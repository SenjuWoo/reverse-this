#Requires -Version 5.1
# Offline .NET prerequisite probes; fake winget never installs machine software.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $root 'Install-Modkit.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
foreach ($definition in $ast.FindAll({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
}, $false)) { Invoke-Expression $definition.Extent.Text }
$productionProbe = (Get-Item Function:\Test-DotNet10).ScriptBlock
$productionFind = (Get-Item Function:\Find-DotNet10).ScriptBlock

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Assert-Throws {
    param([scriptblock]$Action, [string]$Pattern)
    $failure = $null
    try { & $Action | Out-Null } catch { $failure = $_.Exception.Message }
    Assert-True ([bool]$failure -and $failure -match $Pattern) "Expected failure matching '$Pattern'; got '$failure'."
}
function Write-TestFile {
    param([string]$Path, [string]$Text)
    [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding $false))
}
function Write-Log { param([string]$Message, [switch]$Detail) }
# Resolve only explicit mock commands. No test can reach the real winget.
function Get-Command {
    [CmdletBinding()]
    param([string]$Name, $CommandType)
    if ($Name -eq 'dotnet' -and $script:MockDotNet) { return [pscustomobject]@{ Source = $script:MockDotNet } }
    if ($Name -eq 'winget' -and $script:MockWinget) { return [pscustomobject]@{ Source = $script:MockWinget } }
}

$testBase = Join-Path $root 'sandbox\tmp'
$testRoot = Join-Path $testBase ('dotnet-tests-' + [Guid]::NewGuid().ToString('N'))
$environmentNames = @('DOTNET_ROOT_X64', 'DOTNET_ROOT', 'RT_DOTNET_INSTALL_EXIT', 'RT_DOTNET_UPDATE_EXIT', 'RT_DOTNET_LIST_EXIT', 'RT_WINGET_EXIT')
$savedEnvironment = @{}
foreach ($name in $environmentNames) { $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$savedPath = $env:PATH
$savedPreference = $ErrorActionPreference
try {
    New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
    $fake = Join-Path $testRoot 'selected dotnet.cmd'
    $fakeWinget = Join-Path $testRoot 'fake winget.cmd'
    Write-TestFile $fake @'
@echo off
setlocal DisableDelayedExpansion
if "%~1"=="--list-sdks" (type "%~dp0sdks.txt" & exit /b 0)
if "%~1"=="--list-runtimes" (type "%~dp0runtimes.txt" & exit /b 0)
>> "%~dp0dotnet-calls.txt" echo %*
if "%~2"=="install" exit /b %RT_DOTNET_INSTALL_EXIT%
if "%~2"=="update" exit /b %RT_DOTNET_UPDATE_EXIT%
if "%~2"=="list" (
  echo ilspycmd 11.1.0.9782 ilspycmd
  exit /b %RT_DOTNET_LIST_EXIT%
)
exit /b 99
'@
    Write-TestFile $fakeWinget @'
@echo off
setlocal DisableDelayedExpansion
> "%~dp0winget-calls.txt" echo %*
> "%~dp0winget-ran.txt" echo present
exit /b %RT_WINGET_EXIT%
'@
    $sdkFile = Join-Path $testRoot 'sdks.txt'
    $runtimeFile = Join-Path $testRoot 'runtimes.txt'
    Write-TestFile $sdkFile "8.0.418 [owned sdk]`r`n"
    Write-TestFile $runtimeFile "Microsoft.NETCore.App 9.0.20 [owned runtime]`r`n"
    Assert-True (-not (Test-DotNet10 $fake)) 'SDK8/runtime9 satisfied a net10 prerequisite.'
    Write-TestFile $sdkFile "10.0.301 [owned sdk]`r`n"
    Assert-True (-not (Test-DotNet10 $fake)) 'SDK10 with a missing runtime10 was accepted.'
    Write-TestFile $sdkFile "10.0.100-preview.7 [owned sdk]`r`n"
    Write-TestFile $runtimeFile "Microsoft.NETCore.App 10.0.9 [owned runtime]`r`n"
    Assert-True (-not (Test-DotNet10 $fake)) 'A preview-only SDK was accepted.'
    Write-TestFile $sdkFile "10.0.301 [owned sdk]`r`n"
    Assert-True (Test-DotNet10 $fake) 'Stable SDK10 plus runtime10 was rejected.'
    Assert-True (-not (Test-DotNet10 (Join-Path $testRoot 'missing.exe'))) 'A missing executable passed the probe.'

    $env:DOTNET_ROOT_X64 = Join-Path $testRoot 'old x64'
    $env:DOTNET_ROOT = Join-Path $testRoot 'portable ten'
    $script:MockDotNet = Join-Path $testRoot 'stale PATH\dotnet.exe'
    $script:AcceptHost = Join-Path $env:DOTNET_ROOT 'dotnet.exe'
    $script:ProbedHosts = @()
    function Test-DotNet10 { param([string]$Executable)
        $script:ProbedHosts += $Executable
        return $Executable -eq $script:AcceptHost
    }
    Assert-True ((Find-DotNet10) -eq $script:AcceptHost) 'Portable DOTNET_ROOT was ignored after an unsuitable X64 root.'
    $script:AcceptHost = Join-Path $env:ProgramFiles 'dotnet\dotnet.exe'
    Assert-True ((Find-DotNet10) -eq $script:AcceptHost) 'A stale PATH blocked the Program Files host.'
    Assert-True ($script:ProbedHosts -contains $script:MockDotNet) 'The PATH host was not considered.'
    $script:AcceptHost = $script:MockDotNet
    Assert-True ((Find-DotNet10) -eq $script:MockDotNet) 'A suitable PATH host was ignored.'

    $script:PrerequisitePresent = $false
    function Find-DotNet10 {
        if ($script:PrerequisitePresent -or (Test-Path -LiteralPath (Join-Path $testRoot 'winget-ran.txt'))) { return $fake }
        return $null
    }
    $script:MockWinget = $null
    Assert-Throws { Initialize-DotNet10 } 'winget is unavailable'
    $script:MockWinget = $fakeWinget
    $env:RT_WINGET_EXIT = '23'
    Assert-Throws { Initialize-DotNet10 } 'Microsoft.DotNet.SDK.10 failed \(23\)'
    Remove-Item -LiteralPath (Join-Path $testRoot 'winget-ran.txt')
    $env:RT_WINGET_EXIT = '0'
    Assert-True ((Initialize-DotNet10) -eq $fake) 'The newly installed host was not selected.'
    Assert-True ($script:DotNetExe -eq $fake -and $script:DotNetHome -eq $testRoot) 'Runtime selection was not recorded for shims.'
    $wingetCall = Get-Content -LiteralPath (Join-Path $testRoot 'winget-calls.txt') -Raw
    Assert-True ($wingetCall -match '--id Microsoft.DotNet.SDK.10 -e' -and $wingetCall -match '--disable-interactivity') 'The official exact SDK package was not requested.'
    function Find-DotNet10 { return $null }
    Assert-Throws { Initialize-DotNet10 } 'SDK and runtime were not found'
    function Find-DotNet10 { return $fake }
    Remove-Item -LiteralPath (Join-Path $testRoot 'winget-calls.txt')
    [void](Initialize-DotNet10)
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $testRoot 'winget-calls.txt'))) 'An existing suitable host invoked winget.'

    $ToolsDir = Join-Path $testRoot 'tools'
    $BinDir = Join-Path $testRoot 'bin'
    $KitRoot = $testRoot
    New-Item -ItemType Directory -Path $ToolsDir, $BinDir | Out-Null
    $tool = [pscustomobject]@{ id = 'ilspycmd'; method = 'dotnet-tool'; package = 'ilspycmd'; shims = @([pscustomobject]@{ name = 'ilspycmd'; exe_glob = 'ilspycmd.exe' }) }
    function Test-AlreadyInstalled { param([string]$Dest, [string]$Marker) return $false }
    function Install-Shims { param($Tool, [string]$Dest) return @() }
    function Write-Marker { param([string]$Dest, [string]$Marker) }
    $env:RT_DOTNET_INSTALL_EXIT = '1'
    $env:RT_DOTNET_UPDATE_EXIT = '0'
    $env:RT_DOTNET_LIST_EXIT = '0'
    $row = Install-DotNetTool $tool
    Assert-True ($row -isnot [array] -and $row.version -eq '11.1.0.9782') 'Selected-host stdout polluted the installed record.'
    $calls = @(Get-Content -LiteralPath (Join-Path $testRoot 'dotnet-calls.txt'))
    Assert-True ($calls.Count -eq 3 -and $calls[0] -match '^tool install ' -and $calls[1] -match '^tool update ' -and $calls[2] -match '^tool list ') 'Install/update/list did not all use the selected host.'
    Assert-True ($calls[0] -match '--framework net10\.0(?:\s|$)' -and $calls[1] -match '--framework net10\.0(?:\s|$)') 'Install/update must explicitly target net10.0 despite a caller SDK pin.'
    $env:RT_DOTNET_LIST_EXIT = '17'
    Assert-Throws { Install-DotNetTool $tool } 'dotnet tool list failed \(17\)'
    $env:RT_DOTNET_UPDATE_EXIT = '19'
    Assert-Throws { Install-DotNetTool $tool } 'dotnet tool ilspycmd failed \(19\)'
    $target = Join-Path $ToolsDir 'runtime-probe.cmd'
    Write-TestFile $target @'
