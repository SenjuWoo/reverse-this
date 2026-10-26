#Requires -Version 5.1
<# Install or update a released workbench's public source from its official digest-verified archive.
   Private sandbox files/settings stay in place; retained backups and errors live under sandbox/backups and sandbox/log.
   Git checkouts use their normal reviewed Git workflow instead. Plan/Offline/NoUpdate write and download nothing. #>
[CmdletBinding()]
param([switch]$Plan, [switch]$Offline, [switch]$NoUpdate, [switch]$DebugLog, [string]$Archive, [string]$Sha256,
    [Alias('KitRoot')][string]$Destination = $PSScriptRoot)
$ErrorActionPreference = 'Stop'

# Failures and version transitions remain local; detailed paths are opt-in.
function Write-SourceUpdateLog {
    param([string]$Message, [switch]$Detail)
    if (-not $sourceLog -or ($Detail -and -not $DebugLog)) { return }
    Add-Content -LiteralPath $sourceLog -Value ((Get-Date -Format 's') + ' ' + $Message) -Encoding UTF8
}

# Only repository source paths are eligible; release manifests never authorize private or Git writes.
function Test-PublicSourcePath {
    param([string]$Path)
    return $Path -match '^(?:[A-Za-z][A-Za-z0-9.-]*\.(?:ps1|cmd|md|txt|json)|VERSION|LICENSE|\.(?:gitattributes|gitignore)|(?:catalog|docs|tests|\.github)/[^:]+)$' -and
        $Path -notmatch '(^|/)\.\.(/|$)|\\|(^|/)\.git(/|$)'
}

