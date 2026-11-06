# Offline checks for Maintain.ps1 retention and pointer repair.
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:TEMP ('rt-maintain-' + [guid]::NewGuid().ToString('N'))
$sandbox = Join-Path $root 'sandbox'
$pointerDir = Join-Path $root 'pointer'
$pointer = Join-Path $pointerDir 'kit.json'
function Touch([string]$Path, [int]$DaysAgo) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    Set-Content -LiteralPath $Path -Value 'fixture' -Encoding ASCII
    (Get-Item -LiteralPath $Path).LastWriteTime = (Get-Date).AddDays(-$DaysAgo)
    (Get-Item -LiteralPath (Split-Path -Parent $Path)).LastWriteTime = (Get-Date).AddDays(-$DaysAgo)
}
try {
    New-Item -ItemType Directory -Path (Join-Path $sandbox 'tmp'), (Join-Path $sandbox 'work\runtime-smoke'), (Join-Path $sandbox 'backups'), $pointerDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $sandbox 'installed.json') -Value '{"schema":1,"tools":{}}' -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $sandbox 'work\keep.txt') -Value 'user work' -Encoding ASCII
    foreach ($n in 1..3) { Touch (Join-Path $sandbox "backups\tool-a-aaaaaaaa$n\file.txt") (10 - $n) }
    Touch (Join-Path $sandbox 'backups\tool-b-bbbbbbbb\file.txt') 1
    foreach ($n in 1..3) { Touch (Join-Path $sandbox "installed.json.pre-1.0.$n.json") (10 - $n) }
    foreach ($n in 1..4) { Touch (Join-Path $pointerDir "kit.json.pre-1.0.$n") (10 - $n) }
    Touch (Join-Path $sandbox 'tmp\old-install') 2
    Touch (Join-Path $sandbox 'tmp\new-install') 0
    Touch (Join-Path $sandbox 'work\runtime-smoke\run-old\x.txt') 3
    Touch (Join-Path $sandbox 'work\runtime-smoke\run-new\x.txt') 0
    Touch (Join-Path $sandbox 'scripts\__pycache__\x.pyc') 0
    Set-Content -LiteralPath $pointer -Value ((@{ kit_root = (Join-Path $root 'gone'); installed_json = 'x'; bin = 'y' } | ConvertTo-Json)) -Encoding ASCII

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '..\Maintain.ps1') -Root $root -PointerPath $pointer -Apply
    if ($LASTEXITCODE -ne 0) { throw 'Maintain.ps1 failed' }
    if (-not (Test-Path -LiteralPath (Join-Path $sandbox 'backups\tool-a-aaaaaaaa3'))) { throw 'newest backup removed' }
    if (-not (Test-Path -LiteralPath (Join-Path $sandbox 'backups\tool-a-aaaaaaaa2'))) { throw 'second backup removed' }
    if (Test-Path -LiteralPath (Join-Path $sandbox 'backups\tool-a-aaaaaaaa1')) { throw 'old backup kept' }
    if (Test-Path -LiteralPath (Join-Path $sandbox 'tmp\old-install')) { throw 'old temp kept' }
    if (-not (Test-Path -LiteralPath (Join-Path $sandbox 'tmp\new-install'))) { throw 'new temp removed' }
    if (Test-Path -LiteralPath (Join-Path $sandbox 'work\runtime-smoke\run-old')) { throw 'old smoke run kept' }
    if (-not (Test-Path -LiteralPath (Join-Path $sandbox 'work\keep.txt'))) { throw 'user work removed' }
    $receipt = Get-Content -LiteralPath $pointer -Raw | ConvertFrom-Json
    if ($receipt.kit_root -ne $root) { throw 'stale pointer not repaired' }
    Write-Output 'maintenance checks ok'
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
