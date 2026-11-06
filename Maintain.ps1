# Keep the local Reverse THIS! kit healthy without touching user work.
# Dry-run by default; -Apply removes only explicitly owned disposable files.
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
$statePath = Join-Path $sandbox 'installed.json'
$stale = New-Object System.Collections.ArrayList
$failures = New-Object System.Collections.ArrayList
$ownerMismatch = $false

function Get-Normalized { param([string]$Path) return [IO.Path]::GetFullPath($Path).TrimEnd('\') }
function Test-UnderRoot {
    param([string]$Path, [string]$Parent)
    $p = Get-Normalized $Path
    $r = (Get-Normalized $Parent) + '\'
    return $p.StartsWith($r, [StringComparison]::OrdinalIgnoreCase)
}

# A junction or symlink is never a disposable target, even when its name looks owned.
function Test-ReparsePoint {
    param([string]$Path)
    $p = Get-Normalized $Path
    while ($p) {
        if (Test-Path -LiteralPath $p) {
            if ((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { return $true }
        }
        $parent = Split-Path -Parent $p
        if (-not $parent -or $parent -eq $p) { break }
        $p = $parent
    }
    return $false
}

# Only these paths can be deleted; target work, tools and manual payloads are excluded.
function Test-CleanupAllowed {
    param([string]$Path)
    $p = Get-Normalized $Path
    foreach ($base in @((Join-Path $sandbox 'tmp'), (Join-Path $sandbox 'backups'), (Join-Path $sandbox 'work\runtime-smoke'))) {
        if (Test-UnderRoot $p $base) { return $true }
    }
    if ((Split-Path -Parent $p) -eq (Get-Normalized $sandbox) -and (Split-Path -Leaf $p) -match '^installed\.json\.pre-.*\.json$') { return $true }
    if ((Split-Path -Parent $p) -eq (Get-Normalized (Split-Path -Parent $PointerPath)) -and (Split-Path -Leaf $p) -match '^kit\.json\.pre-.*$') { return $true }
    if ((Split-Path -Leaf $p) -eq '__pycache__') {
        foreach ($base in @((Join-Path $Root 'scripts'), (Join-Path $Root 'tests'), (Join-Path $Root 'kit'))) {
            if (Test-UnderRoot $p $base) { return $true }
        }
    }
    return $false
}

function Add-Stale {
    param([string]$Path, [string]$Reason)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    if (-not (Test-CleanupAllowed $Path)) { [void]$failures.Add("refused non-owned cleanup target: $Path"); return }
    if (Test-ReparsePoint $Path) { [void]$failures.Add("refused linked cleanup target: $Path"); return }
    $item = Get-Item -LiteralPath $Path -Force
    $bytes = if ($item.PSIsContainer) {
        (Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    } else { $item.Length }
    [void]$stale.Add([pscustomobject]@{ Path = $Path; Reason = $Reason; Bytes = [int64]$(if ($null -eq $bytes) { 0 } else { $bytes }) })
}

function Remove-Stale {
    param($Items)
    foreach ($item in $Items) {
        try {
            # Revalidate immediately before the destructive operation.
            if (-not (Test-CleanupAllowed $item.Path) -or (Test-ReparsePoint $item.Path)) { throw 'cleanup target changed ownership or became a link' }
            Remove-Item -LiteralPath $item.Path -Recurse -Force -ErrorAction Stop
            Write-Host ("removed {0} ({1})" -f $item.Path, $item.Reason)
        } catch {
            [void]$failures.Add("$($item.Path): $($_.Exception.Message)")
        }
    }
}

function Write-AtomicText {
    param([string]$Path, [string]$Text)
    $temp = $Path + '.new'
    [IO.File]::WriteAllText($temp, $Text, (New-Object Text.UTF8Encoding $false))
    $replacing = Test-Path -LiteralPath $Path
    if ($replacing) { [IO.File]::Replace($temp, $Path, [NullString]::Value) } else { [IO.File]::Move($temp, $Path) }
}

# Repair either owner record, or both, from the current checkout. A pointer that
# names another existing kit, or a manifest that is not a usable owner, is ambiguous.
function Repair-Owner {
    $pointerExists = Test-Path -LiteralPath $PointerPath -PathType Leaf
    $stateExists = Test-Path -LiteralPath $statePath -PathType Leaf
    if (-not $pointerExists -and -not $stateExists) { return }

    $receipt = $null
    $state = $null
    if ($pointerExists) {
        try { $receipt = Get-Content -LiteralPath $PointerPath -Raw -Encoding UTF8 | ConvertFrom-Json }
        catch { Write-Host "owner pointer is unreadable: $PointerPath"; return }
    }
    if ($stateExists) {
        try {
            $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($state.schema -ne 1 -or -not $state.tools -or -not @($state.tools.PSObject.Properties).Count) { throw 'installed state is not a usable owner manifest' }
        } catch { Write-Host "owner repair refused: $($_.Exception.Message)"; return }
    } else {
        Write-Host "owner repair refused: no installed manifest at $statePath"
        return
    }

    $needPointer = $pointerExists -and (
        -not $receipt.kit_root -or (Get-Normalized ([string]$receipt.kit_root)) -ne $Root -or
        -not $receipt.installed_json -or (Get-Normalized ([string]$receipt.installed_json)) -ne $statePath -or
        -not $receipt.bin -or (Get-Normalized ([string]$receipt.bin)) -ne (Join-Path $Root 'sandbox\bin')
    )
    $stateOwner = [string]$state.kit_root
    $needState = -not $stateOwner -or (Get-Normalized $stateOwner) -ne $Root

    if ($needPointer -and $receipt.kit_root -and (Get-Normalized ([string]$receipt.kit_root)) -ne $Root -and
        (Test-Path -LiteralPath ([string]$receipt.kit_root) -PathType Container)) {
        Write-Host "owner pointer names another existing kit; leaving both records untouched: $($receipt.kit_root)"
        return
    }
    if ($needState -and $stateOwner -and (Get-Normalized $stateOwner) -ne $Root -and
        (Test-Path -LiteralPath $stateOwner -PathType Container)) {
        Write-Host "installed manifest names another existing kit; leaving both records untouched: $stateOwner"
        return
    }
    if (-not $needPointer -and -not $needState) { return }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $stateBackup = "$statePath.pre-move-$stamp.json"
    $pointerBackup = if ($pointerExists) { "$PointerPath.pre-move-$stamp" } else { $null }
    Copy-Item -LiteralPath $statePath -Destination $stateBackup
    if ($pointerExists) { Copy-Item -LiteralPath $PointerPath -Destination $pointerBackup }
    try {
        if ($needState) {
            $state.kit_root = $Root
            Write-AtomicText -Path $statePath -Text ($state | ConvertTo-Json -Depth 100)
        }
        if ($needPointer -or $needState) {
            $new = [ordered]@{
                java_home = if ($receipt) { $receipt.java_home } else { $state.java_home }
                bin = (Join-Path $Root 'sandbox\bin')
                installed_json = $statePath
                kit_root = $Root
            }
            Write-AtomicText -Path $PointerPath -Text ($new | ConvertTo-Json)
        }
        $readState = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $readPointer = Get-Content -LiteralPath $PointerPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ((Get-Normalized $readState.kit_root) -ne $Root -or (Get-Normalized $readPointer.kit_root) -ne $Root) { throw 'repaired owner records did not read back consistently' }
        Write-Host "repaired owner records: $Root (state backup: $stateBackup; pointer backup: $pointerBackup)"
    } catch {
        Copy-Item -LiteralPath $stateBackup -Destination $statePath -Force -ErrorAction SilentlyContinue
        if ($pointerExists) { Copy-Item -LiteralPath $pointerBackup -Destination $PointerPath -Force -ErrorAction SilentlyContinue }
        throw "owner repair rolled back: $($_.Exception.Message)"
    }
}

function Get-ValidationPython {
    foreach ($candidate in @($env:UABS_PYTHON, (Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source))) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $candidate }
    }
    return $null
}

function Test-Packaged {
    $catalog = Get-Content -LiteralPath (Join-Path $Root 'catalog\tools.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $catalog.tools -or -not @($catalog.tools).Count) { throw 'catalog/tools.json has no tools' }
    $version = (Get-Content -LiteralPath (Join-Path $Root 'VERSION') -Raw -Encoding UTF8).Trim()
    if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'VERSION is not semantic' }
    foreach ($name in @('Maintain.ps1', 'maintain.cmd', 'Install-Modkit.ps1', 'catalog\tools.json')) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $name))) { throw "packaged file missing: $name" }
    }
    Write-Host "packaged checks ok: $version, $($catalog.tools.Count) tools"
}

