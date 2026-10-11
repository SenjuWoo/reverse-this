#Requires -Version 5.1
<#
.SYNOPSIS
  Exercise installed tools using generated inputs; no game or proprietary files.
.DESCRIPTION
  Run after installing the eight app/format additions. Samples, configuration,
  logs and results stay under sandbox/work/runtime-smoke in a fresh run folder.
  Apktool rebuilds generated resources, Kaitai checks generated parser syntax,
  and capa statically scans its own Python launcher. No sample is executed.
  Environment is restored.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$installed = Get-Content -LiteralPath (Join-Path $root 'sandbox\installed.json') -Raw | ConvertFrom-Json
foreach ($id in @('asar', 'wasm-tools', 'kaitai', 'jadx', 'lief', 'pyinstxtractor-ng', 'apktool', 'capa')) {
    if (-not $installed.tools.$id) { throw "Missing installed tool: $id. Install the app/format additions first." }
}
$bin = Join-Path $root 'sandbox\bin'
$work = Join-Path $root ('sandbox\work\runtime-smoke\run-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $work | Out-Null
$log = Join-Path $work 'smoke.log'
$results = New-Object System.Collections.ArrayList
$previous = @{}
foreach ($name in @('JAVA_HOME', 'JAVA_TOOL_OPTIONS', 'TEMP', 'TMP', 'PYTHONDONTWRITEBYTECODE', 'JADX_CONFIG_DIR', 'JADX_CACHE_DIR')) {
    $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Run {
    param([string]$Executable, [string[]]$Arguments, [string]$ErrorLog)
    Assert-True (Test-Path -LiteralPath $Executable -PathType Leaf) "Missing executable/shim: $Executable"
    $preference = $ErrorActionPreference
    try {
        # PS5.1 wraps native stderr as errors; the process exit code decides success.
        $ErrorActionPreference = 'Continue'
        $global:LASTEXITCODE = $null
        if ($ErrorLog) { $lines = & $Executable @Arguments 2> $ErrorLog }
        else { $lines = & $Executable @Arguments 2>&1 }
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $preference
    }
    $lines | Out-String | Add-Content -LiteralPath $log
    Assert-True ($null -ne $code -and $code -eq 0) "Native command failed ($code): $Executable $($Arguments -join ' ')"
    return $lines
}
function Check {
    param([string]$Name, [scriptblock]$Action)
    try {
        & $Action
        [void]$results.Add([pscustomobject]@{ tool = $Name; status = 'pass' })
        Write-Host "$Name PASS"
    } catch {
        [void]$results.Add([pscustomobject]@{ tool = $Name; status = 'failed'; error = $_.Exception.Message })
        Write-Host "$Name FAIL: $($_.Exception.Message)"
    }
}

Push-Location $work
try {
    $env:JAVA_TOOL_OPTIONS = '-Duser.home="' + $work + '"'
    $env:TEMP = Join-Path $work 'tmp'
    $env:TMP = $env:TEMP
    $env:PYTHONDONTWRITEBYTECODE = '1'
    $env:JADX_CONFIG_DIR = Join-Path $work 'jadx-config'
    $env:JADX_CACHE_DIR = Join-Path $work 'jadx-cache'
    New-Item -ItemType Directory -Force -Path $env:TEMP | Out-Null
    $javaHome = $installed.java_home
    if (-not $javaHome -or -not (Test-Path -LiteralPath (Join-Path $javaHome 'bin\javac.exe') -PathType Leaf)) {
        $javaHome = $previous['JAVA_HOME']
    }
    if ($javaHome) { $env:JAVA_HOME = $javaHome }
    $python = Join-Path $root 'sandbox\tools\lief\Scripts\python.exe'

    Check 'asar' {
        New-Item -ItemType Directory -Force -Path 'asar-input\nested' | Out-Null
        [IO.File]::WriteAllText((Join-Path $work 'asar-input\hello.txt'), 'ReverseThis owned smoke input')
        [IO.File]::WriteAllBytes((Join-Path $work 'asar-input\nested\bytes.bin'), [byte[]](0,1,2,127,128,255))
        Run (Join-Path $bin 'asar.cmd') @('pack', 'asar-input', 'owned.asar') | Out-Null
        $listing = Run (Join-Path $bin 'asar.cmd') @('list', 'owned.asar')
        Assert-True (($listing -join "`n") -match 'bytes\.bin') 'ASAR listing missed nested input.'
        Run (Join-Path $bin 'asar.cmd') @('extract', 'owned.asar', 'asar-extracted') | Out-Null
        foreach ($file in @(Get-ChildItem -LiteralPath 'asar-input' -Recurse -File)) {
            $relative = $file.FullName.Substring((Join-Path $work 'asar-input').Length + 1)
            Assert-True ((Get-FileHash -LiteralPath $file.FullName).Hash -eq (Get-FileHash -LiteralPath (Join-Path 'asar-extracted' $relative)).Hash) "ASAR byte mismatch: $relative"
        }
    }
    Check 'wasm-tools' {
        [IO.File]::WriteAllText((Join-Path $work 'owned.wat'), '(module (func (export "answer") (result i32) i32.const 42))')
        Run (Join-Path $bin 'wasm-tools.cmd') @('parse', 'owned.wat', '-o', 'owned.wasm') | Out-Null
        Run (Join-Path $bin 'wasm-tools.cmd') @('validate', 'owned.wasm') | Out-Null
        Run (Join-Path $bin 'wasm-tools.cmd') @('print', 'owned.wasm', '-o', 'roundtrip.wat') | Out-Null
        Run (Join-Path $bin 'wasm-tools.cmd') @('parse', 'roundtrip.wat', '-o', 'roundtrip.wasm') | Out-Null
        Run (Join-Path $bin 'wasm-tools.cmd') @('validate', 'roundtrip.wasm') | Out-Null
        Assert-True ((Get-FileHash -LiteralPath 'owned.wasm').Hash -eq (Get-FileHash -LiteralPath 'roundtrip.wasm').Hash) 'Wasm roundtrip bytes differ.'
    }
    Check 'kaitai' {
        $ksy = @'
meta:
  id: smoke_record
  endian: le
seq:
  - id: magic
    contents: [0x52, 0x54]
  - id: value
    type: u4
'@
        [IO.File]::WriteAllText((Join-Path $work 'owned.ksy'), $ksy)
        Run (Join-Path $bin 'kaitai-struct-compiler.cmd') @('--target', 'python', '--outdir', 'kaitai-output', 'owned.ksy') | Out-Null
        $generated = Get-Content -LiteralPath 'kaitai-output\smoke_record.py' -Raw
        Assert-True ($generated -match 'read_u4le' -and $generated -match 'class SmokeRecord') 'Generated parser missed the requested class/field.'
        Run $python @('-B', '-c', "import ast; ast.parse(open('kaitai-output/smoke_record.py', encoding='utf-8').read()); print('generated parser syntax valid')") | Out-Null
    }
    Check 'jadx' {
        Assert-True ([bool]$javaHome) 'JADX smoke needs a JDK in installed.json or JAVA_HOME.'
        [IO.File]::WriteAllText((Join-Path $work 'SmokeMath.java'), 'public final class SmokeMath { public static int add(int a, int b) { return a + b; } public static String marker() { return "ReverseThis owned smoke"; } }')
        Run (Join-Path $javaHome 'bin\javac.exe') @('--release', '8', '-d', 'classes', 'SmokeMath.java') | Out-Null
        Run (Join-Path $bin 'jadx.cmd') @('--no-res', '--output-dir', 'jadx-output', 'classes\SmokeMath.class') | Out-Null
        $files = @(Get-ChildItem -LiteralPath 'jadx-output\sources' -Filter 'SmokeMath.java' -Recurse -File)
        Assert-True ($files.Count -eq 1) 'Expected exactly one decompiled SmokeMath.java.'
        $java = Get-Content -LiteralPath $files[0].FullName -Raw
        Assert-True (-not [string]::IsNullOrEmpty($java) -and $java -match 'class SmokeMath' -and $java -match 'ReverseThis owned smoke' -and $java -match 'return .*\+') 'JADX missed expected own-class semantics.'
    }
    Check 'lief' {
        $source = @'
import json
import sys
import lief
binary = lief.parse(sys.argv[1])
assert isinstance(binary, lief.PE.Binary), 'expected PE image'
assert 'AMD64' in str(binary.header.machine), binary.header.machine
assert len(binary.sections) > 0, 'missing sections'
print(json.dumps({'lief': lief.__version__, 'format': 'PE', 'machine': str(binary.header.machine), 'sections': len(binary.sections), 'imports': len(binary.imports)}))
'@
        [IO.File]::WriteAllText((Join-Path $work 'parse-owned-tool.py'), $source)
        Run $python @('-B', 'parse-owned-tool.py', (Join-Path $root 'sandbox\tools\wasm-tools\wasm-tools.exe')) | Out-Null
    }
    Check 'pyinstxtractor-ng' {
        $information = Run (Join-Path $bin 'pyinstxtractor-ng.cmd') @('--info', (Join-Path $root 'sandbox\tools\pyinstxtractor-ng\pyinstxtractor-ng.exe'))
        Assert-True (($information -join "`n") -match 'CArchive files:\s+[1-9]') 'No populated PyInstaller archive inspection result returned.'
    }
    Check 'apktool' {
        $version = Run (Join-Path $bin 'apktool.cmd') @('--version')
        $expected = [regex]::Escape(($installed.tools.apktool.version -replace '^v', ''))
        Assert-True (($version -join "`n") -match $expected) 'Apktool runtime version differs from its installed record.'
        $help = Run (Join-Path $bin 'apktool.cmd') @('--help')
        Assert-True (($help -join "`n") -match 'apktool d\|decode') 'Apktool decode help missing.'
        New-Item -ItemType Directory -Force -Path 'apk-project\res\values', 'apk-project\assets' | Out-Null
        # Minimal metadata follows Apktool's own decoded-project test fixture schema.
        $metadata = "version: $($installed.tools.apktool.version -replace '^v','')`napkFileName: owned.apk`nusesFramework:`n  ids:`n  - 1`nresourcesInfo:`n  packageId: 127`nversionInfo:`n  versionCode: 1`n  versionName: 1.0`n"
        [IO.File]::WriteAllText((Join-Path $work 'apk-project\apktool.yml'), $metadata)
        [IO.File]::WriteAllText((Join-Path $work 'apk-project\AndroidManifest.xml'), '<manifest package="com.reversethis.smoke" xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="@string/marker"/></manifest>')
        [IO.File]::WriteAllText((Join-Path $work 'apk-project\res\values\strings.xml'), '<resources><string name="marker">ReverseThis owned original</string></resources>')
        [IO.File]::WriteAllBytes((Join-Path $work 'apk-project\assets\bytes.bin'), [byte[]](0,1,127,128,255))
        Run (Join-Path $bin 'apktool.cmd') @('b', 'apk-project', '-p', 'apk-framework', '-o', 'owned.apk') | Out-Null
        Run (Join-Path $bin 'apktool.cmd') @('d', 'owned.apk', '-p', 'apk-framework', '-o', 'apk-decoded') | Out-Null
        $stringsPath = Join-Path $work 'apk-decoded\res\values\strings.xml'
        $strings = Get-Content -LiteralPath $stringsPath -Raw
        Assert-True ($strings -match 'ReverseThis owned original') 'Apktool did not decode the generated resource.'
        [IO.File]::WriteAllText($stringsPath, $strings.Replace('ReverseThis owned original', 'ReverseThis owned modified'))
        Run (Join-Path $bin 'apktool.cmd') @('b', 'apk-decoded', '-p', 'apk-framework', '-o', 'rebuilt.apk') | Out-Null
        Run (Join-Path $bin 'apktool.cmd') @('d', 'rebuilt.apk', '-p', 'apk-framework', '-o', 'apk-rebuilt-decoded') | Out-Null
        Assert-True ((Get-Content -LiteralPath 'apk-rebuilt-decoded\res\values\strings.xml' -Raw) -match 'ReverseThis owned modified') 'Modified APK resource did not survive rebuilding.'
        Assert-True ((Get-Content -LiteralPath 'apk-rebuilt-decoded\AndroidManifest.xml' -Raw) -match 'com\.reversethis\.smoke') 'APK package identity changed.'
        Assert-True ((Get-FileHash -LiteralPath 'apk-project\assets\bytes.bin').Hash -eq (Get-FileHash -LiteralPath 'apk-rebuilt-decoded\assets\bytes.bin').Hash) 'APK asset bytes changed.'
    }
    Check 'capa' {
        $version = Run (Join-Path $bin 'capa.cmd') @('--version')
        $expected = [regex]::Escape(($installed.tools.capa.version -replace '^v', ''))
        Assert-True (($version -join "`n") -match $expected) 'capa runtime version differs from its installed record.'
        $sample = Join-Path $root 'sandbox\tools\capa\Scripts\python.exe'
        $analysis = (Run (Join-Path $bin 'capa.cmd') @('-q', '-j', $sample) -ErrorLog (Join-Path $work 'capa-stderr.log')) -join "`n"
        [IO.File]::WriteAllText((Join-Path $work 'capa-analysis.json'), $analysis)
        $report = $analysis | ConvertFrom-Json
        Assert-True ($report.meta.sample.sha256 -eq (Get-FileHash -LiteralPath $sample -Algorithm SHA256).Hash.ToLowerInvariant()) 'capa analyzed a different sample.'
        Assert-True ($report.meta.version -eq ($installed.tools.capa.version -replace '^v','')) 'capa analysis version differs from its record.'
    }
} finally {
    Pop-Location
    foreach ($name in $previous.Keys) {
        if ($null -eq $previous[$name]) {
            Remove-Item -LiteralPath ('Env:\' + $name) -ErrorAction SilentlyContinue
        } else {
            [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
        }
    }
    [IO.File]::WriteAllText((Join-Path $work 'results.json'), ($results | ConvertTo-Json -Depth 4))
    Write-Host "Evidence: $work"
    Write-Host 'Scope: generated APK resource rebuild; Kaitai compile/syntax; static capa scan of its own Python launcher; no samples executed or APKs installed.'
}
Assert-True ($results.Count -eq 8 -and @($results | Where-Object status -eq 'failed').Count -eq 0) 'Installed-tool smoke failed; inspect results.json and smoke.log.'
