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
    New-Item -ItemType Directory -Path (Join-Path $sandbox 'tmp'), (Join-Path $sandbox 'work/runtime-smoke'), (Join-Path $sandbox 'backups'), $pointerDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $sandbox 'installed.json') -Value '{"schema":1,"kit_root":"old-root","tools":{"probe":{"id":"probe"}}}' -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $sandbox 'work/keep.txt') -Value 'user work' -Encoding ASCII
    foreach ($n in 1..3) { Touch (Join-Path $sandbox "backups/tool-a-aaaaaaaa$n/file.txt") (10 - $n) }
    Touch (Join-Path $sandbox 'backups/tool-b-bbbbbbbb/file.txt') 1
    foreach ($n in 1..3) { Touch (Join-Path $sandbox "installed.json.pre-1.0.$n.json") (10 - $n) }
    foreach ($n in 1..4) { Touch (Join-Path $pointerDir "kit.json.pre-1.0.$n") (10 - $n) }
    Touch (Join-Path $sandbox 'tmp/old-install') 2
    Touch (Join-Path $sandbox 'tmp/new-install') 0
    Touch (Join-Path $sandbox 'work/runtime-smoke/run-old/x.txt') 3
    Touch (Join-Path $sandbox 'work/runtime-smoke/run-new/x.txt') 0
    Touch (Join-Path $sandbox 'scripts/__pycache__/x.pyc') 0
    Touch (Join-Path $sandbox 'work/__pycache__/keep.pyc') 0
    Touch (Join-Path $sandbox 'manual/__pycache__/keep.pyc') 0
    Touch (Join-Path $root 'tests/__pycache__/x.pyc') 0
    Set-Content -LiteralPath $pointer -Value ((@{ kit_root = (Join-Path $root 'gone'); installed_json = 'x'; bin = 'y' } | ConvertTo-Json)) -Encoding ASCII

    $hostExe = (Get-Process -Id $PID).Path
    & $hostExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '../Maintain.ps1') -Root $root -PointerPath $pointer -Apply
    if ($LASTEXITCODE -ne 0) { throw 'Maintain.ps1 failed' }
    if (-not (Test-Path -LiteralPath (Join-Path $sandbox 'backups/tool-a-aaaaaaaa3'))) { throw 'newest backup removed' }
    if (-not (Test-Path -LiteralPath (Join-Path $sandbox 'backups/tool-a-aaaaaaaa2'))) { throw 'second backup removed' }
    if (Test-Path -LiteralPath (Join-Path $sandbox 'backups/tool-a-aaaaaaaa1')) { throw 'old backup kept' }
    if (Test-Path -LiteralPath (Join-Path $sandbox 'tmp/old-install')) { throw 'old temp kept' }
    if (-not (Test-Path -LiteralPath (Join-Path $sandbox 'tmp/new-install'))) { throw 'new temp removed' }
    if (Test-Path -LiteralPath (Join-Path $sandbox 'work/runtime-smoke/run-old')) { throw 'old smoke run kept' }
    if (-not (Test-Path -LiteralPath (Join-Path $sandbox 'work/keep.txt'))) { throw 'user work removed' }
    if (-not (Test-Path -LiteralPath (Join-Path $sandbox 'scripts/__pycache__/x.pyc'))) { throw 'protected sandbox cache removed' }
    if (Test-Path -LiteralPath (Join-Path $root 'tests/__pycache__')) { throw 'source cache kept' }
    if (-not (Test-Path -LiteralPath (Join-Path $sandbox 'work/__pycache__/keep.pyc'))) { throw 'protected work cache removed' }
    if (-not (Test-Path -LiteralPath (Join-Path $sandbox 'manual/__pycache__/keep.pyc'))) { throw 'manual cache removed' }

    $lock = [IO.File]::Open((Join-Path $sandbox '.install.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        & $hostExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '../Maintain.ps1') -Root $root -PointerPath $pointer -Apply
        if ($LASTEXITCODE -eq 0) { throw 'cleanup ignored an active installer lock' }
    } finally { $lock.Dispose(); $global:LASTEXITCODE = 0 }
    $receipt = Get-Content -LiteralPath $pointer -Raw | ConvertFrom-Json
    if ([IO.Path]::GetFullPath($receipt.kit_root) -ne [IO.Path]::GetFullPath($root)) { throw 'stale pointer not repaired' }
    $state = Get-Content -LiteralPath (Join-Path $sandbox 'installed.json') -Raw | ConvertFrom-Json
    if ([IO.Path]::GetFullPath($state.kit_root) -ne [IO.Path]::GetFullPath($root)) { throw 'stale installed manifest not repaired' }

    # A linked entry inside a disposable directory must be refused, not traversed.
    $outside = Join-Path $root 'outside'
    New-Item -ItemType Directory -Force -Path $outside | Out-Null
    Set-Content -LiteralPath (Join-Path $outside 'sentinel.txt') -Value 'outside' -Encoding ASCII
    $link = Join-Path $sandbox 'tmp/old-link'
    $junctionMade = $false
    try { New-Item -ItemType Junction -Path $link -Target $outside -ErrorAction Stop | Out-Null; $junctionMade = $true } catch { }
    if ($junctionMade) {
        (Get-Item -LiteralPath $link).LastWriteTime = (Get-Date).AddDays(-2)
        & $hostExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '../Maintain.ps1') -Root $root -PointerPath $pointer -Apply
        if ($LASTEXITCODE -eq 0) { throw 'a linked cleanup target was accepted' }
        if (-not (Test-Path -LiteralPath (Join-Path $outside 'sentinel.txt'))) { throw 'linked cleanup target changed its destination' }
        & cmd.exe /d /c ('rmdir "' + $link + '"')
        $global:LASTEXITCODE = 0
    }

    # Repair must also run when there are no cleanup candidates at all.
    $state.kit_root = 'old-root-again'
    Set-Content -LiteralPath (Join-Path $sandbox 'installed.json') -Value ($state | ConvertTo-Json -Depth 8) -Encoding ASCII
    Set-Content -LiteralPath $pointer -Value ((@{ kit_root = (Join-Path $root 'gone-again'); installed_json = 'x'; bin = 'y' } | ConvertTo-Json)) -Encoding ASCII
    & $hostExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '../Maintain.ps1') -Root $root -PointerPath $pointer -Apply
    if ($LASTEXITCODE -ne 0) { throw 'Maintain.ps1 failed without cleanup candidates' }
    $state = Get-Content -LiteralPath (Join-Path $sandbox 'installed.json') -Raw | ConvertFrom-Json
    if ([IO.Path]::GetFullPath($state.kit_root) -ne [IO.Path]::GetFullPath($root)) { throw 'manifest repair depended on stale cleanup' }

    # A partially repaired move: the pointer is current but the manifest is stale.
    $state.kit_root = 'old-root-partial'
    Set-Content -LiteralPath (Join-Path $sandbox 'installed.json') -Value ($state | ConvertTo-Json -Depth 8) -Encoding ASCII
    & $hostExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '../Maintain.ps1') -Root $root -PointerPath $pointer -Apply
    if ($LASTEXITCODE -ne 0) { throw 'Maintain.ps1 failed repairing a stale manifest with a current pointer' }
    $state = Get-Content -LiteralPath (Join-Path $sandbox 'installed.json') -Raw | ConvertFrom-Json
    if ([IO.Path]::GetFullPath($state.kit_root) -ne [IO.Path]::GetFullPath($root)) { throw 'stale manifest was not repaired independently' }

    # An intact manifest is enough evidence for -Apply to regenerate a missing pointer.
    Remove-Item -LiteralPath $pointer -Force
    & $hostExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '../Maintain.ps1') -Root $root -PointerPath $pointer -Apply
    if ($LASTEXITCODE -ne 0) { throw 'Maintain.ps1 failed to regenerate a missing pointer' }
    if (-not (Test-Path -LiteralPath $pointer)) { throw 'missing pointer was not regenerated' }
    $receipt = Get-Content -LiteralPath $pointer -Raw | ConvertFrom-Json
    if ([IO.Path]::GetFullPath($receipt.kit_root) -ne [IO.Path]::GetFullPath($root)) { throw 'regenerated pointer has the wrong owner' }
    # A missing pointer parent must be created safely, not treated as a failed repair.
    $nestedPointer = Join-Path $root 'missing/deep/kit.json'
    & $hostExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '../Maintain.ps1') -Root $root -PointerPath $nestedPointer -Apply
    if ($LASTEXITCODE -ne 0) { throw 'Maintain.ps1 failed for a missing pointer parent' }
    if (-not (Test-Path -LiteralPath $nestedPointer)) { throw 'missing pointer parent was not created' }

    # An owner record naming another existing checkout is ambiguous and must fail.
    $otherKit = Join-Path $root 'other-kit'
    New-Item -ItemType Directory -Force -Path $otherKit | Out-Null
    $ambiguousState = Get-Content -LiteralPath (Join-Path $sandbox 'installed.json') -Raw | ConvertFrom-Json
    $ambiguousState.kit_root = $otherKit
    Set-Content -LiteralPath (Join-Path $sandbox 'installed.json') -Value ($ambiguousState | ConvertTo-Json -Depth 8) -Encoding ASCII
    Set-Content -LiteralPath $pointer -Value ((@{ kit_root = $otherKit; installed_json = (Join-Path $sandbox 'installed.json'); bin = (Join-Path $root 'sandbox/bin') } | ConvertTo-Json)) -Encoding ASCII
    & $hostExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '../Maintain.ps1') -Root $root -PointerPath $pointer -Apply
    if ($LASTEXITCODE -eq 0) { throw 'ambiguous owner records were accepted' }

    # -All must not reach the installer after an ownership refusal.
    $fakeInstaller = Join-Path $root 'Install-Modkit.ps1'
    Set-Content -LiteralPath $fakeInstaller -Value "Set-Content -LiteralPath (Join-Path '$root' 'ran.txt') -Value 'ran'" -Encoding ASCII
    & $hostExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '../Maintain.ps1') -Root $root -PointerPath $pointer -All
    if ($LASTEXITCODE -eq 0) { throw '-All continued after an ownership refusal' }
    if (Test-Path -LiteralPath (Join-Path $root 'ran.txt')) { throw '-All ran the installer after an ownership refusal' }
    Remove-Item -LiteralPath $fakeInstaller -Force

    Write-Output 'maintenance checks ok'
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
exit 0
