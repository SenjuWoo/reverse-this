#Requires -Version 5.1
<## Offline installer regression checks. No downloads or machine configuration writes. ##>
$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $sourceRoot 'Install-Modkit.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
foreach ($definition in $ast.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
}, $false)) {
    Invoke-Expression $definition.Extent.Text
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

$testBase = Join-Path $sourceRoot 'sandbox\tmp'
$testRoot = Join-Path $testBase ('tests-' + [guid]::NewGuid().ToString('N'))
$KitRoot = $testRoot
$Sandbox = Join-Path $testRoot 'sandbox'
$BinDir = Join-Path $Sandbox 'bin'
$ToolsDir = Join-Path $Sandbox 'tools'
$TmpDir = Join-Path $Sandbox 'tmp'
$LogDir = Join-Path $Sandbox 'log'
$LogPath = Join-Path $LogDir 'modkit.log'
$StatePath = Join-Path $Sandbox 'installed.json'
$PointerDir = Join-Path $testRoot 'profile-pointer'
$PointerPath = Join-Path $PointerDir 'kit.json'
$kitVersion = '0.0.0'
$Force = $false
$script:JavaHome = $null
$script:ExtraInstalled = @()
$tool = [pscustomobject]@{
    id = 'probe'
    method = 'github-release'
    needs_jdk = $null
    shims = @([pscustomobject]@{ name = 'probe'; exe_glob = 'probe.cmd'; prefer_path = $null; require_path = $null })
}
$script:CurrentTool = $tool
$script:InstallState = [pscustomobject]@{
    schema = 1; kit_version = $kitVersion; kit_root = $KitRoot; java_home = $null
    tools = [pscustomobject]@{}
}

try {
    New-Item -ItemType Directory -Path $BinDir, $ToolsDir, $TmpDir, $LogDir, $PointerDir -Force | Out-Null
    $dest = Join-Path $ToolsDir 'probe'
    New-Item -ItemType Directory -Path $dest | Out-Null
    Write-Utf8 -Path (Join-Path $dest 'old.txt') -Text 'known-good'
    Write-Utf8 -Path (Join-Path $dest 'probe.cmd') -Text "@echo off`r`nexit /b 0`r`n"
    $stage = Join-Path $TmpDir 'bad-stage'
    New-Item -ItemType Directory -Path $stage | Out-Null
    Write-Utf8 -Path (Join-Path $stage 'unexpected.txt') -Text 'not the required executable'
    $threw = $false
    try { Move-FlattenedStage -Stage $stage -Dest $dest | Out-Null } catch { $threw = $true }
    Assert-True $threw 'A payload missing its required shim was accepted'
    Assert-True ((Get-Content -LiteralPath (Join-Path $dest 'old.txt') -Raw) -eq 'known-good') 'An invalid update destroyed the previous payload'

    $stage = Join-Path $TmpDir 'good-stage'
    New-Item -ItemType Directory -Path $stage | Out-Null
    Write-Utf8 -Path (Join-Path $stage 'probe.cmd') -Text "@echo off`r`nexit /b 0`r`n"
    Move-FlattenedStage -Stage $stage -Dest $dest | Out-Null
    Assert-True (Test-Path -LiteralPath (Join-Path $dest 'probe.cmd')) 'A valid payload was not installed'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $dest 'old.txt'))) 'An update merged stale files into the new payload'

    $seven = Join-Path $TmpDir 'fake-7z.cmd'
    Write-Utf8 -Path $seven -Text "@echo off`r`necho archive progress`r`nexit /b 0`r`n"
    $output = @(Invoke-SevenZip -SevenZip $seven -ArgumentList @('x', 'dummy.zip'))
    Assert-True ($output.Count -eq 0) 'Archive progress polluted the installer return value'
    Write-Utf8 -Path $seven -Text "@echo off`r`necho failed archive`r`nexit /b 3`r`n"
    $threw = $false
    try { Invoke-SevenZip -SevenZip $seven -ArgumentList @('x') | Out-Null } catch { $threw = $true }
    Assert-True $threw 'A failing archive process was accepted'

    $caller = Join-Path $testRoot 'caller directory'
    New-Item -ItemType Directory -Path $caller | Out-Null
    Write-Utf8 -Path (Join-Path $caller 'relative-input.txt') -Text 'caller input'
    $result = Join-Path $TmpDir 'shim-result.txt'
    $target = Join-Path $dest 'probe.cmd'
    Write-Utf8 -Path $target -Text (@(
        '@echo off'
        '> "%RT_TEST_RESULT%" echo argument=%~1'
        '>> "%RT_TEST_RESULT%" echo duringjava=%JAVA_HOME%'
        '>> "%RT_TEST_RESULT%" echo duringcwd=%CD%'
        'if exist relative-input.txt >> "%RT_TEST_RESULT%" echo relative=present'
        'exit /b 7'
    ) -join "`r`n")
    $java = Join-Path $testRoot 'fake jdk'
    $shim = Write-Shim -Name 'probe' -Target $target -JavaHome $java
    $parent = Join-Path $TmpDir 'shim-caller.cmd'
    Write-Utf8 -Path $parent -Text (@(
        '@echo off'
        'set "JAVA_HOME=caller-java"'
        ('set "RT_TEST_RESULT=' + $result + '"')
        ('cd /d "' + $caller + '"')
        ('call "' + $shim + '" "argument with spaces"')
        'set "RT_TEST_EXIT=%ERRORLEVEL%"'
        '>> "%RT_TEST_RESULT%" echo aftercwd=%CD%'
        '>> "%RT_TEST_RESULT%" echo afterjava=%JAVA_HOME%'
        '>> "%RT_TEST_RESULT%" echo exit=%RT_TEST_EXIT%'
        'exit /b 0'
    ) -join "`r`n")
    & $parent
    Assert-True ($LASTEXITCODE -eq 0) 'The shim caller did not finish'
    $lines = @(Get-Content -LiteralPath $result)
    Assert-True ($lines -contains 'argument=argument with spaces') 'A shim damaged quoted arguments'
    Assert-True ($lines -contains ('duringjava=' + $java)) 'A shim did not set its private JDK'
    Assert-True ($lines -contains ('duringcwd=' + $caller)) 'A CLI shim changed the working directory used for relative input paths'
    Assert-True ($lines -contains 'relative=present') 'A CLI shim could not see an input file relative to its caller'
    Assert-True ($lines -contains ('aftercwd=' + $caller)) 'A shim changed its caller working directory'
    Assert-True ($lines -contains 'afterjava=caller-java') 'A shim leaked environment changes into its caller'
    Assert-True ($lines -contains 'exit=7') 'A shim lost the tool exit code'

    $record = [pscustomobject]@{
        id = 'probe'; version = 'v1'; asset = 'probe.zip'; sha256 = ('a' * 64)
        hash_source = 'computed'; dir = 'sandbox/tools/probe'; shims = [pscustomobject]@{ probe = 'sandbox/bin/probe.cmd' }
    }
    $script:InstallState.tools | Add-Member -NotePropertyName probe -NotePropertyValue $record -Force
    Write-Marker -Dest $dest -Marker 'v1|probe.zip'
    Remove-Item -LiteralPath $shim -Force
    $cached = Test-AlreadyInstalled -Dest $dest -Marker 'v1|probe.zip'
    Assert-True $cached 'A complete cached payload was not reused'
    Assert-True (Test-Path -LiteralPath $shim) 'A cached install did not recreate its missing shim'

    $legacy = [pscustomobject]@{
        schema = 1; kit_version = $kitVersion; kit_root = $KitRoot; java_home = $null
        tools = [pscustomobject]@{ probe = @('archive progress', $record) }
    }
    Write-Utf8 -Path $StatePath -Text ($legacy | ConvertTo-Json -Depth 8)
    $loaded = New-State
    Assert-True ($loaded.tools.probe -isnot [array]) 'Legacy progress strings were not removed from installed state'
    Assert-True ($loaded.tools.probe.id -eq 'probe') 'State repair lost the valid tool record'

    $unrelated = 'a' * 64
    $release = [pscustomobject]@{ assets = @(); body = "Linux archive SHA256: $unrelated" }
    Assert-True ($null -eq (Get-PublishedHash -Release $release -AssetName 'probe.zip')) 'A release body hash was incorrectly applied to another asset'
    $expected = 'b' * 64
    $release.assets = @([pscustomobject]@{ name = 'probe.zip'; digest = ('sha256:' + $expected) })
    $published = Get-PublishedHash -Release $release -AssetName 'probe.zip'
    Assert-True ($published.hash -eq $expected -and $published.source -eq 'github-digest') 'The exact asset digest was not selected'
    Assert-True ($null -eq (Get-PublishedHash -Release $release -AssetName 'other.zip')) 'An asset digest was incorrectly applied to another filename'
    $commit = 'c' * 40
    $url = Get-GitHubArchiveUrl -Repo 'owner/repo' -Kind 'commit' -Ref $commit
    Assert-True ($url -eq "https://github.com/owner/repo/archive/$commit.zip") 'Source archive URL did not pin the recorded commit'
    $threw = $false
    try { Get-GitHubArchiveUrl -Repo 'owner/repo' -Kind 'commit' -Ref 'main' | Out-Null } catch { $threw = $true }
    Assert-True $threw 'A mutable branch was accepted as a commit archive'

    $atomic = Join-Path $TmpDir 'atomic.json'
    Write-AtomicJson -Path $atomic -Text '{"phase":"old"}'
    $threw = $false
    try { Write-AtomicJson -Path $atomic -Text '{broken' } catch { $threw = $true }
    Assert-True $threw 'An invalid state document was accepted'
    Assert-True ((Get-Content -LiteralPath $atomic -Raw | ConvertFrom-Json).phase -eq 'old') 'A failed state update damaged the last valid document'
    Write-AtomicJson -Path $atomic -Text '{"phase":"new"}'
    Assert-True ((Get-Content -LiteralPath $atomic -Raw | ConvertFrom-Json).phase -eq 'new') 'Atomic state replacement did not write the new document'
    Assert-True (-not (Test-Path -LiteralPath ($atomic + '.new'))) 'Atomic state replacement left a temporary document behind'

    $savedRelease = ${function:Get-GitHubRelease}
    $savedJdk = ${function:Install-Jdk}
    $savedDownload = ${function:Save-Url}
    try {
        function Get-GitHubRelease {
            return [pscustomobject]@{ tag_name = 'v1'; assets = @([pscustomobject]@{ name = 'probe.zip' }) }
        }
        function Install-Jdk { return $script:FakeJavaHome }
        function Save-Url { throw 'A cached install unexpectedly attempted a download' }
        $tool | Add-Member -NotePropertyName repo -NotePropertyValue 'fixture/repo' -Force
        $tool | Add-Member -NotePropertyName asset_pattern -NotePropertyValue '^probe\.zip$' -Force
        $tool.needs_jdk = 25
        $script:FakeJavaHome = $java
        $script:JavaHome = $null
        Write-AtomicJson -Path (Join-Path $dest '.kit-record.json') -Text ($record | ConvertTo-Json -Depth 8)
        $script:InstallState.tools = [pscustomobject]@{}
        Remove-Item -LiteralPath $StatePath -Force
        Remove-Item -LiteralPath $shim -Force
        $recovered = @(Install-One $tool)
        Assert-True ($recovered.Count -eq 1 -and $recovered[0].id -eq 'probe') 'A missing global state lost the recoverable per-tool record'
        Assert-True (Test-Path -LiteralPath $shim) 'A missing global state prevented cached shim repair'
        Assert-True ($script:JavaHome -eq $java) 'A cached Java tool did not repair its JDK selection'
        Assert-True ((Get-Content -LiteralPath $shim -Raw).Contains('set "JAVA_HOME=' + $java + '"')) 'A repaired Java shim omitted its selected JDK'
    } finally {
        Set-Item Function:\Get-GitHubRelease -Value $savedRelease
        Set-Item Function:\Install-Jdk -Value $savedJdk
        Set-Item Function:\Save-Url -Value $savedDownload
        $tool.needs_jdk = $null
    }

    $savedZipInstall = ${function:Install-GitHubZipTool}
    try {
        $rollbackTool = [pscustomobject]@{
            id = 'rollback'; method = 'github-release'
            shims = @([pscustomobject]@{ name = 'rollback'; exe_glob = 'rollback.cmd' })
        }
        $rollbackDest = Join-Path $ToolsDir 'rollback'
        $oldDirectory = Join-Path $rollbackDest 'legacy'
        New-Item -ItemType Directory -Path $oldDirectory -Force | Out-Null
        Write-Utf8 -Path (Join-Path $oldDirectory 'rollback.cmd') -Text 'old executable'
        Write-Utf8 -Path (Join-Path $rollbackDest 'old.txt') -Text 'old payload'
        $oldShim = Write-Shim -Name 'rollback' -Target (Join-Path $oldDirectory 'rollback.cmd')
        $oldShimText = Get-Content -LiteralPath $oldShim -Raw
        $script:RollbackStage = Join-Path $TmpDir 'rollback-stage'
        $modernDirectory = Join-Path $script:RollbackStage 'modern'
        New-Item -ItemType Directory -Path $modernDirectory -Force | Out-Null
        Write-Utf8 -Path (Join-Path $modernDirectory 'rollback.cmd') -Text 'new executable'
        Write-Utf8 -Path (Join-Path $script:RollbackStage 'readme.txt') -Text 'keep the modern subdirectory'
        function Install-GitHubZipTool {
            param($Tool)
            Move-FlattenedStage -Stage $script:RollbackStage -Dest (Join-Path $ToolsDir $Tool.id)
            Install-Shims -Tool $Tool -Dest (Join-Path $ToolsDir $Tool.id) | Out-Null
            throw 'Injected post-promotion failure'
        }
        $threw = $false
        try { Install-One $rollbackTool | Out-Null } catch { $threw = $true }
        Assert-True $threw 'A failure after payload promotion was accepted'
        Assert-True ((Get-Content -LiteralPath (Join-Path $rollbackDest 'legacy\rollback.cmd') -Raw) -eq 'old executable') 'Transaction rollback lost the previous executable'
        Assert-True ((Get-Content -LiteralPath (Join-Path $rollbackDest 'old.txt') -Raw) -eq 'old payload') 'Transaction rollback lost the previous payload'
        Assert-True ((Get-Content -LiteralPath $oldShim -Raw) -ceq $oldShimText) 'Transaction rollback left a shim pointing at the failed new payload'
    } finally {
        Set-Item Function:\Install-GitHubZipTool -Value $savedZipInstall
    }

    $savedCatalog = ${function:Get-Catalog}
    $savedInstall = ${function:Install-One}
    try {
        function Get-Catalog {
            return [pscustomobject]@{ tools = @([pscustomobject]@{ id = '7zip'; unpack = 'msi-admin' }) }
        }
        function Install-One {
            param($Tool)
            $script:CurrentTool = $Tool
            $script:CachedRecord = 'dependency cached record'
            $script:PromotedBackup = 'dependency backup'
            $sevenDir = Join-Path $ToolsDir '7zip'
            New-Item -ItemType Directory -Path $sevenDir -Force | Out-Null
            Write-Utf8 -Path (Join-Path $sevenDir '7z.exe') -Text 'fixture'
            Write-Utf8 -Path (Join-Path $sevenDir '7z.dll') -Text 'fixture'
            return [pscustomobject]@{ id = '7zip'; version = 'fixture' }
        }
        $script:CurrentTool = $tool
        $script:CachedRecord = $record
        $script:PromotedBackup = 'parent backup'
        $sevenPath = Get-SevenZip
        Assert-True (Test-Path -LiteralPath $sevenPath) 'A nested archive dependency did not return its executable'
        Assert-True ($script:CurrentTool.id -eq 'probe') 'A nested dependency changed its parent tool context'
        Assert-True ($script:CachedRecord.id -eq 'probe') 'A nested dependency changed its parent cached record'
        Assert-True ($script:PromotedBackup -eq 'parent backup') 'A nested dependency changed its parent rollback source'
    } finally {
        Set-Item Function:\Get-Catalog -Value $savedCatalog
        Set-Item Function:\Install-One -Value $savedInstall
    }

    $libraryTool = [pscustomobject]@{ id = 'library'; method = 'pip-venv'; package = 'lief'; shims = @() }
    $libraryDest = Join-Path $ToolsDir 'library'
    New-Item -ItemType Directory -Path $libraryDest | Out-Null
    Write-Marker -Dest $libraryDest -Marker 'present'
    $threw = $false
    try { Assert-ToolPayload -Tool $libraryTool -Dest $libraryDest } catch { $threw = $true }
    Assert-True $threw 'A Python library without its interpreter passed payload validation'

    $savedRelease = ${function:Get-GitHubRelease}
    $savedDownload = ${function:Save-Url}
    try {
        $script:RawFixtureText = 'offline jar fixture'
        $rawFixture = Join-Path $TmpDir 'raw-fixture.jar'
        Write-Utf8 -Path $rawFixture -Text $script:RawFixtureText
        $script:RawDigest = Get-Sha256Hex $rawFixture
        function Get-GitHubRelease {
            return [pscustomobject]@{
                tag_name = 'v1'; assets = @([pscustomobject]@{
                    name = 'probe_1.jar'; digest = ('sha256:' + $script:RawDigest)
                    browser_download_url = 'https://github.com/fixture/repo/releases/download/v1/probe_1.jar'
                })
            }
        }
        function Save-Url {
            param([string]$Url, [string]$Dest)
            Write-Utf8 -Path $Dest -Text $script:RawFixtureText
        }
        $rawTool = [pscustomobject]@{
            id = 'raw-probe'; method = 'github-release'; repo = 'fixture/repo'
            asset_pattern = '^probe_[0-9]+\.jar$'; unpack = 'raw'; needs_jdk = 25
            shims = @([pscustomobject]@{ name = 'raw-probe'; exe_glob = 'probe_*.jar'; java_jar = $true })
        }
        $script:JavaHome = $java
        $rawRecord = @(Install-One $rawTool)
        Assert-True ($rawRecord.Count -eq 1 -and $rawRecord[0].id -eq 'raw-probe') 'A raw JAR install did not return exactly one tool record'
        Assert-True ($rawRecord[0].sha256 -eq $script:RawDigest -and $rawRecord[0].hash_source -eq 'github-digest') 'A raw JAR install lost its exact asset digest'
        $jarPath = Join-Path $ToolsDir 'raw-probe\probe_1.jar'
        Assert-True ((Get-Content -LiteralPath $jarPath -Raw) -eq $script:RawFixtureText) 'A raw JAR payload was changed during installation'
        $jarShim = Get-Content -LiteralPath (Join-Path $BinDir 'raw-probe.cmd') -Raw
        Assert-True ($jarShim.Contains('"%JAVA_HOME%\bin\java.exe" -jar ')) 'A raw JAR shim did not invoke the selected Java runtime'
    } finally {
        Set-Item Function:\Get-GitHubRelease -Value $savedRelease
        Set-Item Function:\Save-Url -Value $savedDownload
    }

    $savedPath = $env:PATH
    $savedNpmVersion = $env:RT_NPM_VERSION
    try {
        $npmBin = Join-Path $TmpDir 'fake npm'
        New-Item -ItemType Directory -Path $npmBin | Out-Null
        $npmExe = Join-Path $npmBin 'npm.cmd'
        Write-Utf8 -Path $npmExe -Text (@(
            '@echo off'
            'echo npm progress'
            'mkdir "%~3\node_modules\@electron\asar" 2>nul'
            'mkdir "%~3\node_modules\.bin" 2>nul'
            '> "%~3\node_modules\@electron\asar\package.json" echo {"name":"@electron/asar","version":"%RT_NPM_VERSION%"}'
            '> "%~3\node_modules\.bin\asar.cmd" echo @echo off'
            '>> "%~3\node_modules\.bin\asar.cmd" echo exit /b 0'
            '> "%~3\invocation.txt" echo %*'
            'exit /b 0'
        ) -join "`r`n")
        $env:PATH = $npmBin + ';' + $savedPath
        $env:RT_NPM_VERSION = '1.2.3'
        $npmTool = [pscustomobject]@{
            id = 'npm-probe'; method = 'npm-tool'; package = '@electron/asar'
            shims = @([pscustomobject]@{ name = 'npm-probe'; exe_glob = 'asar.cmd' })
        }
        $npmRecord = @(Install-One $npmTool)
        Assert-True ($npmRecord.Count -eq 1 -and $npmRecord[0].version -eq '1.2.3') 'An npm install leaked output or lost its package version'
        $npmDest = Join-Path $ToolsDir 'npm-probe'
        $npmArguments = Get-Content -LiteralPath (Join-Path $npmDest 'invocation.txt') -Raw
        Assert-True ($npmArguments.Contains('--ignore-scripts') -and $npmArguments.Contains('--engine-strict')) 'An npm install allowed lifecycle scripts or ignored required engines'
        $Force = $true
        $env:RT_NPM_VERSION = '1.2.4'
        $npmRecord = @(Install-One $npmTool)
        Assert-True ($npmRecord.Count -eq 1 -and $npmRecord[0].version -eq '1.2.4') 'A forced npm update did not replace the package version'
    } finally {
        $Force = $false
        $env:PATH = $savedPath
        $env:RT_NPM_VERSION = $savedNpmVersion
    }
    Write-Host 'installer regression checks ok'
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $base = [IO.Path]::GetFullPath($testBase).TrimEnd('\') + '\'
    if ($resolved.StartsWith($base, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolved) -match '^tests-[a-f0-9]{32}$' -and
        (Test-Path -LiteralPath $resolved)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