function Test-Local {
    $tests = Join-Path $Root 'tests'
    if (Test-Path -LiteralPath (Join-Path $tests 'test_catalog.py') -PathType Leaf) {
        $python = Get-ValidationPython
        if ($python) {
            & $python (Join-Path $tests 'test_catalog.py')
            if ($LASTEXITCODE -ne 0) { throw 'catalog test failed' }
            & $python (Join-Path $tests 'test_encyclopedia.py')
            if ($LASTEXITCODE -ne 0) { throw 'encyclopedia test failed' }
            return
        }
    }
    Test-Packaged
}

if (-not (Test-Path -LiteralPath $sandbox -PathType Container)) {
    if ($UpdateTools) {
        # The installer creates the sandbox; no cleanup or repair can run before it exists.
    } elseif ($Apply -or $All) {
        Write-Host "No installed kit state under $Root; nothing to clean."
        exit 0
    } else {
        Test-Packaged
        exit 0
    }
} else {
    if (Test-Path -LiteralPath $statePath -PathType Leaf) {
        try {
            $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
            $stateOwner = [string]$state.kit_root
            if ($stateOwner -and (Get-Normalized $stateOwner) -ne $Root) {
                $ownerMismatch = $true
                Write-Host "owner state points at $stateOwner; -Apply validates and repairs both records."
            }
        } catch { Write-Host "installed state is unreadable: $statePath" }
    }
}