@echo off
> "%~dp0runtime-root.txt" echo %DOTNET_ROOT%
>> "%~dp0runtime-root.txt" echo %DOTNET_ROOT_X64%
exit /b 0
'@
    $shim = Write-Shim -Name 'runtime-probe' -Target $target -DotNetHome $testRoot
    $beforeRoot = $env:DOTNET_ROOT
    $beforeRootX64 = $env:DOTNET_ROOT_X64
    & $shim
    Assert-True ($LASTEXITCODE -eq 0) 'A shim with the selected runtime failed.'
    $runtimeRoots = @(Get-Content -LiteralPath (Join-Path $ToolsDir 'runtime-root.txt'))
    Assert-True ($runtimeRoots.Count -eq 2 -and $runtimeRoots[0] -eq $testRoot -and $runtimeRoots[1] -eq $testRoot) 'The apphost shim did not bind the selected runtime.'
    Assert-True ($env:DOTNET_ROOT -ceq $beforeRoot -and $env:DOTNET_ROOT_X64 -ceq $beforeRootX64) 'A runtime shim changed its caller environment.'
    Assert-True ($env:PATH -ceq $savedPath -and $ErrorActionPreference -eq $savedPreference) 'Prerequisite handling changed PATH or error policy.'
    Write-Host 'dotnet prerequisite ok: stable SDK/runtime10, portable discovery, winget failures and rediscovery, selected-host tool commands'
} finally {
    foreach ($name in $environmentNames) {
        if ($null -eq $savedEnvironment[$name]) { Remove-Item -LiteralPath ('Env:\' + $name) -ErrorAction SilentlyContinue }
        else { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process') }
    }
    Set-Item Function:\Test-DotNet10 $productionProbe
    Set-Item Function:\Find-DotNet10 $productionFind
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = (Resolve-Path -LiteralPath $testRoot).Path
        $prefix = [IO.Path]::GetFullPath($testBase).TrimEnd('\') + '\'
        if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing cleanup outside test root.' }
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
