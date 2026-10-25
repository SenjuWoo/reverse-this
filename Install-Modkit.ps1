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
    [switch]$Doctor,
    [switch]$DebugLog,
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
    param([string]$Message, [switch]$Detail)
    if ($Detail -and -not $DebugLog) { return }
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
    if ($uri.Host -eq 'virtualltek.com') {
        $path = $uri.AbsolutePath
        if ($path -eq '/download' -or $path -eq '/download/') { return $true }
        if ($path.StartsWith('/community/')) { return $true }
        if ($path.StartsWith('/wp-content/uploads/') -and $path.EndsWith('.zip')) { return $true }
        return $false
    }
    return $false
}

function Get-GitHubArchiveUrl {
    param([string]$Repo, [string]$Kind, [string]$Ref)
    if ($Repo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw "bad repo $Repo" }
    if ($Ref -notmatch '^[A-Za-z0-9._+-]+$') { throw "bad ref $Ref" }
    if ($Kind -eq 'tag') { return "https://github.com/$Repo/archive/refs/tags/$Ref.zip" }
    if ($Kind -eq 'branch') { return "https://github.com/$Repo/archive/refs/heads/$Ref.zip" }
    if ($Kind -eq 'commit' -and $Ref -match '^[0-9a-f]{40}$') { return "https://github.com/$Repo/archive/$Ref.zip" }
    throw "bad archive kind $Kind"
}