# Existing links anywhere above a write could redirect an otherwise valid source path.
function Assert-SourceWritePath {
    param([string]$Path)
    $probe = $Path
    while ($probe) {
        if ((Test-Path -LiteralPath $probe) -and ((Get-Item -LiteralPath $probe).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Linked source destination refused: $Path" }
        $parent = Split-Path -Parent $probe
        if ($parent -eq $probe) { break }
        $probe = $parent
    }
}

# Check paths, symlinks, file hashes and version before any installed source file is touched.
function Read-SourceRelease {
    param([string]$Directory)
    $manifest = Get-Content -LiteralPath (Join-Path $Directory 'RELEASE.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.product -ne 'Reverse THIS!' -or $manifest.version -notmatch '^\d+\.\d+\.\d+$' -or
        $manifest.commit -notmatch '^[a-f0-9]{40}$' -or -not $manifest.files) { throw 'Invalid source release receipt.' }
    $seen = @{}
    foreach ($file in $manifest.files) {
        # Old release receipts include three harmless sandbox documentation placeholders; never deploy them.
        if ($file.path -in @('sandbox/README.md','sandbox/manual/README.md','sandbox/work/.gitkeep')) { continue }
        if (-not (Test-PublicSourcePath $file.path) -or $seen.ContainsKey($file.path) -or $file.sha256 -notmatch '^[a-f0-9]{64}$') { throw "Unsafe/duplicate source receipt path: $($file.path)" }
        $seen[$file.path] = $true
        $path = Join-Path $Directory $file.path
        Assert-SourceWritePath $path
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $file.sha256) { throw "Source receipt mismatch: $($file.path)" }
    }
    foreach ($required in @('Install-Modkit.ps1','VERSION','catalog/tools.json')) {
        if (-not $seen.ContainsKey($required)) { throw "Source receipt omitted $required" }
    }
    if ((Get-Content -LiteralPath (Join-Path $Directory 'VERSION') -Raw).Trim() -ne $manifest.version) { throw 'Source VERSION disagrees with its receipt.' }
    return $manifest
}

if ($Plan -or $Offline -or $NoUpdate) {
    Write-Host "Source update disabled/read-only. Owner: $Destination; official release: https://github.com/SenjuWoo/reverse-this/releases/latest"
    exit 0
}
$updateRoot = [IO.Path]::GetFullPath($Destination).TrimEnd('\')
if (-not [IO.Path]::IsPathRooted($Destination) -or $updateRoot -eq [IO.Path]::GetPathRoot($updateRoot).TrimEnd('\')) { throw 'Destination must be an absolute non-root directory.' }
$fresh = -not (Test-Path -LiteralPath (Join-Path $updateRoot 'VERSION') -PathType Leaf)
if ($fresh -and (Test-Path -LiteralPath $updateRoot) -and @(Get-ChildItem -LiteralPath $updateRoot -Force).Count) { throw 'Nonempty unowned destination preserved; select an empty destination or an existing released workbench.' }
$currentVersion = if ($fresh) { '0.0.0' } else { (Get-Content -LiteralPath (Join-Path $updateRoot 'VERSION') -Raw).Trim() }
$ancestor = $updateRoot
while ($ancestor) {
    if (Test-Path -LiteralPath (Join-Path $ancestor '.git')) { throw 'Git development checkout preserved. Fetch/review and fast-forward through Git instead of the release updater.' }
    $parent = Split-Path -Parent $ancestor
    if ($parent -eq $ancestor) { break }
    $ancestor = $parent
}
Assert-SourceWritePath $updateRoot
$logDirectory = Join-Path $updateRoot 'sandbox\log'
Assert-SourceWritePath $logDirectory
$sourceLog = $null
if (-not $fresh) {
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    $sourceLog = Join-Path $logDirectory 'source-update.log'
    Write-SourceUpdateLog ('source update from ' + $currentVersion)
}
$temp = Join-Path ([IO.Path]::GetTempPath()) ('reverse-this-update-' + [guid]::NewGuid().ToString('N'))
$lock = $null
$changed = @()
$backup = $null
try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    if (-not $Archive) {
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/SenjuWoo/reverse-this/releases/latest' -Headers @{ 'User-Agent'='ReverseTHIS-Updater' } -UseBasicParsing
        if ($release.tag_name -notmatch '^v\d+\.\d+\.\d+$') { throw 'Invalid official release version.' }
        if ([version]$release.tag_name.TrimStart('v') -le [version]$currentVersion) { Write-Host 'Workbench source is current or newer.'; exit 0 }
        $assets = @($release.assets | Where-Object { $_.name -eq ('Reverse-This-' + $release.tag_name.TrimStart('v') + '.zip') })
        if ($assets.Count -ne 1 -or $assets[0].digest -notmatch '^sha256:([a-f0-9]{64})$') { throw 'Official source archive lacks a unique SHA-256 asset digest.' }
        $Sha256 = $Matches[1]
        $url = [string]$assets[0].browser_download_url
        if ($url -notmatch '^https://github\.com/SenjuWoo/reverse-this/releases/download/v\d+\.\d+\.\d+/Reverse-This-\d+\.\d+\.\d+\.zip$') { throw 'Unexpected official archive URL.' }
        $Archive = Join-Path $temp 'release.zip'
        Invoke-WebRequest -Uri $url -OutFile $Archive -UseBasicParsing
    }
    if ($Sha256 -notmatch '^[a-fA-F0-9]{64}$' -or (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash -ne $Sha256) { throw 'Source archive SHA-256 mismatch or missing expected digest.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    $unpack = Join-Path $temp 'source'
    try {
        foreach ($entry in $zip.Entries) {
            $path = $entry.FullName.Replace('\','/')
            if ($path -match '(^|/)\.\.(/|$)|^/|:' -or (($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) { throw 'Unsafe source archive entry.' }
        }
        [IO.Compression.ZipFileExtensions]::ExtractToDirectory($zip, $unpack)
    } finally { $zip.Dispose() }
    if (-not (Test-Path -LiteralPath (Join-Path $unpack 'RELEASE.json'))) {
        $children = @(Get-ChildItem -LiteralPath $unpack -Directory)
        if ($children.Count -ne 1) { throw 'Expected one source release root.' }
        $unpack = $children[0].FullName
    }
    $manifest = Read-SourceRelease $unpack
    if ([version]$manifest.version -le [version]$currentVersion) { Write-Host 'Workbench source is current or newer.'; exit 0 }
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    $sourceLog = Join-Path $logDirectory 'source-update.log'
    Write-SourceUpdateLog ('source update from ' + $currentVersion)
    Write-SourceUpdateLog -Detail "destination=$updateRoot release=$($manifest.version) commit=$($manifest.commit) files=$(@($manifest.files).Count)"
    $sandbox = Join-Path $updateRoot 'sandbox'
    New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
    $lock = [IO.File]::Open((Join-Path $sandbox '.install.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    # Only unchanged release-owned files may be replaced; new release paths must not collide with personal files.
    $previousPaths = @()
    if (-not $fresh) {
        try { $previous = Read-SourceRelease $updateRoot }
        catch { throw "Installed source was changed or its release receipt is invalid; preserved: $($_.Exception.Message)" }
        if ([version]$manifest.version -le [version]$previous.version) { Write-Host 'Workbench source advanced during download; current or newer source preserved.'; exit 0 }
        $previousPaths = @($previous.files | ForEach-Object path)
    }
    foreach ($file in $manifest.files) {
        if ((Test-PublicSourcePath $file.path) -and $file.path -notin $previousPaths -and
            (Test-Path -LiteralPath (Join-Path $updateRoot $file.path))) { throw "New release path collides with a personal file; preserved: $($file.path)" }
    }
    $backup = Join-Path $sandbox ('backups/source-' + $manifest.version + '-' + [guid]::NewGuid().ToString('N'))
    Assert-SourceWritePath $backup
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    $paths = @($manifest.files | Where-Object { Test-PublicSourcePath $_.path } | ForEach-Object path) + @('RELEASE.json')
    foreach ($relative in $paths) {
        $target = Join-Path $updateRoot $relative
        $directory = Split-Path -Parent $target
        Assert-SourceWritePath $target
        $old = Join-Path $backup $relative
        $existed = Test-Path -LiteralPath $target
        if ($existed) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $old) | Out-Null; Copy-Item -LiteralPath $target -Destination $old }
        $changed += [pscustomobject]@{ path=$target; backup=$old; existed=$existed }
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
        $pending = Join-Path $directory ('.reverse-update-' + [guid]::NewGuid().ToString('N'))
        try { Copy-Item -LiteralPath (Join-Path $unpack $relative) -Destination $pending; Move-Item -LiteralPath $pending -Destination $target -Force }
        finally { if (Test-Path -LiteralPath $pending) { Remove-Item -LiteralPath $pending -Force } }
    }
    Write-Host "Updated source to $($manifest.version). Previous files retained: $backup. Run Install-Modkit.ps1 to update selected tools."
    Write-SourceUpdateLog "source updated to $($manifest.version); rollback=$backup"
} catch {
    $failure = $_
    $rollbackErrors = @()
    foreach ($entry in @($changed | Sort-Object { $_.path.Length } -Descending)) {
        try {
            if ($entry.existed) { Copy-Item -LiteralPath $entry.backup -Destination $entry.path -Force }
            elseif (Test-Path -LiteralPath $entry.path) { Remove-Item -LiteralPath $entry.path -Force }
        } catch { $rollbackErrors += $_.Exception.Message }
    }
    Write-SourceUpdateLog "FAIL $($failure.Exception.Message)"
    if ($rollbackErrors.Count) { throw "Source update failed: $($failure.Exception.Message). Rollback incomplete: $($rollbackErrors -join '; ')" }
    throw $failure
} finally {
    if ($lock) { $lock.Dispose() }
    if (Test-Path -LiteralPath $temp) {
        $resolved = [IO.Path]::GetFullPath($temp)
        if ((Split-Path -Parent $resolved).TrimEnd('\') -ne ([IO.Path]::GetTempPath()).TrimEnd('\') -or
            (Split-Path -Leaf $resolved) -notmatch '^reverse-this-update-[a-f0-9]{32}$' -or
            ((Get-Item -LiteralPath $resolved).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Unsafe source-update temporary cleanup refused.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
