#Requires -Version 5.1
<#
.SYNOPSIS
  Install the Reverse THIS! modkit into stable paths under this repo.

.DESCRIPTION
  Downloads the current official Windows build of each tool in catalog/tools.json
  into sandbox\tools and writes shims in sandbox\bin. A later chat reads
  sandbox\installed.json or %LOCALAPPDATA%\ReverseThis\kit.json.
  It does not search the disk for tools you already installed somewhere else.
#>
[CmdletBinding()]
param(
    [switch]$Plan,
    [switch]$SelfTest,
    [switch]$Force,
    [string[]]$Only
)

$ErrorActionPreference = 'Stop'
$KitRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$CatalogPath = Join-Path $KitRoot 'catalog\tools.json'
$FixturePath = Join-Path $KitRoot 'tests\fixtures\assets.json'
$Sandbox = Join-Path $KitRoot 'sandbox'
$BinDir = Join-Path $Sandbox 'bin'
$ToolsDir = Join-Path $Sandbox 'tools'
$TmpDir = Join-Path $Sandbox 'tmp'
$LogDir = Join-Path $Sandbox 'log'
$LogPath = Join-Path $LogDir 'modkit.log'
$StatePath = Join-Path $Sandbox 'installed.json'
$PointerDir = Join-Path $env:LOCALAPPDATA 'ReverseThis'
$PointerPath = Join-Path $PointerDir 'kit.json'

function Write-Log {
    param([string]$Message)
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Write-Host $line
    if (Test-Path $LogDir) {
        Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
    }
}