function Resolve-FighterFactoryZipUrl {
    param([string]$DownloadHtml, [string]$TopicHtml)
    if (-not $DownloadHtml) {
        $DownloadHtml = Get-WebText 'https://virtualltek.com/download/'
    }
    $topic = [regex]::Match($DownloadHtml, 'href="(/community/[^"]*winport[^"]*)"')
    if (-not $topic.Success) { throw 'Fighter Factory download page has no Windows portable topic' }
    $topicPath = $topic.Groups[1].Value
    if ($topicPath -notmatch '^/community/[A-Za-z0-9][A-Za-z0-9./_-]*winport/?$') {
        throw "Fighter Factory topic path rejected: $topicPath"
    }
    if (-not $TopicHtml) {
        $TopicHtml = Get-WebText ('https://virtualltek.com' + $topicPath)
    }
    $found = [regex]::Matches($TopicHtml, 'https://virtualltek\.com/wp-content/uploads/[A-Za-z0-9_./-]+\.zip')
    $urls = @($found | ForEach-Object { $_.Value } | Select-Object -Unique)
    if ($urls.Count -ne 1) { throw "Fighter Factory portable zip count is $($urls.Count)" }
    if (-not (Test-AllowedDownloadUrl $urls[0])) { throw "refusing download URL $($urls[0])" }
    return [string]$urls[0]
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
    $ffExpect = 'https://virtualltek.com/wp-content/uploads/wpforo/default_attachments/1/1707418391-375_windows_port.zip'
    $ffDownload = Get-Content -LiteralPath (Join-Path $KitRoot 'tests\fixtures\fighter-factory-download.html') -Raw -Encoding UTF8
    $ffTopic = Get-Content -LiteralPath (Join-Path $KitRoot 'tests\fixtures\fighter-factory-topic.html') -Raw -Encoding UTF8
    try {
        $ffZip = Resolve-FighterFactoryZipUrl -DownloadHtml $ffDownload -TopicHtml $ffTopic
        if ($ffZip -ne $ffExpect) { $failed += "fighter factory zip is $ffZip" }
    } catch {
        $failed += "fighter factory $($_.Exception.Message)"
    }
    $archiveUrl = Get-GitHubArchiveUrl -Repo 'SDmodding/SDK' -Kind 'branch' -Ref 'theory'
    if ($archiveUrl -ne 'https://github.com/SDmodding/SDK/archive/refs/heads/theory.zip') {
        $failed += "archive url drifted: $archiveUrl"
    }
    $tagUrl = Get-GitHubArchiveUrl -Repo 'risk-of-thunder/R2API' -Kind 'tag' -Ref '4.4.0'
    if ($tagUrl -ne 'https://github.com/risk-of-thunder/R2API/archive/refs/tags/4.4.0.zip') {
        $failed += "tag archive url drifted: $tagUrl"
    }
    $badArchive = $false
    try { Get-GitHubArchiveUrl -Repo 'SDmodding/SDK' -Kind 'branch' -Ref '../main' | Out-Null; $badArchive = $true } catch { }
    if ($badArchive) { $failed += 'archive url builder accepted a bad ref' }
    if (-not (Test-AllowedDownloadUrl $ffExpect)) { $failed += 'fighter factory zip was refused' }
    if (-not (Test-AllowedDownloadUrl 'https://virtualltek.com/download/')) { $failed += 'virtualltek download page was refused' }
    if (-not (Test-AllowedDownloadUrl 'https://virtualltek.com/community/3-7-5-studio/ff-375-winport')) { $failed += 'virtualltek topic was refused' }
    if (Test-AllowedDownloadUrl 'https://virtualltek.com/wp-content/uploads/setup.exe') { $failed += 'virtualltek exe was allowed' }
    if (Test-AllowedDownloadUrl 'https://mega.nz/file/game') { $failed += 'mega.nz was allowed' }
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

$kitVersion = (Get-Content -LiteralPath (Join-Path $KitRoot 'VERSION') -Raw -Encoding UTF8).Trim()

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
    & $curl -sS -L --proto '=https' --proto-redir '=https' --fail --retry 3 --retry-delay 2 -A 'reverse-this' -o $Dest $Url
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

function Get-GitHubHeaders {
    $headers = @{
        'User-Agent' = 'reverse-this'
        'Accept' = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
    }
    if (-not $script:GitHubTokenChecked) {
        $script:GitHubTokenChecked = $true
        $script:GitHubToken = $null
        $gh = Get-Command gh -ErrorAction SilentlyContinue
        if ($gh) {
            $prev = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            $tok = (& gh auth token 2>&1 | Out-String).Trim()
            $code = $LASTEXITCODE
            $ErrorActionPreference = $prev
            if ($code -eq 0 -and $tok -match '^(gho_|github_pat_|ghp_)') {
                $script:GitHubToken = $tok
            }
        }
    }
    if ($script:GitHubToken) { $headers.Authorization = 'Bearer ' + $script:GitHubToken }
    return $headers
}

function Get-GitHubRelease {
    param([string]$Repo, [string]$Release)
    $url = Get-ReleaseApiUrl -Repo $Repo -Release $Release
    return Invoke-RestMethod -Headers (Get-GitHubHeaders) -Uri $url
}

function Invoke-GitHubApi {
    param([string]$ApiPath)
    $url = 'https://api.github.com/' + $ApiPath.TrimStart('/')
    return Invoke-RestMethod -Headers (Get-GitHubHeaders) -Uri $url
}

function Get-WebText {
    param([string]$Url)
    if (-not (Test-AllowedDownloadUrl $Url)) { throw "refusing download URL $Url" }
    $dest = Join-Path $TmpDir ('page-' + [guid]::NewGuid().ToString('N') + '.html')
    Save-Url -Url $Url -Dest $dest
    try {
        return (Get-Content -LiteralPath $dest -Raw -Encoding UTF8)
    } finally {
        Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
    }
}

function Get-PublishedHash {
    param($Release, [string]$AssetName)
    $selected = @(ConvertTo-Array $Release.assets | Where-Object { $_.name -ceq $AssetName })
    if ($selected.Count -eq 1 -and $selected[0].digest -match '^sha256:([a-fA-F0-9]{64})$') {
        return @{ hash = $Matches[1].ToLowerInvariant(); source = 'github-digest' }
    }
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
    return $null
}

function Assert-OwnedToolPath {
    param([string]$Path)
    $root = [IO.Path]::GetFullPath($ToolsDir).TrimEnd('\') + '\'
    $full = [IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or
        (Split-Path -Parent $full) -ne $root.TrimEnd('\')) { throw "not an owned tool directory: $Path" }
    if (Test-Path -LiteralPath $Path) {
        $links = @(Get-Item -LiteralPath $Path) + @(Get-ChildItem -LiteralPath $Path -Recurse -Force)
        if ($links | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) {
            throw "refusing linked tool directory: $Path"
        }
    }
}

function Assert-ToolPayload {
    param($Tool, [string]$Dest)
    if (-not (Test-Path -LiteralPath $Dest -PathType Container)) { throw "missing tool directory: $Dest" }
    $payload = @(Get-ChildItem -LiteralPath $Dest -Recurse -File -Force | Where-Object { $_.Name -notlike '.kit-*' } | Select-Object -First 1)
    if (-not $payload.Count) { throw "$($Tool.id) has no payload files" }
    if ($Tool.method -eq 'pip-venv') {
        if (-not (Test-Path -LiteralPath (Join-Path $Dest 'Scripts\python.exe'))) { throw "$($Tool.id) missing Python interpreter" }
        $metadata = @(Get-ChildItem -Path (Join-Path $Dest 'Lib\site-packages') -Directory -Filter (($Tool.package -replace '-', '_') + '-*.dist-info') -ErrorAction SilentlyContinue)
        if (-not $metadata.Count) { throw "$($Tool.id) missing package metadata" }
    }
    if ($Tool.id -eq 'capa-source') {
        $signatures = @(Get-ChildItem -LiteralPath (Join-Path $Dest 'sigs') -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -gt 0 -and $_.Name -match '\.(sig|pat|pat\.gz)$' } | Select-Object -First 1)
        if (-not $signatures.Count) { throw 'capa-source missing library signatures under sigs' }
    } elseif ($Tool.id -eq 'capa-rules') {
        $rules = @(Get-ChildItem -LiteralPath $Dest -Recurse -File -Force -Filter '*.yml' | Where-Object {
            $relative = $_.FullName.Substring($Dest.TrimEnd('\').Length).TrimStart('\')
            $_.Length -gt 0 -and $relative -match '^[^\\]+\\' -and $relative -notmatch '(^|\\)\.'
        } | Select-Object -First 1)
        if (-not $rules.Count) { throw 'capa-rules missing capability rules under category directories' }
    }
    foreach ($shim in (ConvertTo-Array $Tool.shims)) {
        $file = Find-ToolFile -Root $Dest -Glob $shim.exe_glob -Prefer $shim.prefer_path
        if (-not $file) { throw "$($Tool.id) missing required executable $($shim.exe_glob)" }
        if ($shim.require_path -and $file.FullName -notmatch $shim.require_path) {
            throw "$($Tool.id) shim $($shim.name) resolved to $($file.FullName)"
        }
    }
}

function Move-FlattenedStage {
    param([string]$Stage, [string]$Dest)
    $fresh = Join-Path $TmpDir ('fresh-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $fresh | Out-Null
    try {
        $items = @(Get-ChildItem -LiteralPath $Stage -Force)
        $dirs = @($items | Where-Object { $_.PSIsContainer })
        $files = @($items | Where-Object { -not $_.PSIsContainer })
        $source = $Stage
        if ($dirs.Count -eq 1 -and $files.Count -eq 0) { $source = $dirs[0].FullName }
        Get-ChildItem -LiteralPath $source -Force | ForEach-Object {
            Move-Item -LiteralPath $_.FullName -Destination $fresh
        }
        $produced = @(Get-ChildItem -LiteralPath $fresh -Force -Recurse -File)
        if ($produced.Count -eq 0) { throw 'extract produced no files' }
        Assert-OwnedToolPath $Dest
        Assert-ToolPayload -Tool $script:CurrentTool -Dest $fresh
        $backup = Join-Path $Sandbox ('backups/' + (Split-Path -Leaf $Dest) + '-' + [guid]::NewGuid().ToString('N'))
        if (Test-Path -LiteralPath $Dest) {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup) | Out-Null
            Move-Item -LiteralPath $Dest -Destination $backup
            $script:PromotedBackup = $backup
        }
        try { Move-Item -LiteralPath $fresh -Destination $Dest } catch {
            if (Test-Path -LiteralPath $backup) { Move-Item -LiteralPath $backup -Destination $Dest }
            throw
        }
    } finally {
        if (Test-Path -LiteralPath $fresh) { Remove-Item -LiteralPath $fresh -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Expand-FlattenedZip {
    param([string]$Zip, [string]$Dest)
    $stage = Join-Path $TmpDir ('stage-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $stage | Out-Null
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($Zip)
        try {
            $stageRoot = [IO.Path]::GetFullPath($stage).TrimEnd('\') + '\'
            foreach ($entry in $archive.Entries) {
                $entryPath = [IO.Path]::GetFullPath((Join-Path $stage $entry.FullName))
                if (-not $entryPath.StartsWith($stageRoot, [StringComparison]::OrdinalIgnoreCase) -or
                    (($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) {
                    throw "unsafe ZIP entry: $($entry.FullName)"
                }
            }
        } finally { $archive.Dispose() }
        $tar = Join-Path $env:SystemRoot 'System32\tar.exe'
        if (-not (Test-Path -LiteralPath $tar)) { throw 'tar.exe is not in System32' }
        $prev = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        & $tar -xf $Zip -C $stage
        $code = $LASTEXITCODE
        $ErrorActionPreference = $prev
        if ($code -ne 0) { throw "tar extract failed ($code)" }
        Move-FlattenedStage -Stage $stage -Dest $Dest
    } finally {
        if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
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
    if ($env:JAVA_HOME) { $homes += @(Get-Item -LiteralPath $env:JAVA_HOME -ErrorAction SilentlyContinue) }
    $javaCmd = Get-Command java -ErrorAction SilentlyContinue
    if ($javaCmd) { $homes += @(Get-Item -LiteralPath (Split-Path -Parent (Split-Path -Parent $javaCmd.Source)) -ErrorAction SilentlyContinue) }
    foreach ($n in $Major..40) {
        $homes += @(Get-Item -Path (Join-Path $env:ProgramFiles "Microsoft\jdk-$n*") -ErrorAction SilentlyContinue)
        $homes += @(Get-Item -Path (Join-Path $env:ProgramFiles "Eclipse Adoptium\jdk-$n*") -ErrorAction SilentlyContinue)
        $homes += @(Get-Item -Path (Join-Path $env:ProgramFiles "Java\jdk-$n*") -ErrorAction SilentlyContinue)
        $homes += @(Get-Item -Path (Join-Path $env:LOCALAPPDATA "Programs\Eclipse Adoptium\jdk-$n*") -ErrorAction SilentlyContinue)
    }
    foreach ($jdkDir in $homes) {
        $exe = Join-Path $jdkDir.FullName 'bin\java.exe'
        if ((Test-Path -LiteralPath $exe) -and (Get-JavaMajor $exe) -ge $Major) {
            return $jdkDir.FullName
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
    & winget install --id "Microsoft.OpenJDK.$Major" -e --accept-package-agreements --accept-source-agreements --disable-interactivity | ForEach-Object { Write-Log -Detail "winget: $_" }
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
        if ($preferred.Count -eq 1) { return $preferred[0] }
        if ($preferred.Count -gt 1) { throw "ambiguous executable $Glob under $Root" }
    }
    # Portable archives can also contain helpers for another architecture.
    $direct = @($hits | Where-Object { $_.DirectoryName -eq (Get-Item -LiteralPath $Root).FullName })
    if ($direct.Count -eq 1) { return $direct[0] }
    if ($hits.Count -gt 1) { throw "ambiguous executable $Glob under $Root" }
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
        [string]$JavaHome,
        [bool]$JavaJar = $false,
        [string]$DotNetHome
    )
    $rel = (Resolve-Path -LiteralPath $Target).Path
    $from = (Resolve-Path -LiteralPath $BinDir).Path
    if (-not $from.EndsWith('\')) { $from = $from + '\' }
    $base = New-Object System.Uri $from
    $to = New-Object System.Uri $rel
    $relative = [Uri]::UnescapeDataString($base.MakeRelativeUri($to).ToString()) -replace '/', '\'
    $relative = $relative.Replace('%', '%%')
    $lines = @('@echo off', 'setlocal DisableDelayedExpansion')
    if ($JavaHome) {
        $lines += 'set "JAVA_HOME=' + $JavaHome.Replace('%', '%%') + '"'
        $lines += 'set "PATH=%JAVA_HOME%\bin;%PATH%"'
    }
    if ($DotNetHome) {
        $lines += 'set "DOTNET_ROOT=' + $DotNetHome.Replace('%', '%%') + '"'
        $lines += 'set "DOTNET_ROOT_X64=%DOTNET_ROOT%"'
    }
    # Chain batch targets directly; CALL expands percent signs in paths a second time.
    $call = ''
    if ($JavaJar) { $call = '"%JAVA_HOME%\bin\java.exe" -jar ' }
    $arguments = if ($Name -eq 'capa') { '-r "%~dp0..\tools\capa-rules" -s "%~dp0..\tools\capa-source\sigs" %*' } else { '%*' }
    $lines += $call + '"%~dp0' + $relative + '" ' + $arguments
    $lines += 'exit /b %errorlevel%'
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
    if ($have -ne $Marker) { return $false }
    $recordPath = Join-Path $Dest '.kit-record.json'
    $row = $null
    if (Test-Path -LiteralPath $recordPath) {
        try { $row = Get-Content -LiteralPath $recordPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $false }
    } elseif ($script:InstallState) {
        $row = $script:InstallState.tools.($script:CurrentTool.id)
    }
    if (-not $row -or $row.id -ne $script:CurrentTool.id) { return $false }
    if ($script:CurrentTool.method -eq 'github-archive' -and $row.asset -like '*/archive/refs/heads/*') { return $false }
    if ($script:CurrentTool.package_version -and $row.version -ne $script:CurrentTool.package_version) { return $false }
    try { Assert-ToolPayload -Tool $script:CurrentTool -Dest $Dest; if ($script:CurrentTool.method -eq 'npm-tool') { Assert-NpmIntegrity -Tool $script:CurrentTool -Dest $Dest } } catch { return $false }
    $row.shims = Install-Shims -Tool $script:CurrentTool -Dest $Dest
    $row.dir = Get-RelativeKitPath $Dest
    if ($row.version -eq 'pip') {
        $pythonExe = Join-Path $Dest 'Scripts\python.exe'
        $row.version = (& $pythonExe -c "import importlib.metadata; print(importlib.metadata.version('$($script:CurrentTool.package)'))" | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or -not $row.version) { return $false }
    } elseif ($row.version -eq 'dotnet-tool') {
        if (-not $script:DotNetExe) { Initialize-DotNet10 | Out-Null }
        $packageRows = @(& $script:DotNetExe tool list --tool-path $Dest)
        $versionRows = @($packageRows | Where-Object { $_ -match ('^' + [regex]::Escape($script:CurrentTool.package) + '\s+') })
        if ($LASTEXITCODE -ne 0 -or $versionRows.Count -ne 1) { return $false }
        $row.version = ($versionRows[0] -split '\s+')[1]
    }
    $script:CachedRecord = $row
    return $true
}

function Write-Marker {
    param([string]$Dest, [string]$Marker)
    Write-Utf8 -Path (Join-Path $Dest '.kit-ok') -Text ($Marker + "`n")
}

function Save-State {
    param($State)
    $json = $State | ConvertTo-Json -Depth 8
    Write-AtomicJson -Path $StatePath -Text $json
    $pointer = [pscustomobject]@{}
    if (Test-Path -LiteralPath $PointerPath) {
        $pointer = Get-Content -LiteralPath $PointerPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $backup = $PointerPath + '.pre-' + $kitVersion
        if (-not (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $PointerPath -Destination $backup }
    }
    $owned = @{ kit_root = $KitRoot; installed_json = $StatePath; bin = $BinDir; java_home = $State.java_home }
    foreach ($key in $owned.Keys) { $pointer | Add-Member -NotePropertyName $key -NotePropertyValue $owned[$key] -Force }
    Write-AtomicJson -Path $PointerPath -Text ($pointer | ConvertTo-Json -Depth 100)
}

function Write-AtomicJson {
    param([string]$Path, [string]$Text)
    $Text | ConvertFrom-Json | Out-Null
    $temp = $Path + '.new'
    Write-Utf8 -Path $temp -Text $Text
    $replacing = Test-Path -LiteralPath $Path
    for ($attempt = 0; $attempt -lt 6; $attempt++) {
        try {
            if ($replacing) { [IO.File]::Replace($temp, $Path, [NullString]::Value) }
            else { [IO.File]::Move($temp, $Path) }
            return
        } catch {
            $ioError = $_.Exception
            while ($ioError -and $ioError -isnot [IO.IOException]) { $ioError = $ioError.InnerException }
            $win32 = if ($ioError) { $ioError.HResult -band 0xFFFF } else { 0 }
            # Sharing/lock violations and ReplaceFile's unchanged-files error are safe to retry.
            # Errors 1176/1177 can move the old file; never retry those or delete the good target.
            if ($attempt -eq 5 -or $win32 -notin @(32, 33, 1175) -or
                -not (Test-Path -LiteralPath $temp) -or
                ($replacing -and -not (Test-Path -LiteralPath $Path))) { throw }
            Write-Log -Detail "atomic JSON retry $($attempt + 1)/5: Win32=$win32 path=$Path"
            Start-Sleep -Milliseconds (100 * ($attempt + 1))
        }
    }
}

function New-State {
    if (Test-Path -LiteralPath $StatePath) {
        $existing = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($existing.tools) {
            foreach ($property in @($existing.tools.PSObject.Properties)) {
                # Old installers captured native stdout alongside the record.
                $rows = @($property.Value | Where-Object { $_ -isnot [string] -and $_.id -eq $property.Name })
                if ($rows.Count -ne 1) { throw "invalid installed record: $($property.Name)" }
                $property.Value = $rows[0]
            }
            return $existing
        }
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
$script:ExtraInstalled = @()

function Install-Shims {
    param($Tool, [string]$Dest)
    $made = @{}
    foreach ($shim in (ConvertTo-Array $Tool.shims)) {
        $file = Find-ToolFile -Root $Dest -Glob $shim.exe_glob -Prefer $shim.prefer_path
        if ($null -eq $file) {
            throw "$($Tool.id) shim $($shim.name) did not find $($shim.exe_glob)"
        }
        $java = $null
        if ($Tool.needs_jdk) { $java = $script:JavaHome }
        $dotnet = if ($Tool.method -eq 'dotnet-tool') { $script:DotNetHome } else { $null }
        if ($shim.require_path -and ($file.FullName -notmatch $shim.require_path)) {
            throw "$($Tool.id) shim $($shim.name) resolved to $($file.FullName)"
        }
        $cmd = Write-Shim -Name $shim.name -Target $file.FullName -JavaHome $java -JavaJar ([bool]$shim.java_jar) -DotNetHome $dotnet
        $made[$shim.name] = Get-RelativeKitPath $cmd
    }
    return $made
}

function Install-GitHubZipTool {
    param($Tool)
    $release = Get-GitHubRelease -Repo $Tool.repo -Release $Tool.release
    $asset = Select-OneAsset -Assets (ConvertTo-Array $release.assets) -Pattern $Tool.asset_pattern
    if ([string]$asset.name -notmatch '^[A-Za-z0-9._+ -]+$') { throw "unsafe asset filename: $($asset.name)" }
    $dest = Join-Path $ToolsDir $Tool.id
    $marker = '{0}|{1}' -f $release.tag_name, $asset.name
    if ($Tool.needs_jdk -and -not $script:JavaHome) { $script:JavaHome = Install-Jdk -Major ([int]$Tool.needs_jdk) }
    if (Test-AlreadyInstalled -Dest $dest -Marker $marker) {
        Write-Log "skip $($Tool.id) $marker"
        return $script:CachedRecord
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
    switch ([string]$Tool.unpack) {
        'msi-admin' { Expand-MsiAdmin -Msi $zip -Dest $dest }
        'nsis-app64' { Expand-NsisApp64 -Installer $zip -Dest $dest }
        '7z' { Expand-WithSevenZip -Archive $zip -Dest $dest }
        'raw' {
            $rawStage = Join-Path $TmpDir ('raw-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $rawStage | Out-Null
            Copy-Item -LiteralPath $zip -Destination (Join-Path $rawStage $asset.name)
            try { Move-FlattenedStage -Stage $rawStage -Dest $dest }
            finally { Remove-Item -LiteralPath $rawStage -Recurse -Force }
        }
        default { Expand-FlattenedZip -Zip $zip -Dest $dest }
    }
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
        return $script:CachedRecord
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
    Move-FlattenedStage -Stage $fresh -Dest $dest
    Remove-Item -LiteralPath $fresh -Force
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
        return $script:CachedRecord
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

function Test-DotNet10 {
    param([string]$Executable)
    if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) { return $false }
    $prev = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $sdks = @(& $Executable --list-sdks 2>&1)
        if ($LASTEXITCODE -ne 0 -or -not ($sdks -match '^10\.\d+\.\d+\s+\[')) { return $false }
        $runtimes = @(& $Executable --list-runtimes 2>&1)
        return ($LASTEXITCODE -eq 0 -and [bool]($runtimes -match '^Microsoft\.NETCore\.App 10\.\d+\.\d+\s+\['))
    } catch { return $false }
    finally { $ErrorActionPreference = $prev }
}

function Find-DotNet10 {
    $candidates = @()
    foreach ($root in @($env:DOTNET_ROOT_X64, $env:DOTNET_ROOT)) {
        if ($root) { $candidates += Join-Path $root 'dotnet.exe' }
    }
    $command = Get-Command dotnet -CommandType Application -ErrorAction SilentlyContinue
    if ($command) { $candidates += $command.Source }
    foreach ($root in @($env:ProgramW6432, $env:ProgramFiles)) {
        if ($root) { $candidates += Join-Path $root 'dotnet\dotnet.exe' }
    }
    foreach ($candidate in @($candidates | Select-Object -Unique)) {
        if (Test-DotNet10 $candidate) { return $candidate }
    }
    return $null
}

function Initialize-DotNet10 {
    $found = Find-DotNet10
    if (-not $found) {
        $winget = Get-Command winget -CommandType Application -ErrorAction SilentlyContinue
        if (-not $winget) { throw 'This kit requires a .NET 10 SDK and runtime for ilspycmd; winget is unavailable. Install Microsoft.DotNet.SDK.10, then rerun the installer.' }
        Write-Log 'installing Microsoft.DotNet.SDK.10 via winget'
        $prev = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            & $winget.Source install --id Microsoft.DotNet.SDK.10 -e --accept-package-agreements --accept-source-agreements --disable-interactivity | ForEach-Object { Write-Log -Detail "winget: $_" }
            $code = $LASTEXITCODE
        } finally { $ErrorActionPreference = $prev }
        if ($code -ne 0) { throw "winget Microsoft.DotNet.SDK.10 failed ($code)" }
        $found = Find-DotNet10
        if (-not $found) { throw 'Microsoft.DotNet.SDK.10 completed but a stable .NET 10 SDK and runtime were not found. Check its installation and rerun.' }
    }
    $script:DotNetExe = $found
    $script:DotNetHome = Split-Path -Parent $found
    return $found
}

function Install-DotNetTool {
    param($Tool)
    $dotnet = Initialize-DotNet10
    $dest = Join-Path $ToolsDir $Tool.id
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    if ((Test-AlreadyInstalled -Dest $dest -Marker 'present') -and (Get-ChildItem -LiteralPath $dest -Filter ($Tool.shims[0].exe_glob) -Recurse -ErrorAction SilentlyContinue)) {
        Write-Log "skip $($Tool.id)"
        return $script:CachedRecord
    }
    $prev = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $dotnet tool install $Tool.package --tool-path $dest --framework net10.0 | ForEach-Object { Write-Log -Detail "dotnet: $_" }
        if ($LASTEXITCODE -ne 0) {
            & $dotnet tool update $Tool.package --tool-path $dest --framework net10.0 | ForEach-Object { Write-Log -Detail "dotnet: $_" }
        }
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prev }
    if ($code -ne 0) { throw "dotnet tool $($Tool.package) failed ($code)" }
    $packageRows = @(& $dotnet tool list --tool-path $dest)
    if ($LASTEXITCODE -ne 0) { throw "dotnet tool list failed ($LASTEXITCODE): $($Tool.package)" }
    $versionRow = @($packageRows | Where-Object { $_ -match ('^' + [regex]::Escape($Tool.package) + '\s+') })
    if ($versionRow.Count -ne 1) { throw "cannot read installed version: $($Tool.package)" }
    $packageVersion = ($versionRow[0] -split '\s+')[1]
    $shims = Install-Shims -Tool $Tool -Dest $dest
    Write-Marker -Dest $dest -Marker 'present'
    return [pscustomobject]@{
        id = $Tool.id
        version = $packageVersion
        asset = [string]$Tool.package
        sha256 = $null
        hash_source = 'nuget'
        dir = Get-RelativeKitPath $dest
        shims = $shims
    }
}

function Install-PipVenv {
    param($Tool)
    if (-not (Get-Command py -ErrorAction SilentlyContinue)) { throw 'Python launcher py is missing; install the Starter Bundle runtime prerequisites first' }
    $dest = Join-Path $ToolsDir $Tool.id
    $exe = Join-Path $dest 'Scripts\python.exe'
    if ((Test-AlreadyInstalled -Dest $dest -Marker 'present') -and (Test-Path -LiteralPath $exe)) {
        Write-Log "skip $($Tool.id)"
        return $script:CachedRecord
    }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & py -3 -m venv $dest | ForEach-Object { Write-Log -Detail "python: $_" }
    if ($LASTEXITCODE -ne 0) { $ErrorActionPreference = $prev; throw "venv failed ($LASTEXITCODE)" }
    $pyexe = Join-Path $dest 'Scripts\python.exe'
    $packageSpec = if ($Tool.package_version) { $Tool.package + '==' + $Tool.package_version } else { $Tool.package }
    & $pyexe -m pip install --upgrade --disable-pip-version-check $packageSpec | ForEach-Object { Write-Log -Detail "pip: $_" }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -ne 0) { throw "pip install $($Tool.package) failed ($code)" }
    $packageVersion = (& $pyexe -c "import importlib.metadata; print(importlib.metadata.version('$($Tool.package)'))" | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $packageVersion) { throw "cannot read installed version: $($Tool.package)" }
    $shims = Install-Shims -Tool $Tool -Dest $dest
    Write-Marker -Dest $dest -Marker 'present'
    return [pscustomobject]@{
        id = $Tool.id
        version = $packageVersion
        asset = [string]$Tool.package
        sha256 = $null
        hash_source = 'pypi'
        dir = Get-RelativeKitPath $dest
        shims = $shims
    }
}

# Reuse a matching global REA without taking ownership or changing its settings.
function Get-ExternalRea {
    param($Tool)
    if ($Tool.id -ne 'rea' -or $Force) { return $null }
    foreach ($command in @(Get-Command rea.cmd -All -CommandType Application -ErrorAction SilentlyContinue)) {
        if ($command.Source.StartsWith($BinDir.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { continue }
        $version = (& $command.Source --version 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or $version -notmatch ('(?<![0-9.])' + [regex]::Escape($Tool.package_version) + '(?![0-9.])')) { continue }
        $shim = Write-Shim -Name 'rea' -Target $command.Source
        return [pscustomobject]@{ id='rea'; version=$Tool.package_version; source='existing-path'; owned=$false; command=$command.Source; dir=$null; shims=@{rea=(Get-RelativeKitPath $shim)} }
    }
    return $null
}

function Assert-NpmIntegrity {
    param($Tool, [string]$Dest)
    if (-not $Tool.npm_integrity) { return }
    $text = [IO.File]::ReadAllText((Join-Path $Dest 'package-lock.json'))
    # npm has an empty root key; PS5.1's PSCustomObject converter rejects it.
    if ($PSVersionTable.PSVersion.Major -ge 6) { $lock = ConvertFrom-Json -InputObject $text -AsHashtable }
    else {
        Add-Type -AssemblyName System.Web.Extensions
        $json = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $json.MaxJsonLength=16777216
        $lock=$json.DeserializeObject($text)
    }
    $row = $lock['packages']['node_modules/' + $Tool.package]
    if (-not $row -or $row['version'] -ne $Tool.package_version -or $row['integrity'] -cne $Tool.npm_integrity) { throw "npm integrity/version mismatch: $($Tool.package)" }
}

function Install-NpmTool {
    param($Tool)
    $dest = Join-Path $ToolsDir $Tool.id
    if (Test-AlreadyInstalled -Dest $dest -Marker 'present') { return $script:CachedRecord }
    $npm = Get-Command npm.cmd -ErrorAction SilentlyContinue
    if (-not $npm) { throw 'npm.cmd is missing; use the Node runtime supplied by the Starter Bundle' }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $npm.Source install --prefix $dest --no-audit --no-fund --ignore-scripts --engine-strict ($Tool.package + '@' + $(if ($Tool.package_version) { $Tool.package_version } else { 'latest' })) | ForEach-Object { Write-Log -Detail "npm: $_" }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -ne 0) { throw "npm install $($Tool.package) failed ($code)" }
    $packageJson = Join-Path $dest ('node_modules/' + $Tool.package + '/package.json')
    $packageVersion = (Get-Content -LiteralPath $packageJson -Raw -Encoding UTF8 | ConvertFrom-Json).version
    if (-not $packageVersion) { throw "cannot read installed version: $($Tool.package)" }
    Assert-NpmIntegrity -Tool $Tool -Dest $dest
    $shims = Install-Shims -Tool $Tool -Dest $dest
    Write-Marker -Dest $dest -Marker 'present'
    return [pscustomobject]@{
        npm_integrity = $Tool.npm_integrity
        id = $Tool.id; version = $packageVersion; asset = $Tool.package
        sha256 = $null; hash_source = 'npm-lock-integrity'
        dir = Get-RelativeKitPath $dest; shims = $shims
    }
}

function New-SpacelessDirectory {
    $bases = @()
    if ($env:TEMP -and $env:TEMP -notmatch ' ') { $bases += $env:TEMP }
    $winTemp = Join-Path $env:SystemRoot 'Temp'
    if ($winTemp -notmatch ' ') { $bases += $winTemp }
    foreach ($base in $bases) {
        $dir = Join-Path $base ('rt7z' + [guid]::NewGuid().ToString('N'))
        try {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            return $dir
        } catch { }
    }
    throw '7-Zip installer needs a temp directory with no spaces'
}

function Invoke-SevenZip {
    param([string]$SevenZip, [string[]]$ArgumentList)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $SevenZip @ArgumentList | ForEach-Object { Write-Log -Detail "7z: $_" }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -ne 0) { throw "7z failed ($code)" }
}

function Expand-MsiAdmin {
    param([string]$Msi, [string]$Dest)
    $stage = New-SpacelessDirectory
    $extract = Join-Path $stage 'out'
    $localMsi = Join-Path $stage 'pkg.msi'
    New-Item -ItemType Directory -Force -Path $extract | Out-Null
    Copy-Item -LiteralPath $Msi -Destination $localMsi
    try {
        $msiexec = Join-Path $env:SystemRoot 'System32\msiexec.exe'
        $prev = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $proc = Start-Process -FilePath $msiexec -ArgumentList @('/a', $localMsi, '/qn', ('TARGETDIR=' + $extract)) -WindowStyle Hidden -Wait -PassThru
        $code = $proc.ExitCode
        $ErrorActionPreference = $prev
        if ($code -ne 0 -and $code -ne 3010) { throw "msiexec /a failed ($code)" }
        $payload = Join-Path $extract 'Files\7-Zip'
        if (-not (Test-Path -LiteralPath (Join-Path $payload '7z.exe')) -or -not (Test-Path -LiteralPath (Join-Path $payload '7z.dll'))) {
            throw '7-Zip MSI did not contain 7z.exe and 7z.dll'
        }
        Move-FlattenedStage -Stage $payload -Dest $Dest
    } finally {
        if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Get-SevenZip {
    $exe = Join-Path $ToolsDir '7zip\7z.exe'
    $dll = Join-Path $ToolsDir '7zip\7z.dll'
    if ((Test-Path -LiteralPath $exe) -and (Test-Path -LiteralPath $dll)) { return $exe }
    $catalog = Get-Catalog
    $tool = ConvertTo-Array $catalog.tools | Where-Object { $_.id -eq '7zip' } | Select-Object -First 1
    if (-not $tool) { throw 'catalog has no 7zip tool' }
    if ([string]$tool.unpack -ne 'msi-admin') { throw '7zip tool must unpack with msi-admin' }
    $parentTool = $script:CurrentTool
    $parentCached = $script:CachedRecord
    $parentBackup = $script:PromotedBackup
    try { $row = Install-One $tool } finally {
        $script:CurrentTool = $parentTool
        $script:CachedRecord = $parentCached
        $script:PromotedBackup = $parentBackup
    }
    if ($row) { $script:ExtraInstalled += @($row) }
    if (-not (Test-Path -LiteralPath $exe) -or -not (Test-Path -LiteralPath $dll)) {
        throw '7zip install did not produce 7z.exe and 7z.dll'
    }
    return $exe
}

function Expand-WithSevenZip {
    param([string]$Archive, [string]$Dest)
    $seven = Get-SevenZip
    $stage = Join-Path $TmpDir ('stage-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $stage | Out-Null
    try {
        Invoke-SevenZip -SevenZip $seven -ArgumentList @('x', '-y', "-o$stage", $Archive)
        Move-FlattenedStage -Stage $stage -Dest $Dest
    } finally {
        if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Expand-NsisApp64 {
    param([string]$Installer, [string]$Dest)
    $seven = Get-SevenZip
    $outer = Join-Path $TmpDir ('nsis-' + [guid]::NewGuid().ToString('N'))
    $innerStage = Join-Path $TmpDir ('app64-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $outer, $innerStage | Out-Null
    try {
        Invoke-SevenZip -SevenZip $seven -ArgumentList @('e', '-y', "-o$outer", $Installer, '$PLUGINSDIR\app-64.7z')
        $packed = @(Get-ChildItem -LiteralPath $outer -Filter 'app-64.7z' -File)
        if ($packed.Count -ne 1) { throw "nsis app-64.7z count $($packed.Count)" }
        Invoke-SevenZip -SevenZip $seven -ArgumentList @('x', '-y', "-o$innerStage", $packed[0].FullName)
        $payload = @(Get-ChildItem -LiteralPath $innerStage -Filter 'LDtk.exe' -File)
        if ($payload.Count -ne 1) { throw "LDtk.exe count $($payload.Count)" }
        Move-FlattenedStage -Stage $innerStage -Dest $Dest
    } finally {
        if (Test-Path -LiteralPath $outer) { Remove-Item -LiteralPath $outer -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $innerStage) { Remove-Item -LiteralPath $innerStage -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Install-GitHubArchive {
    param($Tool)
    $repo = [string]$Tool.repo
    if ($Tool.ref -eq 'release') {
        $release = Get-GitHubRelease -Repo $repo -Release $Tool.release
        $refName = [string]$release.tag_name
        $url = Get-GitHubArchiveUrl -Repo $repo -Kind 'tag' -Ref $refName
        $marker = 'tag|' + $refName
        $version = $refName
    } else {
        $meta = Invoke-GitHubApi -ApiPath ("repos/" + $repo)
        $branch = [string]$meta.default_branch
        if (-not $branch) { throw "$($Tool.id) has no default branch" }
        $commit = Invoke-GitHubApi -ApiPath ("repos/" + $repo + "/commits/" + $branch)
        $sha = [string]$commit.sha
        if ($sha -notmatch '^[0-9a-f]{40}$') { throw "$($Tool.id) commit sha was not a sha" }
        $url = Get-GitHubArchiveUrl -Repo $repo -Kind 'commit' -Ref $sha
        $marker = 'commit|' + $sha
        $version = $sha.Substring(0, 12)
    }
    $dest = Join-Path $ToolsDir $Tool.id
    if (Test-AlreadyInstalled -Dest $dest -Marker $marker) {
        Write-Log "skip $($Tool.id) $marker"
        return $script:CachedRecord
    }
    $zip = Join-Path $TmpDir ($Tool.id + '-src.zip')
    Write-Log "get $($Tool.id) $url"
    Save-Url -Url $url -Dest $zip
    $actual = Get-Sha256Hex $zip
    Expand-FlattenedZip -Zip $zip -Dest $dest
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    $shims = Install-Shims -Tool $Tool -Dest $dest
    Write-Marker -Dest $dest -Marker $marker
    return [pscustomobject]@{
        id = $Tool.id
        version = $version
        asset = $url
        sha256 = $actual
        hash_source = 'computed'
        dir = Get-RelativeKitPath $dest
        shims = $shims
    }
}

function Install-FighterFactory {
    param($Tool)
    $url = Resolve-FighterFactoryZipUrl
    $name = [IO.Path]::GetFileName(([Uri]$url).AbsolutePath)
    if ($name -notmatch '^[A-Za-z0-9._-]+\.zip$') { throw "bad fighter factory file name $name" }
    $dest = Join-Path $ToolsDir $Tool.id
    if (Test-AlreadyInstalled -Dest $dest -Marker $url) {
        Write-Log "skip $($Tool.id) $url"
        return $script:CachedRecord
    }
    $zip = Join-Path $TmpDir $name
    Write-Log "get fighter-factory $url"
    Save-Url -Url $url -Dest $zip
    $actual = Get-Sha256Hex $zip
    Expand-FlattenedZip -Zip $zip -Dest $dest
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    $shims = Install-Shims -Tool $Tool -Dest $dest
    Write-Marker -Dest $dest -Marker $url
    return [pscustomobject]@{
        id = $Tool.id
        version = $name
        asset = $url
        sha256 = $actual
        hash_source = 'computed'
        dir = Get-RelativeKitPath $dest
        shims = $shims
    }
}

function Select-InstallTools {
    param($Selected, $Catalog)
    $groupIds = @('capa-rules', 'capa-source', 'capa')
    $groupAdded = $false
    foreach ($tool in (ConvertTo-Array $Selected)) {
        if ($tool.id -notin $groupIds) { $tool; continue }
        if ($groupAdded) { continue }
        $parent = @(ConvertTo-Array $Catalog.tools | Where-Object { $_.id -eq 'capa' })
        if ($parent.Count -ne 1) { throw 'The capa dependency group requires exactly one capa catalog entry.' }
        $parent[0]
        $groupAdded = $true
    }
}

function Install-One {
    param($Tool)
    $capaTag = $null
    if ($Tool.id -eq 'capa') {
        $capaTag = [string](Get-GitHubRelease -Repo 'mandiant/capa').tag_name
        if ($capaTag -notmatch '^v\d+\.\d+\.\d+$') { throw "invalid capa release version: $capaTag" }
        $Tool | Add-Member -NotePropertyName package_version -NotePropertyValue $capaTag.Substring(1) -Force
    }
    $dest = Join-Path $ToolsDir $Tool.id
    Write-Log -Detail "resolved $($Tool.id): method=$($Tool.method) directory=$dest force=$Force"
    Assert-OwnedToolPath $dest
    $savedShims = @{}
    foreach ($shim in (ConvertTo-Array $Tool.shims)) {
        if ($shim.name -notmatch '^[A-Za-z0-9-]+$') { throw "unsafe shim name: $($shim.name)" }
        $shimPath = Join-Path $BinDir ($shim.name + '.cmd')
        $savedShims[$shimPath] = if (Test-Path -LiteralPath $shimPath) { [IO.File]::ReadAllBytes($shimPath) } else { $null }
    }
    $packageBackup = $null
    $parentStarted = $false
    $dependencyChanges = @()
    $previousExtra = @($script:ExtraInstalled)
    try {
    $external = Get-ExternalRea -Tool $Tool
    if ($external) { return $external }
    foreach ($id in (ConvertTo-Array $Tool.requires)) {
        $dependency = @(ConvertTo-Array (Get-Catalog).tools | Where-Object { $_.id -eq $id })
        if ($dependency.Count -ne 1) { throw "unknown dependency: $id" }
        $change = $null
        if ($capaTag) {
            $dependency[0] | Add-Member -NotePropertyName release -NotePropertyValue $capaTag -Force
            $change = [pscustomobject]@{
                dir = Join-Path $ToolsDir $id
                existed = Test-Path -LiteralPath (Join-Path $ToolsDir $id)
                backup = $null
            }
            $dependencyChanges += $change
        }
        $script:PromotedBackup = $null
        try { $script:ExtraInstalled += @(Install-One $dependency[0]) }
        finally { if ($change) { $change.backup = $script:PromotedBackup } }
    }
    $script:CurrentTool = $Tool
    $script:CachedRecord = $null
    $script:PromotedBackup = $null
    $parentStarted = $true
    if ($Tool.method -eq 'dotnet-tool') { Initialize-DotNet10 | Out-Null }
    if ($Tool.method -in @('pip-venv', 'dotnet-tool', 'npm-tool') -and (Test-Path -LiteralPath $dest)) {
        if (Test-AlreadyInstalled -Dest $dest -Marker 'present') {
            Write-AtomicJson -Path (Join-Path $dest '.kit-record.json') -Text ($script:CachedRecord | ConvertTo-Json -Depth 8)
            return $script:CachedRecord
        }
        $backupCandidate = Join-Path $Sandbox ('backups/' + $Tool.id + '-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backupCandidate) | Out-Null
        Copy-Item -LiteralPath $dest -Destination $backupCandidate -Recurse
        $packageBackup = $backupCandidate
    }
    $row = switch ($Tool.method) {
        'github-release' { Install-GitHubZipTool $Tool }
        'github-files' { Install-GitHubFilesTool $Tool }
        'renderdoc-stable-zip' { Install-RenderDocTool $Tool }
        'dotnet-tool' { Install-DotNetTool $Tool }
        'pip-venv' { Install-PipVenv $Tool }
        'npm-tool' { Install-NpmTool $Tool }
        'github-archive' { Install-GitHubArchive $Tool }
        'virtualltek-portable' { Install-FighterFactory $Tool }
        default { throw "unknown method $($Tool.method)" }
    }
    if ($row -is [array] -or -not $row -or $row.id -ne $Tool.id) { throw "invalid install result: $($Tool.id)" }
    Assert-ToolPayload -Tool $Tool -Dest $dest
    Write-AtomicJson -Path (Join-Path $dest '.kit-record.json') -Text ($row | ConvertTo-Json -Depth 8)
    return $row
    } catch {
        $failure = $_
        $rollbackErrors = @()
        if ($capaTag) { $script:ExtraInstalled = $previousExtra }
        $rollback = if ($packageBackup) { $packageBackup } elseif ($parentStarted) { $script:PromotedBackup } else { $null }
        try {
            if ($rollback -and (Test-Path -LiteralPath $rollback)) {
                Assert-OwnedToolPath $dest
                if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
                Move-Item -LiteralPath $rollback -Destination $dest
                Write-Log "restored last-good $($Tool.id)"
            }
        } catch { $rollbackErrors += $_.Exception.Message }
        for ($index = $dependencyChanges.Count - 1; $index -ge 0; $index--) {
            $change = $dependencyChanges[$index]
            try {
                Assert-OwnedToolPath $change.dir
                if ($change.backup -and (Test-Path -LiteralPath $change.backup)) {
                    if (Test-Path -LiteralPath $change.dir) { Remove-Item -LiteralPath $change.dir -Recurse -Force }
                    Move-Item -LiteralPath $change.backup -Destination $change.dir
                } elseif (-not $change.existed -and (Test-Path -LiteralPath $change.dir)) {
                    Remove-Item -LiteralPath $change.dir -Recurse -Force
                }
            } catch { $rollbackErrors += $_.Exception.Message }
        }
        foreach ($shimPath in $savedShims.Keys) {
            try {
                if ($null -ne $savedShims[$shimPath]) { [IO.File]::WriteAllBytes($shimPath, $savedShims[$shimPath]) }
                elseif (Test-Path -LiteralPath $shimPath) { Remove-Item -LiteralPath $shimPath -Force }
            } catch { $rollbackErrors += $_.Exception.Message }
        }
        if ($rollbackErrors.Count) { throw "Install failed: $($failure.Exception.Message). Rollback incomplete: $($rollbackErrors -join '; ')" }
        throw $failure
    }
}

function Merge-ExtraInstalled {
    param($State)
    foreach ($extra in @($script:ExtraInstalled)) {
        if ($extra -and $extra.id) {
            $State.tools | Add-Member -NotePropertyName $extra.id -NotePropertyValue $extra -Force
        }
    }
    $script:ExtraInstalled = @()
}

if ($SelfTest) { Invoke-SelfTest }
if ($Plan) { Invoke-Plan }

$catalog = Get-Catalog
$selected = @(ConvertTo-Array $catalog.tools)
if ($Only) {
    $wanted = @($Only | ForEach-Object { $_.Split(',') } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
    $unknown = @($wanted | Where-Object { $_ -notin $selected.id })
    if ($unknown.Count) { throw "unknown tool id: $($unknown -join ', ')" }
    $selected = @($selected | Where-Object { $wanted -contains $_.id })
    if ($selected.Count -eq 0) { throw "Only matched nothing: $($wanted -join ', ')" }
}
if ($Doctor) {
    $missing = 0
    $state = New-State
    foreach ($tool in $selected) {
        try {
            $row = $state.tools.($tool.id)
            if (-not $row) { throw 'not installed' }
            foreach ($id in (ConvertTo-Array $tool.requires)) {
                if (-not $state.tools.$id) { throw "missing dependency: $id" }
                $dependency = $catalog.tools | Where-Object { $_.id -eq $id }
                Assert-ToolPayload -Tool $dependency -Dest (Join-Path $ToolsDir $id)
            }
            if ($row.source -eq 'existing-path' -and $row.owned -eq $false) {
                if (-not (Test-Path -LiteralPath $row.command -PathType Leaf)) { throw 'external command missing' }
            } else { Assert-ToolPayload -Tool $tool -Dest (Join-Path $ToolsDir $tool.id) }
            foreach ($shim in (ConvertTo-Array $tool.shims)) {
                if (-not (Test-Path -LiteralPath (Join-Path $BinDir ($shim.name + '.cmd')))) { throw "missing shim $($shim.name)" }
            }
            Write-Host "OK $($tool.id) $($row.version)"
        } catch { Write-Host "FAIL $($tool.id): $($_.Exception.Message)"; $missing++ }
    }
    Write-Host 'Doctor checks files and records only; run the relevant tool on a lab sample for runtime proof.'
    if ($missing) { exit 1 }
    exit 0
}

$selected = @(Select-InstallTools -Selected $selected -Catalog $catalog)
New-Item -ItemType Directory -Force -Path $BinDir, $ToolsDir, $TmpDir, $LogDir, $PointerDir | Out-Null
$lockPath = Join-Path $Sandbox '.install.lock'
try { $lock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None') }
catch { throw 'Another installer is using this kit. Wait for it to finish.' }
try {
Write-Log "reverse-this $kitVersion  root=$KitRoot"
if (Test-Path -LiteralPath $StatePath) {
    $stateBackup = $StatePath + '.pre-' + $kitVersion + '.json'
    if (-not (Test-Path -LiteralPath $stateBackup)) { Copy-Item -LiteralPath $StatePath -Destination $stateBackup }
}
$state = New-State
$script:InstallState = $state
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
        Merge-ExtraInstalled $state
        Save-State $state
        $ok += $tool.id
    } catch {
        Write-Log "FAIL $($tool.id): $($_.Exception.Message)"
        $bad += $tool.id
        Merge-ExtraInstalled $state
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
} finally { $lock.Dispose() }
