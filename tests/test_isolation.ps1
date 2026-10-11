#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

function Assert {
    param($Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

$root = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('reverse-this-isolation-&-' + [char]0x4e2d + '-' + [Guid]::NewGuid().ToString('N'))
try {
    $inputFolder = Join-Path $testRoot 'input & source'
    New-Item -ItemType Directory -Force -Path $inputFolder | Out-Null
    $script = Join-Path $testRoot 'Start-IsolatedLab.ps1'
    Copy-Item -LiteralPath (Join-Path $root 'Start-IsolatedLab.ps1') -Destination $script
    $before = @(Get-ChildItem -LiteralPath $testRoot -Force -Recurse).Count
    $plan = & $script -Plan -InputFolder $inputFolder
    Assert ($plan -is [string]) 'Plan must return only the XML string.'
    Assert ($plan.Contains('&amp;')) 'Host paths were not XML escaped.'
    $xml = [xml]$plan
    foreach ($name in @('Networking', 'ClipboardRedirection', 'AudioInput', 'VideoInput', 'PrinterRedirection', 'vGPU')) {
        Assert ($xml.Configuration.$name -eq 'Disable') "$name must be disabled."
    }
    Assert ($xml.Configuration.ProtectedClient -eq 'Enable') 'ProtectedClient must be enabled.'
    Assert (-not $xml.Configuration.LogonCommand) 'Samples must not run at logon.'
    $maps = @($xml.Configuration.MappedFolders.MappedFolder)
    Assert ($maps.Count -eq 4) 'Expected tools, bin, output and optional input mappings.'
    foreach ($name in @('tools', 'bin')) {
        $map = @($maps | Where-Object { $_.SandboxFolder -eq "C:\ReverseThis\sandbox\$name" })
        Assert ($map.Count -eq 1 -and $map[0].ReadOnly -eq 'true') "$name must be mapped read-only."
        Assert ($map[0].HostFolder -eq (Join-Path $testRoot "sandbox\$name")) "$name host folder drifted."
    }
    $writable = @($maps | Where-Object { $_.ReadOnly -ne 'true' })
    Assert ($writable.Count -eq 1) 'Exactly one host folder may be writable.'
    Assert ($writable[0].HostFolder -eq (Join-Path $testRoot 'sandbox\work\isolated')) 'Writable output must stay under sandbox/work/isolated.'
    Assert ($writable[0].SandboxFolder -eq 'C:\ReverseThis\sandbox\work\isolated') 'Guest output folder drifted.'
    $inputMap = @($maps | Where-Object { $_.SandboxFolder -eq 'C:\ReverseThis\input' })
    Assert ($inputMap.Count -eq 1 -and $inputMap[0].HostFolder -eq $inputFolder -and $inputMap[0].ReadOnly -eq 'true') 'Input must be mapped read-only with its exact path.'
    $default = [xml](& $script -Plan)
    Assert (@($default.Configuration.MappedFolders.MappedFolder).Count -eq 3) 'Default plan must not expose an input folder.'
    Assert (@(Get-ChildItem -LiteralPath $testRoot -Force -Recurse).Count -eq $before) 'Plan wrote host files.'
    $rejected = $false
    try { & $script -Plan -InputFolder $script | Out-Null } catch { $rejected = $true }
    Assert $rejected 'A file cannot be mapped as InputFolder.'

    # Emulate the OS feature and intercept process creation; never start Windows Sandbox.
    $systemLauncher = Join-Path $env:WINDIR 'System32\WindowsSandbox.exe'
    $launches = New-Object System.Collections.ArrayList
    New-Item -ItemType Directory -Force -Path (Join-Path $testRoot 'sandbox\tools'), (Join-Path $testRoot 'sandbox\bin') | Out-Null
    & {
        $linkedPath = $null
        function Get-Command { throw 'The Sandbox launcher must not trust PATH.' }
        function Test-Path {
            param([string]$LiteralPath, [string]$PathType)
            if ($LiteralPath -eq $systemLauncher) { return $true }
            $arguments = @{ LiteralPath = $LiteralPath }
            if ($PathType) { $arguments.PathType = $PathType }
            Microsoft.PowerShell.Management\Test-Path @arguments
        }
        function Get-Item {
            param([string]$LiteralPath, [switch]$Force)
            if ($LiteralPath -eq $linkedPath) {
                return [pscustomobject]@{ Attributes = [IO.FileAttributes]::ReparsePoint }
            }
            Microsoft.PowerShell.Management\Get-Item -LiteralPath $LiteralPath -Force:$Force
        }
        function Start-Process {
            param([string]$FilePath, [string]$ArgumentList)
            [void]$launches.Add(@{ FilePath = $FilePath; ArgumentList = $ArgumentList })
        }
        & $script 6>$null
        Assert ($launches.Count -eq 1) 'Expected one intercepted launch.'
        Assert ($launches[0].FilePath -eq $systemLauncher) 'Only the OS WindowsSandbox.exe may launch.'
        Assert ($launches[0].ArgumentList -eq ('"{0}"' -f (Join-Path $testRoot 'sandbox\work\isolated-lab.wsb'))) 'Configuration path must be quoted as one argument.'
        $linkedPath = Join-Path $testRoot 'sandbox\work\isolated'
        $rejected = $false
        try { & $script } catch { $rejected = $_.Exception.Message.StartsWith('Writable output path contains a link:') }
        Assert $rejected 'A writable output link must be rejected.'
        Assert ($launches.Count -eq 1) 'A linked output must not launch a sandbox.'
    }
    Write-Host 'isolation ok: escaped plan, read-only mappings, OS-only launch, writable-link rejection; no real process launched'
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = (Resolve-Path -LiteralPath $testRoot).Path
        $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
        if (-not $resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove test directory outside TEMP: $resolved"
        }
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
