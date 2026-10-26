#Requires -Version 5.1
# Offline standalone boundaries: fake runtimes/registries, actual receipts and local release archives only.
# Disposable fixtures stay in TEMP, outside Git ancestors which the source updater correctly refuses.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$tokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'Install-Modkit.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
foreach ($definition in $ast.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] }, $false)) { Invoke-Expression $definition.Extent.Text }
function Assert-True { param([bool]$Value,[string]$Message) if (-not $Value) { throw $Message } }
function Assert-Throws { param([scriptblock]$Action,[string]$Pattern)
    $failure=$null; try { & $Action | Out-Null } catch { $failure=$_.Exception.Message }
    Assert-True ([bool]$failure -and $failure -match $Pattern) "Expected $Pattern; got $failure"
}
function Write-TestFile { param([string]$Path,[string]$Text) [IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding $false)) }
# Windows PowerShell promotes native stderr; capture expected child failures without losing their status.
function Invoke-TestUpdater { param([string]$Digest)
    $prior=$ErrorActionPreference
    try { $ErrorActionPreference='Continue'; $output=@(& $shell -NoProfile -ExecutionPolicy Bypass -File $updater -Archive $archive -Sha256 $Digest -KitRoot $destination 2>&1); $code=$LASTEXITCODE }
    finally { $ErrorActionPreference=$prior }
    return [pscustomobject]@{Code=$code;Output=($output | Out-String)}
}
function Write-Log { param([string]$Message,[switch]$Detail) }
$base = [IO.Path]::GetTempPath()
$testRoot = Join-Path $base ('standalone-' + [guid]::NewGuid().ToString('N'))
$oldBinding=$env:UABS_PYTHON; $oldRoots=$env:UABS_TOOL_ROOTS; $oldPath=$env:PATH
$NoUpdate=$false; $Force=$false; $script:Node=$null; $script:PythonExe=$null
try {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    # Hidden parents (including the real AppData on clean Windows) remain valid path evidence.
    $hiddenParent=Join-Path $testRoot 'hidden-parent'
    New-Item -ItemType Directory -Path $hiddenParent | Out-Null
    (Get-Item -LiteralPath $hiddenParent -Force).Attributes=[IO.FileAttributes]::Directory -bor [IO.FileAttributes]::Hidden
    $updaterAst=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'Update-ReverseThis.ps1'),[ref]$null,[ref]$null)
    $guard=$updaterAst.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Assert-SourceWritePath'},$true)
    Invoke-Expression $guard.Extent.Text
    Assert-SourceWritePath (Join-Path $hiddenParent 'new-tool')
    $KitRoot=Join-Path $testRoot 'owner'; $Sandbox=Join-Path $KitRoot 'sandbox'; $ToolsDir=Join-Path $Sandbox 'tools'; $BinDir=Join-Path $Sandbox 'bin'
    New-Item -ItemType Directory -Path $ToolsDir,$BinDir -Force | Out-Null
    $statePath=Join-Path $Sandbox 'installed.json'; $pointer=Join-Path $testRoot 'kit.json'
    Write-TestFile $statePath ([pscustomobject]@{schema=1;kit_root=$KitRoot;tools=[pscustomobject]@{fixture=@{id='fixture'}}} | ConvertTo-Json -Depth 5)
    Write-TestFile $pointer ([pscustomobject]@{kit_root=$KitRoot;installed_json=$statePath;bin=$BinDir;extension=@{personal='retained'}} | ConvertTo-Json -Depth 5)
    Assert-True ((Resolve-OwnerRoot 'new checkout' '' $pointer) -eq $KitRoot) 'A checkout did not reuse its registered owner.'
    Write-TestFile $pointer '{"kit_root":"relative"}'
    Assert-Throws { Resolve-OwnerRoot 'new checkout' '' $pointer } 'Invalid.*pointer'
    Assert-True ((Resolve-OwnerRoot 'checkout' (Join-Path $testRoot 'isolated') $pointer) -eq (Join-Path $testRoot 'isolated')) 'Explicit isolated root did not bypass the pointer.'
    Assert-Throws { Resolve-OwnerRoot 'checkout' 'relative-root' $pointer } 'absolute non-root'

    # Actual read-only entrypoints must fail missing tools without creating state or changing the shared pointer.
    $shell=(Get-Process -Id $PID).Path; $env:UABS_TOOL_ROOTS=''
    $pointerFile=Join-Path $env:LOCALAPPDATA 'ReverseThis\kit.json'
    $pointerHash=if (Test-Path -LiteralPath $pointerFile) { (Get-FileHash -LiteralPath $pointerFile).Hash } else { $null }
    foreach ($mode in @('-Doctor','-Offline')) {
        $missingRoot=Join-Path $testRoot ('missing-' + $mode.TrimStart('-'))
        $prior=$ErrorActionPreference
        try { $ErrorActionPreference='Continue'; & $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'Install-Modkit.ps1') $mode -InstallRoot $missingRoot -Only rea 2>&1 | Out-Null; $code=$LASTEXITCODE }
        finally { $ErrorActionPreference=$prior }
        Assert-True ($code -eq 1 -and -not (Test-Path -LiteralPath $missingRoot)) "$mode created state or accepted a missing tool."
    }
    $afterPointerHash=if (Test-Path -LiteralPath $pointerFile) { (Get-FileHash -LiteralPath $pointerFile).Hash } else { $null }
    Assert-True ($pointerHash -eq $afterPointerHash) 'An isolated read-only check changed the shared owner pointer.'

    # Reusing a Java/.NET payload must still bind its known runtime into the regenerated shim.
    $productionJdk=${function:Install-Jdk}; $productionDotnet=${function:Initialize-DotNet10}; $productionRelease=${function:Get-GitHubRelease}
    function Install-Jdk { param([int]$Major) return (Join-Path $testRoot 'known-jdk') }
    function Initialize-DotNet10 { $script:DotNetHome=Join-Path $testRoot 'known-dotnet'; return 'fixture-dotnet' }
    try {
        $NoUpdate=$true; $script:JavaHome=$null; $script:DotNetHome=$null
        foreach ($case in @(@('java-probe','github-release'),@('dotnet-probe','dotnet-tool'))) {
            $runtimeDest=Join-Path $ToolsDir $case[0]
            New-Item -ItemType Directory -Path $runtimeDest | Out-Null
            Write-TestFile (Join-Path $runtimeDest 'probe.cmd') "@echo off`r`nexit /b 0`r`n"
            Write-TestFile (Join-Path $runtimeDest '.kit-ok') 'present'
            Write-TestFile (Join-Path $runtimeDest '.kit-record.json') (@{id=$case[0];version='1.0.0';dir=$runtimeDest;shims=@{}} | ConvertTo-Json)
            $runtimeTool=[pscustomobject]@{id=$case[0];method=$case[1];needs_jdk=$(if ($case[0] -eq 'java-probe') {25});shims=@(@{name=$case[0];exe_glob='probe.cmd'})}
            Install-One $runtimeTool | Out-Null
            $shimText=Get-Content -LiteralPath (Join-Path $BinDir ($case[0]+'.cmd')) -Raw
            $expected=if ($case[0] -eq 'java-probe') {'known-jdk'} else {'known-dotnet'}
            Assert-True ($shimText.Contains($expected)) "NoUpdate lost the selected runtime in $($case[0])."
        }
        $NoUpdate=$false; $script:JavaHome=$null
        function Get-GitHubRelease { return [pscustomobject]@{tag_name='v0.9.0';assets=@(@{name='probe.zip'})} }
        $newerJava=[pscustomobject]@{id='java-probe';method='github-release';repo='fixture/repo';asset_pattern='^probe\.zip$';needs_jdk=25;shims=@(@{name='java-probe';exe_glob='probe.cmd'})}
        $retainedJava=Install-One $newerJava
        $shimText=Get-Content -LiteralPath (Join-Path $BinDir 'java-probe.cmd') -Raw
        Assert-True ($retainedJava.version -eq '1.0.0' -and $shimText.Contains('known-jdk')) 'Normal newer Java reuse lost its JDK binding or downgraded the payload.'
    } finally {
        Set-Item Function:\Install-Jdk $productionJdk
        Set-Item Function:\Initialize-DotNet10 $productionDotnet
        Set-Item Function:\Get-GitHubRelease $productionRelease
        $NoUpdate=$false; $script:JavaHome=$null; $script:DotNetHome=$null
    }

    # An owned fake interpreter proves that the probe validates stdout, base prefix and explicit process binding.
    $fakePython=Join-Path $testRoot 'python.cmd'
    $probe=@{exe=$fakePython;base=$testRoot;prefix=$testRoot;version=@(3,14,4)} | ConvertTo-Json -Compress
    Write-TestFile $fakePython ("@echo off`r`necho " + $probe + "`r`nexit /b 0`r`n")
    Assert-True ((Test-SharedPython $fakePython) -eq $fakePython) 'Shared base probe rejected a valid interpreter.'
    $env:UABS_PYTHON=$fakePython
    Assert-True ((Find-SharedPython) -eq $fakePython) 'Explicit process Python was not reused.'
    $probe=@{exe=$fakePython;base=$testRoot;prefix='tool venv';version=@(3,14,4)} | ConvertTo-Json -Compress
    Write-TestFile $fakePython ("@echo off`r`necho " + $probe + "`r`nexit /b 0`r`n")
    Assert-True (-not (Test-SharedPython $fakePython)) 'A virtual environment became the shared Python.'
    Assert-Throws { Find-SharedPython } 'UABS_PYTHON.*shared base'
    Assert-True (Test-PrivateRuntimePath 'C:\x\.cache\codex-runtimes\python.exe') 'Private agent runtime was accepted.'
    foreach ($case in @(@('22.23.3',$false),@('22.23.4',$true),@('23.0.0',$false),@('24.22.0',$false),@('24.22.1',$true),@('26.12.0',$false),@('26.12.1',$true))) {
        Assert-True ((Test-CompatibleNodeVersion $case[0] $true) -eq $case[1]) "REA Node boundary wrong: $($case[0])"
    }

    # A real fake Node executable is probed; an incompatible unowned pair never triggers an install.
    $nodeDirectory=Join-Path $testRoot 'node'; New-Item -ItemType Directory -Path $nodeDirectory | Out-Null
    $nodeCommand=Join-Path $nodeDirectory 'node.cmd'
    Write-TestFile $nodeCommand "@echo off`r`necho v24.22.1`r`nexit /b 0`r`n"
    Write-TestFile (Join-Path $nodeDirectory 'npm.cmd') "@echo off`r`nexit /b 0`r`n"
    function Get-Command { [CmdletBinding()]param([string]$Name,$CommandType,[switch]$All)
        if ($Name -eq 'node') { return [pscustomobject]@{Source=$nodeCommand} }
        if ($Name -eq 'winget') { return $null }
    }
    $productionRuntimeInstall=${function:Install-RuntimePackage}
    $productionNodeFind=${function:Find-SharedNode}
    function Install-RuntimePackage { param([string]$Id,[switch]$Upgrade) throw 'Offline fixture must not provision a runtime.' }
    try {
        $NoUpdate=$true
        $pair=Initialize-SharedNode $true
        Assert-True ($pair.node -eq $nodeCommand -and $pair.npm -eq (Join-Path $nodeDirectory 'npm.cmd')) 'Shared Node/npm pair was not reused.'
        Remove-Item -LiteralPath (Join-Path $nodeDirectory 'npm.cmd')
        $incomplete=Find-SharedNode $true -AllowIncompatible
        Assert-True ($incomplete.node -eq $nodeCommand -and -not $incomplete.npm) 'Existing Node without npm was treated as absent.'
        Write-TestFile (Join-Path $nodeDirectory 'npm.cmd') "@echo off`r`nexit /b 0`r`n"
        Write-TestFile $nodeCommand "@echo off`r`necho v23.0.0`r`nexit /b 0`r`n"
        $script:Node=$null; $NoUpdate=$false
        function Find-SharedNode { param([bool]$Rea,[switch]$AllowIncompatible)
            if ($AllowIncompatible) { return [pscustomobject]@{node=$nodeCommand;npm=(Join-Path $nodeDirectory 'npm.cmd');version='v23.0.0'} }
        }
        Assert-Throws { Initialize-SharedNode $true } 'no parallel Node was installed'
    } finally {
        Remove-Item Function:\Get-Command
        Set-Item Function:\Install-RuntimePackage $productionRuntimeInstall
        Set-Item Function:\Find-SharedNode $productionNodeFind
        $NoUpdate=$false; $script:Node=$null
    }

    # A generated npm launcher must keep the compatible second Node when the caller's first Node is incompatible.
    $badNode=Join-Path $testRoot 'node-incompatible'; $goodNode=Join-Path $testRoot 'node-compatible'
    $nodeToolDir=Join-Path $ToolsDir 'node-probe'
    New-Item -ItemType Directory -Path $badNode,$goodNode,$nodeToolDir | Out-Null
    Write-TestFile (Join-Path $badNode 'node.cmd') "@echo off`r`necho v23.0.0`r`nexit /b 0`r`n"
    Write-TestFile (Join-Path $goodNode 'node.cmd') "@echo off`r`necho v24.22.1`r`nexit /b 0`r`n"
    foreach ($directory in @($badNode,$goodNode)) { Write-TestFile (Join-Path $directory 'npm.cmd') "@echo off`r`nexit /b 0`r`n" }
    Write-TestFile (Join-Path $nodeToolDir 'probe.cmd') "@echo off`r`nnode --version`r`n"
    Write-TestFile (Join-Path $nodeToolDir '.kit-ok') 'present'
    Write-TestFile (Join-Path $nodeToolDir '.kit-record.json') (@{id='rea';version='6.8.0';dir=$nodeToolDir;shims=@{}} | ConvertTo-Json)
    $nodeTool=[pscustomobject]@{id='rea';method='npm-tool';shims=@(@{name='node-probe';exe_glob='probe.cmd'})}
    try {
        $env:PATH=$badNode+';'+$goodNode+';'+$oldPath; $NoUpdate=$true; $script:Node=$null
        $script:CurrentTool=$nodeTool
        Assert-True (Test-AlreadyInstalled -Dest $nodeToolDir -Marker 'present') 'The cached npm fixture was not reusable.'
        $nodeOutput=(& (Join-Path $BinDir 'node-probe.cmd') | Out-String).Trim()
        Assert-True ($LASTEXITCODE -eq 0 -and $nodeOutput -eq 'v24.22.1' -and $script:Node.node -eq (Join-Path $goodNode 'node.cmd')) 'The npm shim launched the caller PATH Node rather than the selected compatible runtime.'
    } finally { $env:PATH=$oldPath; $NoUpdate=$false; $script:Node=$null }

    # The Python manager receives patch-only requests for an existing managed feature line.
    $productionFind=${function:Find-SharedPython}; $productionCommand=${function:Get-Command}
    $manager=Join-Path $testRoot 'pymanager.cmd'; $managerCalls=Join-Path $testRoot 'manager.txt'
    Write-TestFile $manager ("@echo off`r`n> `"" + $managerCalls + "`" echo %*`r`nexit /b 0`r`n")
    $script:ManagedPython=Join-Path $testRoot 'Python\pythoncore-3.14-64\python.exe'
    function Find-SharedPython { return $script:ManagedPython }
    function Get-Command { [CmdletBinding()]param([string]$Name,$CommandType,[switch]$All)
        if ($Name -eq 'pymanager') { return [pscustomobject]@{Source=$manager} }
        if ($Name -eq 'winget') { throw 'An offline runtime fixture reached real winget.' }
    }
    try {
        Assert-True ((Initialize-SharedPython) -eq $script:ManagedPython) 'Managed Python selection changed.'
        Assert-True ((Get-Content -LiteralPath $managerCalls -Raw).Trim() -eq 'install --update --yes 3.14') 'Existing Python was not patched on its feature line.'
        Remove-Item -LiteralPath $managerCalls
        $script:PythonExe=$null; $NoUpdate=$true
        Initialize-SharedPython | Out-Null
        Assert-True (-not (Test-Path -LiteralPath $managerCalls)) 'NoUpdate patched the shared runtime.'
    } finally {
        Set-Item Function:\Find-SharedPython $productionFind
        if ($productionCommand) { Set-Item Function:\Get-Command $productionCommand } else { Remove-Item Function:\Get-Command }
        $NoUpdate=$false; $script:PythonExe=$null
    }

    # Latest metadata is mocked at the HTTP boundary; intentional owner pins never query it.
    $script:RegistryCalls=0
    function Invoke-RestMethod { param([string]$Uri,[switch]$UseBasicParsing)
        $script:RegistryCalls++
        if ($Uri -like '*pypi.org*') { return [pscustomobject]@{info=@{version='99.2.0'}} }
        if ($Uri -like '*nuget.org*') { return [pscustomobject]@{versions=@('11.1.0','12.0.0-preview','11.2.0')} }
        return [pscustomobject]@{version='4.4.0';dist=@{integrity='sha512-fixture'}}
    }
    foreach ($case in @(@('frida','pip-venv','frida-tools','99.2.0'),@('asar','npm-tool','@electron/asar','4.4.0'),@('ilspycmd','dotnet-tool','ilspycmd','11.2.0'))) {
        $tool=[pscustomobject]@{id=$case[0];method=$case[1];package=$case[2]}
        Resolve-PackageVersion $tool
        Assert-True ($tool.package_version -eq $case[3]) "Registry version not resolved: $($tool.id)"
    }
    $pin=[pscustomobject]@{id='rea';method='npm-tool';package='rea-agents';package_version='6.8.0'}
    Resolve-PackageVersion $pin
    Assert-True ($script:RegistryCalls -eq 3 -and $pin.package_version -eq '6.8.0') 'Intentional REA pin was replaced by registry latest.'
    $NoUpdate=$true
    Resolve-PackageVersion ([pscustomobject]@{id='frida';method='pip-venv';package='frida-tools'})
    Assert-True ($script:RegistryCalls -eq 3) 'NoUpdate queried package metadata.'
    $NoUpdate=$false
    Remove-Item Function:\Invoke-RestMethod

    # Explicit receipts bind a known tool to its existing directory, and tampering is rejected before mutation.
    $external=Join-Path $testRoot 'external'; New-Item -ItemType Directory -Path $external | Out-Null
    Write-TestFile (Join-Path $external 'fixture.cmd') "@echo off`r`nexit /b 0`r`n"
    $tool=[pscustomobject]@{id='fixture';method='github-release';shims=@([pscustomobject]@{name='fixture';exe_glob='fixture.cmd'})}
    $row=[pscustomobject]@{id='fixture';version='2.0.0';dir=$external;shims=@{}}
    $row=Add-ToolReceipt $tool $row $external
    Write-TestFile (Join-Path $external '.kit-record.json') ($row | ConvertTo-Json -Depth 8)
    Write-TestFile (Join-Path $external '.kit-ok') '2.0.0|fixture.zip'
    $ToolDirectories=@($external); $env:UABS_TOOL_ROOTS=''
    Initialize-ExternalTools ([pscustomobject]@{tools=@($tool)})
    Assert-True ((Get-ToolDirectory 'fixture') -eq $external) 'Registered owner directory was duplicated.'
    $script:CurrentTool=$tool
    Assert-True ([bool](Get-NewerReleaseRecord $tool $external '1.9.0')) 'Newer owned release would have been downgraded.'
    Write-TestFile (Join-Path $external 'fixture.cmd') 'tampered'
    Assert-Throws { Initialize-ExternalTools ([pscustomobject]@{tools=@($tool)}) } 'Invalid external receipt file'
    $script:ToolReceipts=@{'capa-rules'=@{directory=(Join-Path $external 'rules')};'capa-source'=@{directory=(Join-Path $external 'signatures')}}
    $capaShim=Write-Shim -Name 'capa' -Target (Join-Path $external 'fixture.cmd')
    $capaText=Get-Content -LiteralPath $capaShim -Raw
    Assert-True ($capaText.Contains((Join-Path $external 'rules')) -and $capaText.Contains((Join-Path $external 'signatures\sigs'))) 'capa shim lost external support owner paths.'
    $script:ToolReceipts=@{}; $ToolDirectories=@()

    # Exercise the actual release updater with a local, checksum-bound archive and private sentinel.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $source=Join-Path $testRoot 'release'; $destination=Join-Path $testRoot 'released-kit'
    New-Item -ItemType Directory -Force -Path (Join-Path $source 'catalog'),(Join-Path $destination 'sandbox\work') | Out-Null
    Write-TestFile (Join-Path $source 'VERSION') '1.1.0'
    Write-TestFile (Join-Path $source 'Install-Modkit.ps1') '# fixture source'
    Write-TestFile (Join-Path $source 'catalog\tools.json') '{"tools":[]}'
    Write-TestFile (Join-Path $source 'README.md') 'new source'
    Write-TestFile (Join-Path $source 'Notes.md') 'new release notes'
    Write-TestFile (Join-Path $destination 'VERSION') '1.0.0'
    Write-TestFile (Join-Path $destination 'Install-Modkit.ps1') '# original source'
    New-Item -ItemType Directory -Force -Path (Join-Path $destination 'catalog') | Out-Null
    Write-TestFile (Join-Path $destination 'catalog\tools.json') '{"tools":[]}'
    Write-TestFile (Join-Path $destination 'README.md') 'last good'
    Write-TestFile (Join-Path $destination 'sandbox\work\private.txt') 'private sentinel'
    $files=foreach ($relative in @('VERSION','Install-Modkit.ps1','catalog/tools.json','README.md','Notes.md')) { @{path=$relative;sha256=(Get-FileHash -LiteralPath (Join-Path $source $relative) -Algorithm SHA256).Hash.ToLowerInvariant()} }
    Write-TestFile (Join-Path $source 'RELEASE.json') (@{product='Reverse THIS!';version='1.1.0';commit=('a'*40);files=@($files)} | ConvertTo-Json -Depth 5)
    $oldFiles=foreach ($relative in @('VERSION','Install-Modkit.ps1','catalog/tools.json','README.md')) { @{path=$relative;sha256=(Get-FileHash -LiteralPath (Join-Path $destination $relative) -Algorithm SHA256).Hash.ToLowerInvariant()} }
    Write-TestFile (Join-Path $destination 'RELEASE.json') (@{product='Reverse THIS!';version='1.0.0';commit=('b'*40);files=@($oldFiles)} | ConvertTo-Json -Depth 5)
    $raceDestination=Join-Path $testRoot 'advanced-kit'
    Copy-Item -LiteralPath $destination -Destination $raceDestination -Recurse
    $archive=Join-Path $testRoot 'release.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($source,$archive)
    $digest=(Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    $shell=(Get-Process -Id $PID).Path; $updater=Join-Path $root 'Update-ReverseThis.ps1'
    # Advance the installed receipt at the archive-hash boundary, after the updater cached its old version.
    $raceProbe=Join-Path $testRoot 'advance-during-download.ps1'
    Write-TestFile $raceProbe @'
param($Archive,$Sha256,$Updater,$Destination)
$ErrorActionPreference='Stop'
Import-Module Microsoft.PowerShell.Utility
function global:Get-FileHash {
    param($LiteralPath,$Algorithm)
    $hash=Microsoft.PowerShell.Utility\Get-FileHash -LiteralPath $LiteralPath -Algorithm $Algorithm
    if ($LiteralPath -eq $Archive -and -not $script:Advanced) {
        $script:Advanced=$true
        [IO.File]::WriteAllText((Join-Path $Destination 'VERSION'),'1.2.0')
        $prior=Get-Content -LiteralPath (Join-Path $Destination 'RELEASE.json') -Raw | ConvertFrom-Json
        $prior.version='1.2.0'
        foreach ($file in $prior.files) { $file.sha256=(Microsoft.PowerShell.Utility\Get-FileHash -LiteralPath (Join-Path $Destination $file.path) -Algorithm SHA256).Hash.ToLowerInvariant() }
        [IO.File]::WriteAllText((Join-Path $Destination 'RELEASE.json'),($prior | ConvertTo-Json -Depth 6))
    }
    return $hash
}
& $Updater -Archive $Archive -Sha256 $Sha256 -Destination $Destination
'@
    $prior=$ErrorActionPreference
    try { $ErrorActionPreference='Continue'; $raceOutput=(& $shell -NoProfile -ExecutionPolicy Bypass -File $raceProbe -Archive $archive -Sha256 $digest -Updater $updater -Destination $raceDestination 2>&1 | Out-String); $raceCode=$LASTEXITCODE }
    finally { $ErrorActionPreference=$prior }
    Assert-True ($raceCode -eq 0 -and (Get-Content -LiteralPath (Join-Path $raceDestination 'VERSION') -Raw) -eq '1.2.0' -and
        $raceOutput -match 'advanced during download' -and -not (Test-Path -LiteralPath (Join-Path $raceDestination 'sandbox\backups'))) "Delayed source update failed its newer-version boundary: exit=$raceCode output=$raceOutput"
    $result=Invoke-TestUpdater ('0'*64)
    Assert-True ($result.Code -ne 0 -and (Get-Content -LiteralPath (Join-Path $destination 'README.md') -Raw) -eq 'last good') 'Bad archive checksum changed source.'
    Write-TestFile (Join-Path $destination 'README.md') 'personal edit'
    $result=Invoke-TestUpdater $digest
    Assert-True ($result.Code -ne 0 -and $result.Output -match 'Installed source was changed' -and
        (Get-Content -LiteralPath (Join-Path $destination 'README.md') -Raw) -eq 'personal edit' -and
        (Get-Content -LiteralPath (Join-Path $destination 'VERSION') -Raw) -eq '1.0.0') 'Source updater overwrote a personal edit or partially promoted source.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $destination 'sandbox\backups'))) 'Edited source created a replacement transaction.'
    Write-TestFile (Join-Path $destination 'README.md') 'last good'
    Write-TestFile (Join-Path $destination 'Notes.md') 'personal collision'
    $result=Invoke-TestUpdater $digest
    Assert-True ($result.Code -ne 0 -and $result.Output -match 'collides with a personal file' -and
        (Get-Content -LiteralPath (Join-Path $destination 'Notes.md') -Raw) -eq 'personal collision') 'New release source replaced an unowned file.'
    Remove-Item -LiteralPath (Join-Path $destination 'Notes.md')
    $result=Invoke-TestUpdater $digest
    Assert-True ($result.Code -eq 0) "Local verified release failed: $($result.Output)"
    Assert-True ((Get-Content -LiteralPath (Join-Path $destination 'VERSION') -Raw) -eq '1.1.0') 'Source update did not promote its version.'
    Assert-True ((Get-Content -LiteralPath (Join-Path $destination 'sandbox\work\private.txt') -Raw) -eq 'private sentinel') 'Source update changed private work.'
    Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $destination 'sandbox\backups') -Filter README.md -Recurse).Count -eq 1) 'Source update lost the last-good file.'
    New-Item -ItemType Directory -Path (Join-Path $destination '.git') | Out-Null
    $result=Invoke-TestUpdater $digest
    Assert-True ($result.Code -ne 0 -and $result.Output -match 'Git development checkout preserved') 'Release updater overwrote a Git development root.'
    $destination=Join-Path $testRoot 'fresh-kit'
    $result=Invoke-TestUpdater $digest
    Assert-True ($result.Code -eq 0 -and (Get-Content -LiteralPath (Join-Path $destination 'VERSION') -Raw) -eq '1.1.0') "Verified fresh source deployment failed: $($result.Output)"
    $destination=Join-Path $testRoot 'personal-directory'
    New-Item -ItemType Directory -Path $destination | Out-Null
    Write-TestFile (Join-Path $destination 'private.txt') 'retain me'
    $result=Invoke-TestUpdater $digest
    Assert-True ($result.Code -ne 0 -and $result.Output -match 'Nonempty unowned destination preserved' -and
        (Get-Content -LiteralPath (Join-Path $destination 'private.txt') -Raw) -eq 'retain me' -and
        -not (Test-Path -LiteralPath (Join-Path $destination 'sandbox'))) 'Fresh deployment adopted or changed an unowned directory.'
    Write-Host 'standalone ok: owner resolution, shared runtime/pin boundaries, manager patch mode, external receipt hashes, local source promotion/private preservation'
} finally {
    $env:UABS_PYTHON=$oldBinding; $env:UABS_TOOL_ROOTS=$oldRoots; $env:PATH=$oldPath
    if (Test-Path -LiteralPath $testRoot) {
        $resolved=[IO.Path]::GetFullPath($testRoot)
        if (-not $resolved.StartsWith([IO.Path]::GetFullPath($base).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe standalone fixture cleanup.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

# Expected failed child probes must not become the GitHub shell wrapper's final exit status.
exit 0
