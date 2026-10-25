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
    $helperDir = Join-Path $stage 'x86'
    New-Item -ItemType Directory -Path $helperDir | Out-Null
    Write-Utf8 -Path (Join-Path $helperDir 'probe.cmd') -Text 'other architecture helper'
    Assert-True ((Find-ToolFile -Root $stage -Glob 'probe.cmd').FullName -eq (Join-Path $stage 'probe.cmd')) 'A nested architecture helper displaced the main executable'
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
        '>> "%RT_TEST_RESULT%" echo duringdotnet=%DOTNET_ROOT%'
        '>> "%RT_TEST_RESULT%" echo duringdotnetx64=%DOTNET_ROOT_X64%'
        '>> "%RT_TEST_RESULT%" echo duringcwd=%CD%'
        'if exist relative-input.txt >> "%RT_TEST_RESULT%" echo relative=present'
        'exit /b 7'
    ) -join "`r`n")
    $java = Join-Path $testRoot 'fake jdk!%RT_KIT_MARKER%'
    $dotnetHome = Join-Path $testRoot 'fake dotnet!%RT_KIT_MARKER%'
    $shim = Write-Shim -Name 'probe' -Target $target -JavaHome $java -DotNetHome $dotnetHome
    $parent = Join-Path $TmpDir 'shim-caller.cmd'
    Write-Utf8 -Path $parent -Text (@(
        '@echo off'
        'set "JAVA_HOME=caller-java"'
        'set "DOTNET_ROOT=caller-dotnet"'
        'set "DOTNET_ROOT_X64=caller-dotnet-x64"'
        ('set "RT_TEST_RESULT=' + $result + '"')
        ('cd /d "' + $caller + '"')
        ('call "' + $shim + '" "argument with spaces"')
        'set "RT_TEST_EXIT=%ERRORLEVEL%"'
        '>> "%RT_TEST_RESULT%" echo aftercwd=%CD%'
        '>> "%RT_TEST_RESULT%" echo afterjava=%JAVA_HOME%'
        '>> "%RT_TEST_RESULT%" echo afterdotnet=%DOTNET_ROOT%'
        '>> "%RT_TEST_RESULT%" echo afterdotnetx64=%DOTNET_ROOT_X64%'
        '>> "%RT_TEST_RESULT%" echo exit=%RT_TEST_EXIT%'
        'exit /b 0'
    ) -join "`r`n")
    & $parent
    Assert-True ($LASTEXITCODE -eq 0) 'The shim caller did not finish'
    $lines = @(Get-Content -LiteralPath $result)
    Assert-True ($lines -contains 'argument=argument with spaces') 'A shim damaged quoted arguments'
    Assert-True ($lines -contains ('duringjava=' + $java)) 'A shim did not set its private JDK'
    Assert-True ($lines -contains ('duringdotnet=' + $dotnetHome) -and $lines -contains ('duringdotnetx64=' + $dotnetHome)) 'A shim did not set its private .NET runtime'
    Assert-True ($lines -contains ('duringcwd=' + $caller)) 'A CLI shim changed the working directory used for relative input paths'
    Assert-True ($lines -contains 'relative=present') 'A CLI shim could not see an input file relative to its caller'
    Assert-True ($lines -contains ('aftercwd=' + $caller)) 'A shim changed its caller working directory'
    Assert-True ($lines -contains 'afterjava=caller-java') 'A shim leaked environment changes into its caller'
    Assert-True ($lines -contains 'afterdotnet=caller-dotnet' -and $lines -contains 'afterdotnetx64=caller-dotnet-x64') 'A shim leaked .NET runtime settings into its caller'
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

    # Use a real Windows handle denying delete sharing, then release it independently.
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
public static class AtomicJsonLockFixture {
    public static Task Hold(string path, int milliseconds) {
        var handle = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.Read);
        return Task.Run(() => { try { Thread.Sleep(milliseconds); } finally { handle.Dispose(); } });
    }
    public static IOException Error(int code) {
        return new IOException("Injected Win32 " + code, unchecked((int)0x80070000) | code);
    }
}
'@
    $releaseLock = [AtomicJsonLockFixture]::Hold($atomic, 400)
    try {
        Write-AtomicJson -Path $atomic -Text '{"phase":"lock-released"}'
        Assert-True ((Get-Content -LiteralPath $atomic -Raw | ConvertFrom-Json).phase -eq 'lock-released') 'Atomic replacement did not recover after a real sharing lock released'
        Assert-True (-not (Test-Path -LiteralPath ($atomic + '.new'))) 'A recovered sharing lock left the new document uncommitted'
    } finally { $releaseLock.Wait() }
    $heldLock = [IO.File]::Open($atomic, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $failure = $null
        try { Write-AtomicJson -Path $atomic -Text '{"phase":"pending"}' } catch { $failure = $_.Exception }
        while ($failure -and $failure -isnot [IO.IOException]) { $failure = $failure.InnerException }
        Assert-True ($null -ne $failure -and ($failure.HResult -band 0xFFFF) -eq 32) 'An exhausted real sharing lock did not surface its IOException'
        Assert-True ((Get-Content -LiteralPath $atomic -Raw | ConvertFrom-Json).phase -eq 'lock-released') 'An exhausted sharing lock changed the good target'
        Assert-True ((Get-Content -LiteralPath ($atomic + '.new') -Raw | ConvertFrom-Json).phase -eq 'pending') 'An exhausted sharing lock lost the pending replacement'
    } finally { $heldLock.Dispose() }

    # Inject only the native replace boundary to deterministically cover Win32 1175 and bounds.
    $savedAtomicWriter = ${function:Write-AtomicJson}
    try {
        $probeBody = $savedAtomicWriter.ToString().Replace(
            '[IO.File]::Replace($temp, $Path, [NullString]::Value)',
            'Invoke-AtomicReplaceFixture -Source $temp -Target $Path')
        Assert-True ($probeBody -ne $savedAtomicWriter.ToString()) 'Atomic replace fixture did not intercept the native boundary'
        Set-Item Function:\Write-AtomicJson -Value ([scriptblock]::Create($probeBody))
        function Invoke-AtomicReplaceFixture {
            param([string]$Source, [string]$Target)
            $script:AtomicAttempts++
            if ($script:AtomicAttempts -le $script:AtomicFailures) { throw [AtomicJsonLockFixture]::Error($script:AtomicErrorCode) }
            [IO.File]::Replace($Source, $Target, [NullString]::Value)
        }
        $script:AtomicAttempts = 0
        $script:AtomicFailures = 2
        $script:AtomicErrorCode = 1175
        Write-AtomicJson -Path $atomic -Text '{"phase":"retry-success"}'
        Assert-True ($script:AtomicAttempts -eq 3 -and (Get-Content -LiteralPath $atomic -Raw | ConvertFrom-Json).phase -eq 'retry-success') 'An unchanged-files Win32 1175 failure was not retried successfully'
        foreach ($code in @(1175, 5, 1176, 1177)) {
            $script:AtomicAttempts = 0
            $script:AtomicFailures = 99
            $script:AtomicErrorCode = $code
            $failure = $null
            try { Write-AtomicJson -Path $atomic -Text '{"phase":"pending-failure"}' } catch { $failure = $_.Exception }
            while ($failure -and $failure -isnot [IO.IOException]) { $failure = $failure.InnerException }
            $expectedAttempts = if ($code -eq 1175) { 6 } else { 1 }
            Assert-True ($script:AtomicAttempts -eq $expectedAttempts -and $failure -and ($failure.HResult -band 0xFFFF) -eq $code) ('Atomic replacement did not bound or surface Win32 ' + $code)
            Assert-True ((Get-Content -LiteralPath $atomic -Raw | ConvertFrom-Json).phase -eq 'retry-success') ('A failed Win32 ' + $code + ' update damaged the good target')
            Assert-True ((Get-Content -LiteralPath ($atomic + '.new') -Raw | ConvertFrom-Json).phase -eq 'pending-failure') ('A failed Win32 ' + $code + ' update lost its new document')
        }
    } finally {
        Set-Item Function:\Write-AtomicJson -Value $savedAtomicWriter
        Remove-Item Function:\Invoke-AtomicReplaceFixture
    }
    Write-AtomicJson -Path $atomic -Text '{"phase":"final-recovery"}'
    Assert-True ((Get-Content -LiteralPath $atomic -Raw | ConvertFrom-Json).phase -eq 'final-recovery') 'A later atomic write did not recover after lock exhaustion'

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
        Assert-True ((Get-Content -LiteralPath $shim -Raw).Contains('set "JAVA_HOME=' + $java.Replace('%', '%%') + '"')) 'A repaired Java shim omitted its selected JDK'
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

    $supportRoot = Join-Path $TmpDir 'support-validation'
    $signatureDir = Join-Path $supportRoot 'source'
    New-Item -ItemType Directory -Path (Join-Path $signatureDir 'sigs') -Force | Out-Null
    Write-Utf8 -Path (Join-Path $signatureDir 'README.md') -Text 'documentation only'
    $sourceTool = [pscustomobject]@{ id = 'capa-source'; method = 'github-archive'; shims = @() }
    $threw = $false
    try { Assert-ToolPayload -Tool $sourceTool -Dest $signatureDir } catch { $threw = $true }
    Assert-True $threw 'capa source documentation passed validation without signatures'
    Write-Utf8 -Path (Join-Path $signatureDir 'sigs\fixture.sig') -Text ''
    $threw = $false
    try { Assert-ToolPayload -Tool $sourceTool -Dest $signatureDir } catch { $threw = $true }
    Assert-True $threw 'An empty capa signature passed validation'
    Write-Utf8 -Path (Join-Path $signatureDir 'sigs\fixture.sig') -Text 'signature fixture'
    Assert-ToolPayload -Tool $sourceTool -Dest $signatureDir
    $rulesDir = Join-Path $supportRoot 'rules'
    New-Item -ItemType Directory -Path (Join-Path $rulesDir '.github\workflows'), (Join-Path $rulesDir 'collection\.hidden') -Force | Out-Null
    Write-Utf8 -Path (Join-Path $rulesDir '.github\workflows\ci.yml') -Text 'workflow, not a capability rule'
    Write-Utf8 -Path (Join-Path $rulesDir 'collection\.hidden\fixture.yml') -Text 'hidden fixture'
    $rulesTool = [pscustomobject]@{ id = 'capa-rules'; method = 'github-archive'; shims = @() }
    $threw = $false
    try { Assert-ToolPayload -Tool $rulesTool -Dest $rulesDir } catch { $threw = $true }
    Assert-True $threw 'Workflow or hidden YAML passed validation as capa capability rules'
    Write-Utf8 -Path (Join-Path $rulesDir 'collection\fixture.yml') -Text ''
    $threw = $false
    try { Assert-ToolPayload -Tool $rulesTool -Dest $rulesDir } catch { $threw = $true }
    Assert-True $threw 'An empty capa capability rule passed validation'
    Write-Utf8 -Path (Join-Path $rulesDir 'collection\fixture.yml') -Text 'rule fixture'
    Assert-ToolPayload -Tool $rulesTool -Dest $rulesDir

    $oldBinDir = $BinDir
    $savedBangResult = $env:RT_BANG_RESULT
    $savedKitMarker = $env:RT_KIT_MARKER
    try {
        $env:RT_KIT_MARKER = 'wrong-expanded-path'
        foreach ($kitName in @('kit! literal & (lab)', 'kit%RT_KIT_MARKER%')) {
        $bangRoot = Join-Path $testRoot $kitName
        $BinDir = Join-Path $bangRoot 'bin'
        $bangTools = Join-Path $bangRoot 'tools'
        New-Item -ItemType Directory -Path $BinDir, $bangTools -Force | Out-Null
        $bangTarget = Join-Path $bangTools 'probe.cmd'
        $env:RT_BANG_RESULT = Join-Path $TmpDir 'bang-result.txt'
        Write-Utf8 -Path $bangTarget -Text "@echo off`r`n> `"%RT_BANG_RESULT%`" echo reached`r`nexit /b 0`r`n"
        Write-Shim -Name 'probe' -Target $bangTarget | Out-Null
        Push-Location -LiteralPath $BinDir
        try { & $env:ComSpec /d /v:on /c probe.cmd } finally { Pop-Location }
        Assert-True ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $env:RT_BANG_RESULT)) 'A shim inherited delayed expansion and damaged a path containing !'
        Remove-Item -LiteralPath $env:RT_BANG_RESULT -Force
        }
    } finally {
        $BinDir = $oldBinDir
        $env:RT_BANG_RESULT = $savedBangResult
        $env:RT_KIT_MARKER = $savedKitMarker
    }

    $customPointer = '{"custom":{"a":{"b":{"c":{"d":{"e":{"keep":["nested","values"]}}}}}}}'
    Write-AtomicJson -Path $PointerPath -Text $customPointer
    Save-State $script:InstallState
    $pointer = Get-Content -LiteralPath $PointerPath -Raw | ConvertFrom-Json
    Assert-True (($pointer.custom.a.b.c.d.e.keep -join ',') -eq 'nested,values') 'Saving state truncated nested personal pointer fields'

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

    $savedNpmInstall = ${function:Install-NpmTool}
    try {
        $copyTool = [pscustomobject]@{
            id = 'backup-copy'; method = 'npm-tool'; package = 'fixture'
            shims = @([pscustomobject]@{ name = 'backup-copy'; exe_glob = 'probe.cmd' })
        }
        $copyDest = Join-Path $ToolsDir 'backup-copy'
        New-Item -ItemType Directory -Path $copyDest | Out-Null
        Write-Utf8 -Path (Join-Path $copyDest 'probe.cmd') -Text 'old executable'
        Write-Utf8 -Path (Join-Path $copyDest 'keep.txt') -Text 'old complete payload'
        $copyShim = Write-Shim -Name 'backup-copy' -Target (Join-Path $copyDest 'probe.cmd')
        $copyShimText = Get-Content -LiteralPath $copyShim -Raw
        function Copy-Item {
            param([string]$LiteralPath, [string]$Destination, [switch]$Recurse)
            New-Item -ItemType Directory -Path $Destination -Force | Out-Null
            Write-Utf8 -Path (Join-Path $Destination 'incomplete.txt') -Text 'partial backup'
            throw 'Injected backup copy failure'
        }
        function Install-NpmTool { throw 'Package installation must not run after backup failure' }
        $Force = $true
        $copyFailure = $null
        try { Install-One $copyTool | Out-Null } catch { $copyFailure = $_.Exception.Message }
        Assert-True ($copyFailure -eq 'Injected backup copy failure') 'A partial backup copy failure was not propagated'
        Assert-True ((Get-Content -LiteralPath (Join-Path $copyDest 'keep.txt') -Raw) -eq 'old complete payload') 'A partial backup replaced the intact previous payload'
        Assert-True ((Get-Content -LiteralPath (Join-Path $copyDest 'probe.cmd') -Raw) -eq 'old executable') 'A partial backup lost the intact previous executable'
        Assert-True ((Get-Content -LiteralPath $copyShim -Raw) -ceq $copyShimText) 'A backup copy failure changed the previous shim'
    } finally {
        $Force = $false
        Remove-Item Function:\Copy-Item
        Set-Item Function:\Install-NpmTool -Value $savedNpmInstall
    }

    $savedRelease = ${function:Get-GitHubRelease}
    $savedCatalog = ${function:Get-Catalog}
    $savedArchive = ${function:Install-GitHubArchive}
    $savedPip = ${function:Install-PipVenv}
    $savedExtra = $script:ExtraInstalled
    try {
        $script:CapaTag = 'v99.2.3'
        $script:FailCapaPackage = $false
        $script:FailCapaDependency = $null
        function Get-GitHubRelease { return [pscustomobject]@{ tag_name = $script:CapaTag } }
        function Get-Catalog {
            return [pscustomobject]@{ tools = @(
                [pscustomobject]@{ id = 'capa-rules'; method = 'github-archive'; shims = @() }
                [pscustomobject]@{ id = 'capa-source'; method = 'github-archive'; shims = @() }
            ) }
        }
        $script:CapaDependencies = @()
        $script:ExtraInstalled = @()
        function Install-GitHubArchive {
            param($Tool)
            $script:CapaDependencies += [pscustomobject]@{ id = $Tool.id; tag = $Tool.release }
            $dependencyDir = Join-Path $ToolsDir $Tool.id
            $stage = Join-Path $TmpDir ('capa-stage-' + [guid]::NewGuid().ToString('N'))
            $category = if ($Tool.id -eq 'capa-rules') { 'collection' } else { 'sigs' }
            $support = Join-Path $stage $category
            New-Item -ItemType Directory -Path $support -Force | Out-Null
            $name = if ($Tool.id -eq 'capa-rules') { 'fixture.yml' } else { 'fixture.sig' }
            Write-Utf8 -Path (Join-Path $support $name) -Text $Tool.release
            Write-Utf8 -Path (Join-Path $stage 'fixture.txt') -Text $Tool.release
            Move-FlattenedStage -Stage $stage -Dest $dependencyDir
            Write-Marker -Dest $dependencyDir -Marker ('tag|' + $Tool.release)
            if ($script:FailCapaDependency -eq $Tool.id) { throw 'Injected later capa dependency failure' }
            return [pscustomobject]@{ id = $Tool.id; version = $Tool.release; shims = @{}; dir = Get-RelativeKitPath $dependencyDir }
        }
        function Install-PipVenv {
            param($Tool)
            $script:CapaPackageVersion = $Tool.package_version
            $packageDir = Join-Path $ToolsDir $Tool.id
            $scripts = Join-Path $packageDir 'Scripts'
            $metadata = Join-Path $packageDir ('Lib\site-packages\flare_capa-' + $Tool.package_version + '.dist-info')
            New-Item -ItemType Directory -Path $scripts, $metadata -Force | Out-Null
            Write-Utf8 -Path (Join-Path $scripts 'python.exe') -Text 'fixture interpreter, never executed'
            Write-Utf8 -Path (Join-Path $scripts 'capa.cmd') -Text "@echo off`r`nexit /b 0`r`n"
            Write-Utf8 -Path (Join-Path $metadata 'METADATA') -Text ('Version: ' + $Tool.package_version)
            Write-Utf8 -Path (Join-Path $packageDir 'package-version.txt') -Text $Tool.package_version
            $made = Install-Shims -Tool $Tool -Dest $packageDir
            Write-Marker -Dest $packageDir -Marker 'present'
            if ($script:FailCapaPackage) { throw 'Injected capa package failure' }
            return [pscustomobject]@{ id = $Tool.id; version = $Tool.package_version; shims = $made; dir = Get-RelativeKitPath $packageDir }
        }
        $capaTool = [pscustomobject]@{
            id = 'capa'; method = 'pip-venv'; package = 'flare-capa'; requires = @('capa-rules', 'capa-source')
            shims = @([pscustomobject]@{ name = 'capa'; exe_glob = 'capa.cmd' })
        }
        $capaRecord = Install-One $capaTool
        Assert-True ($script:CapaDependencies.Count -eq 2) 'capa did not install both rule and signature dependencies'
        Assert-True (@($script:CapaDependencies | Where-Object { $_.tag -ne 'v99.2.3' }).Count -eq 0) 'capa dependencies did not use the exact package release tag'
        Assert-True ($script:CapaPackageVersion -eq '99.2.3' -and $capaRecord.version -eq '99.2.3') 'capa package version did not match its rule and signature release'
        $pipSpecAssignment = $ast.Find({
            param($node)
            $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -eq '$packageSpec'
        }, $true)
        Assert-True ($null -ne $pipSpecAssignment) 'The pip package version specification is missing'
        $spec = & {
            param($Tool, $Assignment)
            Invoke-Expression $Assignment
            $packageSpec
        } $capaTool $pipSpecAssignment.Extent.Text
        Assert-True ($spec -eq 'flare-capa==99.2.3') 'The pip package specification did not pin the matching capa version'
        $capaDest = Join-Path $ToolsDir 'capa'
        $capaRecord.version = '99.1.0'
        Write-AtomicJson -Path (Join-Path $capaDest '.kit-record.json') -Text ($capaRecord | ConvertTo-Json -Depth 8)
        $script:CurrentTool = $capaTool
        Assert-True (-not (Test-AlreadyInstalled -Dest $capaDest -Marker 'present')) 'An old capa package was reused with a newer rule release'
        $capaRecord.version = '99.2.3'
        Write-AtomicJson -Path (Join-Path $capaDest '.kit-record.json') -Text ($capaRecord | ConvertTo-Json -Depth 8)
        Assert-True (Test-AlreadyInstalled -Dest $capaDest -Marker 'present') 'A matching capa package was not reusable'

        $script:InstallState.tools | Add-Member -NotePropertyName capa -NotePropertyValue $capaRecord -Force
        Merge-ExtraInstalled $script:InstallState
        $beforeGroup = @{}
        foreach ($id in @('capa', 'capa-rules', 'capa-source')) {
            $groupDir = Join-Path $ToolsDir $id
            $beforeGroup[$id] = (@(Get-ChildItem -LiteralPath $groupDir -Recurse -File -Force | ForEach-Object {
                $_.FullName.Substring($groupDir.Length) + ':' + (Get-Sha256Hex $_.FullName)
            } | Sort-Object) -join "`n")
        }
        $beforeCapaShim = Get-Content -LiteralPath (Join-Path $BinDir 'capa.cmd') -Raw
        $sentinel = [pscustomobject]@{ id = 'unrelated'; version = 'keep' }
        $script:CapaTag = 'v99.3.0'
        foreach ($failurePoint in @('package', 'later-dependency')) {
            $script:ExtraInstalled = @($sentinel)
            $script:FailCapaPackage = $failurePoint -eq 'package'
            $script:FailCapaDependency = if ($failurePoint -eq 'later-dependency') { 'capa-source' } else { $null }
            $threw = $false
            try { Install-One $capaTool | Out-Null } catch { $threw = $true }
            Assert-True $threw ('The injected capa ' + $failurePoint + ' failure was accepted')
            foreach ($id in @('capa', 'capa-rules', 'capa-source')) {
                $groupDir = Join-Path $ToolsDir $id
                $after = (@(Get-ChildItem -LiteralPath $groupDir -Recurse -File -Force | ForEach-Object {
                    $_.FullName.Substring($groupDir.Length) + ':' + (Get-Sha256Hex $_.FullName)
                } | Sort-Object) -join "`n")
                Assert-True ($after -ceq $beforeGroup[$id]) ('A failed capa group update changed prior bytes or records: ' + $id)
            }
            Assert-True ((Get-Content -LiteralPath (Join-Path $BinDir 'capa.cmd') -Raw) -ceq $beforeCapaShim) 'A failed capa group update changed its prior shim'
            Assert-True ($script:ExtraInstalled.Count -eq 1 -and $script:ExtraInstalled[0].id -eq 'unrelated') 'A failed capa group update advertised changed dependencies or lost unrelated progress'
            Merge-ExtraInstalled $script:InstallState
            Save-State $script:InstallState
            $saved = New-State
            Assert-True ($saved.tools.capa.version -eq '99.2.3' -and $saved.tools.'capa-rules'.version -eq 'v99.2.3' -and $saved.tools.'capa-source'.version -eq 'v99.2.3') 'A failed capa group update persisted mixed versions'
        }
        # Follow the production catalog order through the actual install selection helper.
        $actualCatalog = Get-Content -LiteralPath (Join-Path $sourceRoot 'catalog\tools.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $routingCatalog = [pscustomobject]@{ tools = @($actualCatalog.tools | Where-Object { $_.id -in @('capa-rules', 'capa-source', 'capa') } | ForEach-Object {
            if ($_.id -eq 'capa') { $capaTool } else { $_ }
        }) }
        $installSelection = @(Select-InstallTools -Selected $routingCatalog.tools -Catalog $routingCatalog)
        Assert-True ($installSelection.Count -eq 1 -and $installSelection[0].id -eq 'capa') 'Full catalog order installed capa support entries outside their parent transaction'
        foreach ($supportId in @('capa-rules', 'capa-source')) {
            $supportSelection = @($routingCatalog.tools | Where-Object { $_.id -eq $supportId })
            $normalized = @(Select-InstallTools -Selected $supportSelection -Catalog $routingCatalog)
            Assert-True ($normalized.Count -eq 1 -and $normalized[0].id -eq 'capa') ('An explicit support selection bypassed the matching capa group: ' + $supportId)
        }
        $unrelated = [pscustomobject]@{ id = 'unrelated' }
        $normalized = @(Select-InstallTools -Selected @($unrelated) -Catalog $routingCatalog)
        Assert-True ($normalized.Count -eq 1 -and $normalized[0] -eq $unrelated) 'Capa routing changed an unrelated selection'
        $script:FailCapaDependency = $null
        $script:FailCapaPackage = $true
        $script:ExtraInstalled = @()
        $groupFailures = 0
        foreach ($selectedTool in $installSelection) {
            try {
                $row = Install-One $selectedTool
                $script:InstallState.tools | Add-Member -NotePropertyName $selectedTool.id -NotePropertyValue $row -Force
            } catch { $groupFailures++ }
            Merge-ExtraInstalled $script:InstallState
            Save-State $script:InstallState
        }
        Assert-True ($groupFailures -eq 1) 'The catalog-order fixture did not exercise its package failure'
        $saved = New-State
        Assert-True ($saved.tools.capa.version -eq '99.2.3' -and $saved.tools.'capa-rules'.version -eq 'v99.2.3' -and $saved.tools.'capa-source'.version -eq 'v99.2.3') 'The normalized full-install loop persisted a mixed capa group'
        foreach ($id in @('capa', 'capa-rules', 'capa-source')) {
            $groupDir = Join-Path $ToolsDir $id
            $after = (@(Get-ChildItem -LiteralPath $groupDir -Recurse -File -Force | ForEach-Object {
                $_.FullName.Substring($groupDir.Length) + ':' + (Get-Sha256Hex $_.FullName)
            } | Sort-Object) -join "`n")
            Assert-True ($after -ceq $beforeGroup[$id]) ('The normalized full-install loop changed prior capa group bytes: ' + $id)
        }
        $priorTools = $ToolsDir
        try {
            $ToolsDir = Join-Path $Sandbox 'fresh-tools'
            New-Item -ItemType Directory -Path $ToolsDir | Out-Null
            $script:FailCapaDependency = $null
            $script:FailCapaPackage = $true
            $script:ExtraInstalled = @()
            $threw = $false
            try { Install-One $capaTool | Out-Null } catch { $threw = $true }
            Assert-True $threw 'A failing fresh capa install was accepted'
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $ToolsDir 'capa-rules')) -and -not (Test-Path -LiteralPath (Join-Path $ToolsDir 'capa-source'))) 'A failed fresh capa install left new support payloads behind'
            Assert-True ($script:ExtraInstalled.Count -eq 0) 'A failed fresh capa install advertised dependencies'
        } finally { $ToolsDir = $priorTools }
    } finally {
        Set-Item Function:\Get-GitHubRelease -Value $savedRelease
        Set-Item Function:\Get-Catalog -Value $savedCatalog
        Set-Item Function:\Install-GitHubArchive -Value $savedArchive
        Set-Item Function:\Install-PipVenv -Value $savedPip
        $script:ExtraInstalled = $savedExtra
    }
    # Exercise the real archive trust boundary before any extractor or promotion runs.
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipDest = Join-Path $ToolsDir 'zip-probe'
    New-Item -ItemType Directory -Path $zipDest | Out-Null
    Write-Utf8 -Path (Join-Path $zipDest 'probe.cmd') -Text 'old executable'
    Write-Utf8 -Path (Join-Path $zipDest 'keep.txt') -Text 'old payload'
    $outsideSentinel = Join-Path $TmpDir 'zip-escape.txt'
    Write-Utf8 -Path $outsideSentinel -Text 'external sentinel'
    $script:CurrentTool = [pscustomobject]@{
        id = 'zip-probe'; method = 'github-release'
        shims = @([pscustomobject]@{ name = 'zip-probe'; exe_glob = 'probe.cmd' })
    }
    foreach ($kind in @('traversal', 'symlink')) {
        $zip = Join-Path $TmpDir ($kind + '.zip')
        $archive = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
        try {
            $entryName = if ($kind -eq 'traversal') { '../zip-escape.txt' } else { 'linked.txt' }
            $entry = $archive.CreateEntry($entryName)
            if ($kind -eq 'symlink') { $entry.ExternalAttributes = 0xA1FF -shl 16 }
            $writer = New-Object IO.StreamWriter($entry.Open())
            try { $writer.Write('../zip-escape.txt') } finally { $writer.Dispose() }
        } finally { $archive.Dispose() }
        $zipFailure = $null
        try { Expand-FlattenedZip -Zip $zip -Dest $zipDest | Out-Null } catch { $zipFailure = $_.Exception.Message }
        Assert-True ($zipFailure -like 'unsafe ZIP entry:*') ('An unsafe ZIP ' + $kind + ' entry was not rejected by validation')
        Assert-True ((Get-Content -LiteralPath $outsideSentinel -Raw) -ceq 'external sentinel') ('ZIP ' + $kind + ' changed a file outside its stage')
        Assert-True ((Get-Content -LiteralPath (Join-Path $zipDest 'probe.cmd') -Raw) -ceq 'old executable' -and
            (Get-Content -LiteralPath (Join-Path $zipDest 'keep.txt') -Raw) -ceq 'old payload') ('ZIP ' + $kind + ' changed the prior payload')
    }
    # A pinned npm lock must be checked before a CLI is activated.
    $pinDir=Join-Path $TmpDir 'pin-check'
    New-Item -ItemType Directory -Path $pinDir | Out-Null
    $pinTool=[pscustomobject]@{package='rea-agents';package_version='6.8.0';npm_integrity='sha512-expected'}
    Write-Utf8 -Path (Join-Path $pinDir 'package-lock.json') -Text '{"packages":{"":{"name":"root-fixture"},"node_modules/rea-agents":{"version":"6.8.0","integrity":"sha512-wrong"}}}'
    $rejected=$false
    try { Assert-NpmIntegrity -Tool $pinTool -Dest $pinDir } catch { $rejected=$true }
    Assert-True $rejected 'A mismatched npm integrity was accepted'
    Write-Utf8 -Path (Join-Path $pinDir 'package-lock.json') -Text '{"packages":{"":{"name":"root-fixture"},"node_modules/rea-agents":{"version":"6.8.0","integrity":"sha512-expected"}}}'
    Assert-NpmIntegrity -Tool $pinTool -Dest $pinDir
    $extBin=Join-Path $TmpDir 'external-rea'
    New-Item -ItemType Directory -Path $extBin | Out-Null
    Write-Utf8 -Path (Join-Path $extBin 'rea.cmd') -Text "@echo off`r`necho 6.8.0`r`n"
    $oldPath=$env:PATH; $env:PATH=$extBin+';'+$env:PATH
    try {
        $external=Get-ExternalRea ([pscustomobject]@{id='rea';package_version='6.8.0'})
        Assert-True ($external.owned -eq $false -and $external.source -eq 'existing-path') 'Global REA was not kept unowned'
        Assert-True ((Get-Content -LiteralPath (Join-Path $extBin 'rea.cmd') -Raw).Contains('6.8.0')) 'Global REA was modified'
        $env:PATH=$BinDir
        Assert-True ($null -eq (Get-ExternalRea ([pscustomobject]@{id='rea';package_version='6.8.0'}))) 'REA selected its own shim recursively'
    } finally { $env:PATH=$oldPath }
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
