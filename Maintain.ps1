# Keep the local Reverse THIS! kit healthy without touching user work.
# Dry-run by default; -Apply removes only kit-owned stale files, -UpdateTools
# refreshes the catalog, and -Test runs the local structural checks.
[CmdletBinding()]
param(
    [string]$Root,
    [string]$PointerPath,
    [switch]$Apply,
    [switch]$UpdateTools,
    [switch]$Test,
    [switch]$All
)

$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = Split-Path -Parent $MyInvocation.MyCommand.Path }
$Root = [IO.Path]::GetFullPath($Root).TrimEnd('\')
if (-not $PointerPath) { $PointerPath = Join-Path $env:LOCALAPPDATA 'ReverseThis\kit.json' }
$sandbox = Join-Path $Root 'sandbox'
$stale = New-Object System.Collections.ArrayList
$failures = New-Object System.Collections.ArrayList

function Add-Stale {
    param([string]$Path, [string]$Reason)
    if (Test-Path -LiteralPath $Path) {
        $item = Get-Item -LiteralPath $Path -Force
        $bytes = if ($item.PSIsContainer) {
            (Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        } else { $item.Length }
        [void]$stale.Add([pscustomobject]@{ Path = $Path; Reason = $Reason; Bytes = [int64]$bytes })
    }
}

function Remove-Stale {
    param($Items)
    foreach ($item in $Items) {
        try {
            Remove-Item -LiteralPath $item.Path -Recurse -Force -ErrorAction Stop
            Write-Host ("removed {0} ({1})" -f $item.Path, $item.Reason)
        } catch {
            [void]$failures.Add("$($item.Path): $($_.Exception.Message)")
        }
    }
}

function Test-Local {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) { throw 'python is not on PATH; cannot run local checks.' }
    & $python.Source (Join-Path $Root 'tests\test_catalog.py')
    if ($LASTEXITCODE -ne 0) { throw 'catalog test failed' }
    & $python.Source (Join-Path $Root 'tests\test_encyclopedia.py')
    if ($LASTEXITCODE -ne 0) { throw 'encyclopedia test failed' }
}

if (-not (Test-Path -LiteralPath $sandbox -PathType Container)) {
    throw "Not a Reverse THIS! kit: $sandbox is missing."
}

# Newest two rollback payloads per tool and two state snapshots are the recovery floor.
$backups = Join-Path $sandbox 'backups'
if (Test-Path -LiteralPath $backups) {
    $groups = Get-ChildItem -LiteralPath $backups -Directory -Force -ErrorAction SilentlyContinue |
        Group-Object { if ($_.Name -match '^(.*?)-[0-9a-f]{8,}$') { $Matches[1] } else { $_.Name } }
    foreach ($group in $groups) {
        $group.Group | Sort-Object LastWriteTime -Descending | Select-Object -Skip 2 |
            ForEach-Object { Add-Stale $_.FullName 'old tool rollback' }
    }
}
Get-ChildItem -LiteralPath $sandbox -File -Filter 'installed.json.pre-*.json' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -Skip 2 |
    ForEach-Object { Add-Stale $_.FullName 'old installed-state snapshot' }

if (Test-Path -LiteralPath $PointerPath) {
    Get-ChildItem -LiteralPath (Split-Path -Parent $PointerPath) -File -Filter 'kit.json.pre-*' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -Skip 3 |
        ForEach-Object { Add-Stale $_.FullName 'old owner-pointer backup' }
    try {
        $receipt = Get-Content -LiteralPath $PointerPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $owner = [string]$receipt.kit_root
        if ($owner -and ([IO.Path]::GetFullPath($owner).TrimEnd('\') -ne $Root) -and -not (Test-Path -LiteralPath $owner -PathType Container)) {
            Write-Host "owner pointer is stale: $owner (current: $Root)"
        }
    } catch { Write-Host "owner pointer is unreadable: $PointerPath" }
}

$tmp = Join-Path $sandbox 'tmp'
if (Test-Path -LiteralPath $tmp) {
    $cutoff = (Get-Date).AddHours(-24)
    Get-ChildItem -LiteralPath $tmp -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        ForEach-Object { Add-Stale $_.FullName 'installer temp older than 24h' }
}
$smoke = Join-Path $sandbox 'work\runtime-smoke'
if (Test-Path -LiteralPath $smoke) {
    Get-ChildItem -LiteralPath $smoke -Directory -Filter 'run-*' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -Skip 1 |
        ForEach-Object { Add-Stale $_.FullName 'old smoke run' }
}
Get-ChildItem -LiteralPath $Root -Recurse -Directory -Filter '__pycache__' -Force -ErrorAction SilentlyContinue |
    ForEach-Object { Add-Stale $_.FullName 'generated Python cache' }

$bytes = [int64](($stale | Measure-Object -Property Bytes -Sum).Sum | ForEach-Object { if ($null -eq $_) { 0 } else { $_ } })
Write-Host ("{0}: {1} stale item(s), {2:N1} MB" -f $Root, $stale.Count, ($bytes / 1MB))
$stale | ForEach-Object { Write-Host ("  {0}  {1}" -f $_.Reason, $_.Path) }

if ($All) { $Apply = $true; $UpdateTools = $true; $Test = $true }
if ($Apply -and $stale.Count) {
    Remove-Stale $stale
    if (Test-Path -LiteralPath $PointerPath) {
        try {
            $receipt = Get-Content -LiteralPath $PointerPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($receipt.kit_root -and -not (Test-Path -LiteralPath $receipt.kit_root -PathType Container) -and (Test-Path -LiteralPath (Join-Path $sandbox 'installed.json') -PathType Leaf)) {
                $new = [ordered]@{
                    java_home = $receipt.java_home
                    bin = (Join-Path $Root 'sandbox\bin')
                    installed_json = (Join-Path $sandbox 'installed.json')
                    kit_root = $Root
                }
                [IO.File]::WriteAllText($PointerPath, ($new | ConvertTo-Json), (New-Object Text.UTF8Encoding $false))
                Write-Host "repaired owner pointer: $PointerPath"
            }
        } catch { Write-Host "pointer repair skipped: $($_.Exception.Message)" }
    }
}
if ($UpdateTools) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'Install-Modkit.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'tool update failed' }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'Install-Modkit.ps1') -Doctor
    if ($LASTEXITCODE -ne 0) { throw 'doctor failed' }
}
if ($Test) { Test-Local }
if ($failures.Count) { $failures | ForEach-Object { Write-Error $_ }; exit 1 }
if (-not $Apply -and $stale.Count) { Write-Host 'Report only. Re-run with -Apply to remove these kit-owned leftovers.'; exit 1 }
exit 0