function Get-Catalog {
    return (Get-Content -LiteralPath $CatalogPath -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function ConvertTo-Array {
    param($Value)
    if ($null -eq $Value) { return @() }
    return @($Value)
}

function Get-ReleaseApiUrl {
    param([string]$Repo, [string]$Release)
    if ($Release) {
        return 'https://api.github.com/repos/{0}/releases/tags/{1}' -f $Repo, $Release
    }
    return 'https://api.github.com/repos/{0}/releases/latest' -f $Repo
}

function Get-RenderDocZipUrl {
    param([string]$Tag)
    if ($Tag -notmatch '^v(\d+\.\d+)$') {
        throw "RenderDoc tag '$Tag' is not a stable vMAJOR.MINOR tag"
    }
    $version = $Matches[1]
    return 'https://renderdoc.org/stable/{0}/RenderDoc_{0}_64.zip' -f $version
}

function Test-AllowedDownloadUrl {
    param([string]$Url)
    $uri = [Uri]$Url
    if ($uri.Scheme -ne 'https') { return $false }
    if ($uri.Host -eq 'github.com') { return $true }
    if ($uri.Host -eq 'objects.githubusercontent.com') { return $true }
    if ($uri.Host -eq 'release-assets.githubusercontent.com') { return $true }
    if ($uri.Host -eq 'renderdoc.org' -and $uri.AbsolutePath.StartsWith('/stable/')) { return $true }
    return $false
}

function Select-OneAsset {
    param($Assets, [string]$Pattern)
    $regex = New-Object System.Text.RegularExpressions.Regex $Pattern
    $hits = @(ConvertTo-Array $Assets | Where-Object { $regex.IsMatch([string]$_.name) })
    if ($hits.Count -ne 1) {
        $names = (@($hits | ForEach-Object { $_.name })) -join ', '
        throw "pattern [$Pattern] matched $($hits.Count) assets: $names"
    }
    return $hits[0]
}

function Invoke-SelfTest {
    $catalog = Get-Catalog
    $fixture = Get-Content -LiteralPath $FixturePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $failed = @()
    foreach ($tool in (ConvertTo-Array $catalog.tools)) {
        if ($tool.method -eq 'github-release') {
            $row = $fixture.($tool.id)
            if ($null -eq $row) { $failed += "$($tool.id) has no fixture"; continue }
            $assets = @(ConvertTo-Array $row.assets | ForEach-Object { [pscustomobject]@{ name = [string]$_ } })
            try {
                $hit = Select-OneAsset -Assets $assets -Pattern $tool.asset_pattern
                if ($hit.name -ne $row.expect) {
                    $failed += "$($tool.id) matched $($hit.name), expected $($row.expect)"
                }
            } catch {
                $failed += "$($tool.id) $($_.Exception.Message)"
            }
        } elseif ($tool.method -eq 'github-files') {
            $row = $fixture.($tool.id)
            $have = @(ConvertTo-Array $row.assets)
            foreach ($file in (ConvertTo-Array $tool.files)) {
                if ($have -notcontains $file) { $failed += "$($tool.id) fixture lacks $file" }
            }
        }
    }
    $url = Get-RenderDocZipUrl -Tag 'v1.46'
    if ($url -ne 'https://renderdoc.org/stable/1.46/RenderDoc_1.46_64.zip') {
        $failed += "renderdoc url drifted: $url"
    }
    $bad = $false
    try { Get-RenderDocZipUrl -Tag 'nightly' | Out-Null; $bad = $true } catch { }
    if ($bad) { $failed += 'renderdoc url builder accepted a bad tag' }
    $ue = ConvertTo-Array $catalog.tools | Where-Object { $_.id -eq 'ue4ss' } | Select-Object -First 1
    $api = Get-ReleaseApiUrl -Repo $ue.repo -Release $ue.release
    if ($api -notlike '*/releases/tags/experimental-latest') {
        $failed += "ue4ss api url is $api"
    }
    if ($failed.Count -gt 0) {
        $failed | ForEach-Object { Write-Host "FAIL $_" }
        exit 1
    }
    Write-Host 'selftest ok'
    exit 0
}

function Invoke-Plan {
    $catalog = Get-Catalog
    foreach ($tool in (ConvertTo-Array $catalog.tools)) {
        $detail = $tool.method
        if ($tool.repo) { $detail = "$detail $($tool.repo)" }
        if ($tool.release) { $detail = "$detail tag=$($tool.release)" }
        if ($tool.asset_pattern) { $detail = "$detail $($tool.asset_pattern)" }
        Write-Host ("{0}`t{1}" -f $tool.id, $detail)
    }
    exit 0
}

if ($SelfTest) { Invoke-SelfTest }
if ($Plan) { Invoke-Plan }

New-Item -ItemType Directory -Force -Path $BinDir, $ToolsDir, $TmpDir, $LogDir, $PointerDir | Out-Null
$kitVersion = (Get-Content -LiteralPath (Join-Path $KitRoot 'VERSION') -Raw -Encoding UTF8).Trim()
Write-Log "reverse-this $kitVersion  root=$KitRoot"

function Save-Url {
    param([string]$Url, [string]$Dest)
    if (-not (Test-AllowedDownloadUrl $Url)) { throw "refusing download URL $Url" }
    $parent = Split-Path -Parent $Dest
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    if (Test-Path -LiteralPath $Dest) { Remove-Item -LiteralPath $Dest -Force }
    $curl = Join-Path $env:SystemRoot 'System32\curl.exe'
    if (-not (Test-Path -LiteralPath $curl)) { throw 'curl.exe is not in System32' }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $curl -sS -L --fail --retry 3 --retry-delay 2 -A 'reverse-this' -o $Dest $Url
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -ne 0 -or -not (Test-Path -LiteralPath $Dest)) {
        throw "download failed ($code) $Url"
    }
    if ((Get-Item -LiteralPath $Dest).Length -le 0) { throw "empty download $Url" }
}

function Get-Sha256Hex {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-GitHubRelease {
    param([string]$Repo, [string]$Release)
    $headers = @{
        'User-Agent' = 'reverse-this'
        'Accept' = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
    }
    $url = Get-ReleaseApiUrl -Repo $Repo -Release $Release
    return Invoke-RestMethod -Headers $headers -Uri $url
}

function Get-SingleBodyHash {
    param([string]$Body)
    $found = [regex]::Matches([string]$Body, '(?i)\b[a-f0-9]{64}\b')
    if ($found.Count -eq 1) { return $found[0].Value.ToLowerInvariant() }
    return $null
}

function Get-PublishedHash {
    param($Release, [string]$AssetName)
    $siblingName = "$AssetName.sha256"
    $sibling = @(ConvertTo-Array $Release.assets | Where-Object { $_.name -eq $siblingName })
    if ($sibling.Count -eq 1) {
        $hashFile = Join-Path $TmpDir $siblingName
        Save-Url -Url $sibling[0].browser_download_url -Dest $hashFile
        $text = Get-Content -LiteralPath $hashFile -Raw -Encoding UTF8
        $match = [regex]::Match($text, '(?i)\b[a-f0-9]{64}\b')
        if (-not $match.Success) { throw "could not read hash from $siblingName" }
        return @{ hash = $match.Value.ToLowerInvariant(); source = 'asset' }
    }
    $bodyHash = Get-SingleBodyHash -Body ([string]$Release.body)
    if ($bodyHash) { return @{ hash = $bodyHash; source = 'release-body' } }
    return $null
}

function Expand-FlattenedZip {
    param([string]$Zip, [string]$Dest)
    $stage = Join-Path $TmpDir ('stage-' + [guid]::NewGuid().ToString('N'))
    $fresh = Join-Path $TmpDir ('fresh-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $stage, $fresh | Out-Null
    try {
        $tar = Join-Path $env:SystemRoot 'System32\tar.exe'
        if (-not (Test-Path -LiteralPath $tar)) { throw 'tar.exe is not in System32' }
        $prev = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        & $tar -xf $Zip -C $stage
        $code = $LASTEXITCODE
        $ErrorActionPreference = $prev
        if ($code -ne 0) { throw "tar extract failed ($code)" }
        $items = @(Get-ChildItem -LiteralPath $stage -Force)
        $dirs = @($items | Where-Object { $_.PSIsContainer })
        $files = @($items | Where-Object { -not $_.PSIsContainer })
        $source = $stage
        if ($dirs.Count -eq 1 -and $files.Count -eq 0) { $source = $dirs[0].FullName }
        Get-ChildItem -LiteralPath $source -Force | ForEach-Object {
            Move-Item -LiteralPath $_.FullName -Destination $fresh
        }
        if (Test-Path -LiteralPath $Dest) { Remove-Item -LiteralPath $Dest -Recurse -Force }
        Move-Item -LiteralPath $fresh -Destination $Dest
    } finally {
        if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $fresh) { Remove-Item -LiteralPath $fresh -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Get-JavaMajor {
    param([string]$JavaExe)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & $JavaExe -version 2>&1 | Out-String
    $ErrorActionPreference = $prev
    if ($out -match 'version "1\.(\d+)') { return [int]$Matches[1] }
    if ($out -match 'version "(\d+)') { return [int]$Matches[1] }
    return 0
}

function Find-JdkHome {
    param([int]$Major)
    $homes = @()
    foreach ($n in $Major..40) {
        $homes += @(Get-Item -Path "C:\Program Files\Microsoft\jdk-$n*" -ErrorAction SilentlyContinue)
        $homes += @(Get-Item -Path "C:\Program Files\Eclipse Adoptium\jdk-$n*" -ErrorAction SilentlyContinue)
        $homes += @(Get-Item -Path "C:\Program Files\Java\jdk-$n*" -ErrorAction SilentlyContinue)
        $homes += @(Get-Item -Path (Join-Path $env:LOCALAPPDATA "Programs\Eclipse Adoptium\jdk-$n*") -ErrorAction SilentlyContinue)
    }
    foreach ($home in $homes) {
        $exe = Join-Path $home.FullName 'bin\java.exe'
        if ((Test-Path -LiteralPath $exe) -and (Get-JavaMajor $exe) -ge $Major) {
            return $home.FullName
        }
    }
    return $null
}

function Install-Jdk {
    param([int]$Major)
    $found = Find-JdkHome -Major $Major
    if ($found) { return $found }
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) { throw "JDK $Major is missing and winget is not available" }
    Write-Log "installing Microsoft.OpenJDK.$Major via winget"
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & winget install --id "Microsoft.OpenJDK.$Major" -e --accept-package-agreements --accept-source-agreements --disable-interactivity
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -ne 0) { throw "winget Microsoft.OpenJDK.$Major failed ($code)" }
    $found = Find-JdkHome -Major $Major
    if (-not $found) { throw "JDK $Major installed but its home was not found" }
    return $found
}

function Find-ToolFile {
    param([string]$Root, [string]$Glob, [string]$Prefer)
    $hits = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $Glob -ErrorAction SilentlyContinue)
    if ($hits.Count -eq 0) { return $null }
    if ($Prefer) {
        $preferred = @($hits | Where-Object { $_.FullName -match $Prefer })
        if ($preferred.Count -ge 1) { return $preferred[0] }
    }
    return $hits[0]
}

function Write-Utf8 {
    param([string]$Path, [string]$Text)
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Text, $utf8)
}

function Write-Shim {
    param(
        [string]$Name,
        [string]$Target,
        [string]$JavaHome
    )
    $rel = (Resolve-Path -LiteralPath $Target).Path
    $from = (Resolve-Path -LiteralPath $BinDir).Path
    if (-not $from.EndsWith('\')) { $from = $from + '\' }
    $base = New-Object System.Uri $from
    $to = New-Object System.Uri $rel
    $relative = [Uri]::UnescapeDataString($base.MakeRelativeUri($to).ToString()) -replace '/', '\'
    $lines = @('@echo off')
    if ($JavaHome) {
        $lines += 'set "JAVA_HOME=' + $JavaHome + '"'
        $lines += 'set "PATH=%JAVA_HOME%\bin;%PATH%"'
    }
    $lines += '"%~dp0' + $relative + '" %*'
    $dest = Join-Path $BinDir ($Name + '.cmd')
    Write-Utf8 -Path $dest -Text (($lines -join "`r`n") + "`r`n")
    return $dest
}

function Get-RelativeKitPath {
    param([string]$FullPath)
    $root = (Resolve-Path -LiteralPath $KitRoot).Path.TrimEnd('\')
    $full = (Resolve-Path -LiteralPath $FullPath).Path
    if ($full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return ($full.Substring($root.Length).TrimStart('\') -replace '\\', '/')
    }
    return $full
}

function Test-AlreadyInstalled {
    param([string]$Dest, [string]$Marker)
    $markerPath = Join-Path $Dest '.kit-ok'
    if ($Force) { return $false }
    if (-not (Test-Path -LiteralPath $markerPath)) { return $false }
    $have = (Get-Content -LiteralPath $markerPath -Raw -Encoding UTF8).Trim()
    return $have -eq $Marker
}

function Write-Marker {
    param([string]$Dest, [string]$Marker)
    Write-Utf8 -Path (Join-Path $Dest '.kit-ok') -Text ($Marker + "`n")
}

function Save-State {
    param($State)
    $json = $State | ConvertTo-Json -Depth 8
    Write-Utf8 -Path $StatePath -Text $json
    $pointer = [ordered]@{
        kit_root = $KitRoot
        installed_json = $StatePath
        bin = $BinDir
        java_home = $State.java_home
    }
    Write-Utf8 -Path $PointerPath -Text ($pointer | ConvertTo-Json -Depth 4)
}

function New-State {
    if (Test-Path -LiteralPath $StatePath) {
        $existing = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($existing.tools) { return $existing }
    }
    return [pscustomobject]@{
        schema = 1
        kit_version = $kitVersion
        kit_root = $KitRoot
        java_home = $null
        tools = [pscustomobject]@{}
    }
}

$script:JavaHome = $null

function Install-Shims {
    param($Tool, [string]$Dest)
    $made = @{}
    foreach ($shim in (ConvertTo-Array $Tool.shims)) {
        $file = Find-ToolFile -Root $Dest -Glob $shim.exe_glob -Prefer $shim.prefer_path
        if ($null -eq $file) {
            Write-Log "WARN $($Tool.id) shim $($shim.name) did not find $($shim.exe_glob)"
            continue
        }
        $java = $null
        if ($Tool.needs_jdk) { $java = $script:JavaHome }
        $cmd = Write-Shim -Name $shim.name -Target $file.FullName -JavaHome $java
        $made[$shim.name] = Get-RelativeKitPath $cmd
    }
    return $made
}

function Install-GitHubZipTool {
    param($Tool)
    $release = Get-GitHubRelease -Repo $Tool.repo -Release $Tool.release
    $asset = Select-OneAsset -Assets (ConvertTo-Array $release.assets) -Pattern $Tool.asset_pattern
    $dest = Join-Path $ToolsDir $Tool.id
    $marker = '{0}|{1}' -f $release.tag_name, $asset.name
    if (Test-AlreadyInstalled -Dest $dest -Marker $marker) {
        Write-Log "skip $($Tool.id) $marker"
        return
    }
    if ($Tool.needs_jdk -and -not $script:JavaHome) {
        $script:JavaHome = Install-Jdk -Major ([int]$Tool.needs_jdk)
        Write-Log "jdk home $($script:JavaHome)"
    }
    $zip = Join-Path $TmpDir $asset.name
    Write-Log "get $($Tool.id) $($release.tag_name) $($asset.name)"
    Save-Url -Url $asset.browser_download_url -Dest $zip
    $actual = Get-Sha256Hex $zip
    $published = Get-PublishedHash -Release $release -AssetName $asset.name
    $hashSource = 'computed'
    if ($published) {
        if ($published.hash -ne $actual) {
            throw "$($Tool.id) hash mismatch published=$($published.hash) actual=$actual"
        }
        $hashSource = $published.source
        Write-Log "hash ok $($Tool.id) $hashSource"
    }
    Expand-FlattenedZip -Zip $zip -Dest $dest
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    $shims = Install-Shims -Tool $Tool -Dest $dest
    Write-Marker -Dest $dest -Marker $marker
    return [pscustomobject]@{
        id = $Tool.id
        version = [string]$release.tag_name
        asset = [string]$asset.name
        sha256 = $actual
        hash_source = $hashSource
        dir = Get-RelativeKitPath $dest
        shims = $shims
    }
}

function Install-GitHubFilesTool {
    param($Tool)
    $release = Get-GitHubRelease -Repo $Tool.repo -Release $Tool.release
    $names = @(ConvertTo-Array $Tool.files)
    $dest = Join-Path $ToolsDir $Tool.id
    $marker = '{0}|{1}' -f $release.tag_name, ($names -join '+')
    if (Test-AlreadyInstalled -Dest $dest -Marker $marker) {
        Write-Log "skip $($Tool.id) $marker"
        return
    }
    $fresh = Join-Path $TmpDir ('files-' + $Tool.id)
    if (Test-Path $fresh) { Remove-Item $fresh -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $fresh | Out-Null
    $hashes = @{}
    foreach ($name in $names) {
        $asset = @(ConvertTo-Array $release.assets | Where-Object { $_.name -eq $name })
        if ($asset.Count -ne 1) { throw "$($Tool.id) release is missing $name" }
        $file = Join-Path $fresh $name
        Write-Log "get $($Tool.id) $($release.tag_name) $name"
        Save-Url -Url $asset[0].browser_download_url -Dest $file
        $actual = Get-Sha256Hex $file
        $published = Get-PublishedHash -Release $release -AssetName $name
        if ($published -and $published.hash -ne $actual) {
            throw "$($Tool.id) $name hash mismatch"
        }
        $hashes[$name] = $actual
    }
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    Move-Item -LiteralPath $fresh -Destination $dest
    $shims = Install-Shims -Tool $Tool -Dest $dest
    Write-Marker -Dest $dest -Marker $marker
    return [pscustomobject]@{
        id = $Tool.id
        version = [string]$release.tag_name
        asset = ($names -join '+')
        sha256 = $hashes
        hash_source = 'per-file'
        dir = Get-RelativeKitPath $dest
        shims = $shims
    }
}

function Install-RenderDocTool {
    param($Tool)
    $release = Get-GitHubRelease -Repo $Tool.repo -Release $null
    $url = Get-RenderDocZipUrl -Tag ([string]$release.tag_name)
    $dest = Join-Path $ToolsDir $Tool.id
    $marker = [string]$release.tag_name
    if (Test-AlreadyInstalled -Dest $dest -Marker $marker) {
        Write-Log "skip $($Tool.id) $marker"
        return
    }
    $zip = Join-Path $TmpDir ("RenderDoc_" + $release.tag_name + "_64.zip")
    Write-Log "get renderdoc $url"
    Save-Url -Url $url -Dest $zip
    $actual = Get-Sha256Hex $zip
    Expand-FlattenedZip -Zip $zip -Dest $dest
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    $shims = Install-Shims -Tool $Tool -Dest $dest
    Write-Marker -Dest $dest -Marker $marker
    return [pscustomobject]@{
        id = $Tool.id
        version = [string]$release.tag_name
        asset = $url
        sha256 = $actual
        hash_source = 'computed'
        dir = Get-RelativeKitPath $dest
        shims = $shims
    }
}

function Install-DotNetTool {
    param($Tool)
    $dest = Join-Path $ToolsDir $Tool.id
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    if ((Test-AlreadyInstalled -Dest $dest -Marker 'present') -and (Get-ChildItem -LiteralPath $dest -Filter ($Tool.shims[0].exe_glob) -Recurse -ErrorAction SilentlyContinue)) {
        Write-Log "skip $($Tool.id)"
        return
    }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & dotnet tool install $Tool.package --tool-path $dest
    if ($LASTEXITCODE -ne 0) {
        & dotnet tool update $Tool.package --tool-path $dest
    }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -ne 0) { throw "dotnet tool $($Tool.package) failed ($code)" }
    $shims = Install-Shims -Tool $Tool -Dest $dest
    Write-Marker -Dest $dest -Marker 'present'
    return [pscustomobject]@{
        id = $Tool.id
        version = 'dotnet-tool'
        asset = [string]$Tool.package
        sha256 = $null
        hash_source = 'nuget'
        dir = Get-RelativeKitPath $dest
        shims = $shims
    }
}

function Install-PipVenv {
    param($Tool)
    $dest = Join-Path $ToolsDir $Tool.id
    $exe = Join-Path $dest 'Scripts\frida.exe'
    if ((Test-Path -LiteralPath $exe) -and -not $Force) {
        Write-Log "skip $($Tool.id)"
        return
    }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & py -3 -m venv $dest
    if ($LASTEXITCODE -ne 0) { $ErrorActionPreference = $prev; throw "venv failed ($LASTEXITCODE)" }
    $pyexe = Join-Path $dest 'Scripts\python.exe'
    & $pyexe -m pip install --disable-pip-version-check $Tool.package
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -ne 0) { throw "pip install $($Tool.package) failed ($code)" }
    $shims = Install-Shims -Tool $Tool -Dest $dest
    Write-Marker -Dest $dest -Marker 'present'
    return [pscustomobject]@{
        id = $Tool.id
        version = 'pip'
        asset = [string]$Tool.package
        sha256 = $null
        hash_source = 'pypi'
        dir = Get-RelativeKitPath $dest
        shims = $shims
    }
}

function Install-One {
    param($Tool)
    switch ($Tool.method) {
        'github-release' { return Install-GitHubZipTool $Tool }
        'github-files' { return Install-GitHubFilesTool $Tool }
        'renderdoc-stable-zip' { return Install-RenderDocTool $Tool }
        'dotnet-tool' { return Install-DotNetTool $Tool }
        'pip-venv' { return Install-PipVenv $Tool }
        default { throw "unknown method $($Tool.method)" }
    }
}

$catalog = Get-Catalog
$selected = @(ConvertTo-Array $catalog.tools)
if ($Only) {
    $wanted = @($Only | ForEach-Object { $_.Split(',') } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
    $selected = @($selected | Where-Object { $wanted -contains $_.id })
    if ($selected.Count -eq 0) { throw "Only matched nothing: $($wanted -join ', ')" }
}
$state = New-State
$state.kit_version = $kitVersion
$state.kit_root = $KitRoot
$ok = @()
$bad = @()
$index = 0
foreach ($tool in $selected) {
    $index += 1
    Write-Log ("[{0}/{1}] {2}" -f $index, $selected.Count, $tool.id)
    try {
        $row = Install-One $tool
        if ($row) {
            $state.tools | Add-Member -NotePropertyName $tool.id -NotePropertyValue $row -Force
        }
        if ($script:JavaHome) { $state.java_home = $script:JavaHome }
        Save-State $state
        $ok += $tool.id
    } catch {
        Write-Log "FAIL $($tool.id): $($_.Exception.Message)"
        $bad += $tool.id
        Save-State $state
    }
}
Write-Log ("done ok={0} failed={1}" -f $ok.Count, $bad.Count)
if ($bad.Count -gt 0) {
    Write-Log ("failed: " + ($bad -join ', '))
    Write-Log "log: $LogPath"
    exit 1
}
Write-Log "bin: $BinDir"
Write-Log "pointer: $PointerPath"
exit 0