if ($All) { $Apply = $true; $UpdateTools = $true; $Test = $true }
if (Test-Path -LiteralPath $sandbox -PathType Container) {
    $cleanupLock = $null
    if ($Apply) {
        $lockPath = Join-Path $sandbox '.install.lock'
        try { $cleanupLock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None') }
        catch { throw 'Another installer is using this kit; maintenance was not started.' }
    }
    try {
        if ($Apply) { Repair-Owner }
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
        }
        $tmp = Join-Path $sandbox 'tmp'
        if (Test-Path -LiteralPath $tmp) {
            Get-ChildItem -LiteralPath $tmp -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddHours(-24) -or (Test-ReparsePoint $_.FullName) } |
                ForEach-Object { Add-Stale $_.FullName 'installer temp older than 24h or linked entry' }
        }
        $smoke = Join-Path $sandbox 'work\runtime-smoke'
        if (Test-Path -LiteralPath $smoke) {
            Get-ChildItem -LiteralPath $smoke -Directory -Filter 'run-*' -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -Skip 1 |
                ForEach-Object { Add-Stale $_.FullName 'old smoke run' }
        }
        # Only source/test caches; never sandbox/work, sandbox/manual or third-party tools.
        foreach ($base in @((Join-Path $Root 'scripts'), (Join-Path $Root 'tests'), (Join-Path $Root 'kit'))) {
            if (Test-Path -LiteralPath $base) {
                Get-ChildItem -LiteralPath $base -Recurse -Directory -Filter '__pycache__' -Force -ErrorAction SilentlyContinue |
                    ForEach-Object { Add-Stale $_.FullName 'generated Python cache' }
            }
        }
        $bytes = [int64](($stale | Measure-Object -Property Bytes -Sum).Sum | ForEach-Object { if ($null -eq $_) { 0 } else { $_ } })
        Write-Host ("{0}: {1} stale item(s), {2:N1} MB" -f $Root, $stale.Count, ($bytes / 1MB))
        $stale | ForEach-Object { Write-Host ("  {0}  {1}" -f $_.Reason, $_.Path) }
        if ($Apply -and $stale.Count) { Remove-Stale $stale }
    } finally { if ($cleanupLock) { $cleanupLock.Dispose() } }
}

if ($UpdateTools) {
    $hostExe = (Get-Process -Id $PID).Path
    & $hostExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'Install-Modkit.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'tool update failed' }
    & $hostExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'Install-Modkit.ps1') -Doctor
    if ($LASTEXITCODE -ne 0) { throw 'doctor failed' }
}
if ($Test) { Test-Local }
if ($failures.Count) { $failures | ForEach-Object { Write-Error $_ }; exit 1 }
if (-not $Apply -and -not $Test -and ($stale.Count -or $ownerMismatch)) { Write-Host 'Report only. Re-run with -Apply to repair or remove kit-owned leftovers.'; exit 1 }
exit 0
