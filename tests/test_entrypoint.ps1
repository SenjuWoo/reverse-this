#Requires -Version 5.1
# Exercise the real batch entrypoint; all failure fixtures stay below sandbox/tmp.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$testBase = Join-Path $root 'sandbox\tmp'
$testRoot = Join-Path $testBase ('entrypoint-tests-' + [Guid]::NewGuid().ToString('N'))

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-Entrypoint {
    param([string]$Directory, [string]$Arguments, [string]$DelayedExpansion = 'off')
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $env:ComSpec
    $info.Arguments = '/d /v:' + $DelayedExpansion + ' /c .\install.cmd ' + $Arguments
    $info.WorkingDirectory = $Directory
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $info
    try {
        [void]$process.Start()
        $process.StandardInput.Close()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(15000)) {
            $process.Kill()
            throw 'Batch entrypoint did not finish with stdin closed.'
        }
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            Output = $stdout.GetAwaiter().GetResult()
            Error = $stderr.GetAwaiter().GetResult()
        }
    } finally {
        $process.Dispose()
    }
}

try {
    foreach ($mode in @('-Plan', '-SelfTest')) {
        $result = Invoke-Entrypoint -Directory $root -Arguments $mode
        Assert-True ($result.ExitCode -eq 0) "Real batch entrypoint failed $mode`: $($result.Error)"
        Assert-True ($result.Output -notmatch 'Modkit ready') 'Read-only checks must not claim tools are ready.'
        Assert-True ($result.Output -notmatch 'Press any key') 'Argument-driven runs must not pause.'
    }

    $fixture = Join-Path $testRoot ('kit & ' + [char]0x4e2d + ' ! path')
    New-Item -ItemType Directory -Force -Path $fixture | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'install.cmd') -Destination (Join-Path $fixture 'install.cmd')
    $probe = @'
param([int]$Result = 0, [string]$Value = '')
Write-Host "PROBE_RESULT=$Result"
Write-Host "PROBE_VALUE=$Value"
exit $Result
'@
    [IO.File]::WriteAllText((Join-Path $fixture 'Install-Modkit.ps1'), $probe)
    foreach ($expected in @(0, 1, 27, -1)) {
        $result = Invoke-Entrypoint -Directory $fixture -Arguments ('-Result ' + $expected)
        Assert-True ($result.ExitCode -eq $expected) "Batch lost child exit code $expected (got $($result.ExitCode))."
        Assert-True ($result.Output -match ('PROBE_RESULT=' + $expected)) 'The fixture installer did not run.'
        if ($expected -ne 0) {
            Assert-True ($result.Output -notmatch 'Modkit command completed|Modkit ready') 'A failed child was reported as success.'
        }
    }
    $result = Invoke-Entrypoint -Directory $fixture -Arguments '-Result 0' -DelayedExpansion 'on'
    Assert-True ($result.ExitCode -eq 0 -and $result.Output -match 'PROBE_RESULT=0') 'Inherited delayed expansion broke the path containing !.'
    $result = Invoke-Entrypoint -Directory $fixture -Arguments '-Value "spaces & punctuation ! intact"'
    Assert-True ($result.ExitCode -eq 0 -and $result.Output -match 'PROBE_VALUE=spaces & punctuation ! intact') 'Quoted arguments were not preserved.'
    $result = Invoke-Entrypoint -Directory $fixture -Arguments ''
    Assert-True ($result.ExitCode -eq 0) 'Interactive-mode PAUSE changed successful child status with stdin closed.'

    Remove-Item -LiteralPath (Join-Path $fixture 'Install-Modkit.ps1')
    $result = Invoke-Entrypoint -Directory $fixture -Arguments '-Plan'
    Assert-True ($result.ExitCode -ne 0) 'A missing installer script was reported as success.'
    Assert-True ($result.Output -notmatch 'Modkit command completed|Modkit ready') 'PowerShell startup failure printed success.'
    Write-Host 'entrypoint ok: real Plan/SelfTest, exact exit status, closed stdin, punctuation paths and quoted arguments'
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = (Resolve-Path -LiteralPath $testRoot).Path
        $prefix = [IO.Path]::GetFullPath($testBase).TrimEnd('\') + '\'
        if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing cleanup outside test root: $resolved"
        }
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
