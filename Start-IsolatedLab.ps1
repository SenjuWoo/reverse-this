#Requires -Version 5.1
<#
.SYNOPSIS
  Open the kit in Windows Sandbox with host tools and optional inputs read-only.
.DESCRIPTION
  -Plan prints the configuration without creating files or launching anything.
  Only sandbox/work/isolated is writable from the guest. No sample runs at logon.
#>
[CmdletBinding()]
param(
    [switch]$Plan,
    [string]$InputFolder
)

$ErrorActionPreference = 'Stop'
$sandbox = Join-Path $PSScriptRoot 'sandbox'
$output = Join-Path $sandbox 'work\isolated'
$config = Join-Path $sandbox 'work\isolated-lab.wsb'
$mappings = @(
    @{ Host = (Join-Path $sandbox 'tools'); Guest = 'C:\ReverseThis\sandbox\tools'; ReadOnly = 'true' },
    @{ Host = (Join-Path $sandbox 'bin'); Guest = 'C:\ReverseThis\sandbox\bin'; ReadOnly = 'true' },
    @{ Host = $output; Guest = 'C:\ReverseThis\sandbox\work\isolated'; ReadOnly = 'false' }
)
if ($InputFolder) {
    $inputItem = Get-Item -LiteralPath $InputFolder
    if (-not $inputItem.PSIsContainer) { throw 'InputFolder must be a directory.' }
    $mappings += @{ Host = $inputItem.FullName; Guest = 'C:\ReverseThis\input'; ReadOnly = 'true' }
}

$settings = New-Object System.Xml.XmlWriterSettings
$settings.Indent = $true
$settings.OmitXmlDeclaration = $true
$text = New-Object System.Text.StringBuilder
$writer = [System.Xml.XmlWriter]::Create($text, $settings)
try {
    $writer.WriteStartElement('Configuration')
    foreach ($name in @('Networking', 'ClipboardRedirection', 'AudioInput', 'VideoInput', 'PrinterRedirection', 'vGPU')) {
        $writer.WriteElementString($name, 'Disable')
    }
    $writer.WriteElementString('ProtectedClient', 'Enable')
    $writer.WriteStartElement('MappedFolders')
    foreach ($mapping in $mappings) {
        $writer.WriteStartElement('MappedFolder')
        $writer.WriteElementString('HostFolder', $mapping.Host)
        $writer.WriteElementString('SandboxFolder', $mapping.Guest)
        $writer.WriteElementString('ReadOnly', $mapping.ReadOnly)
        $writer.WriteEndElement()
    }
    $writer.WriteEndElement()
    $writer.WriteEndElement()
} finally {
    $writer.Dispose()
}
$xml = $text.ToString()
if ($Plan) { return $xml }

$launcher = Join-Path $env:WINDIR 'System32\WindowsSandbox.exe'
if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) {
    throw 'Windows Sandbox is unavailable. It requires a supported Windows edition (Pro, Enterprise or Education) and the Windows Sandbox feature. -Plan works without it.'
}
foreach ($mapping in @($mappings | Where-Object { $_.ReadOnly -eq 'true' })) {
    if (-not (Test-Path -LiteralPath $mapping.Host -PathType Container)) {
        throw "Missing mapped folder: $($mapping.Host). Install the kit first."
    }
}
# A writable junction must not redirect guest output outside the kit's work folder.
foreach ($folder in @($sandbox, (Join-Path $sandbox 'work'), $output, $config)) {
    if ((Test-Path -LiteralPath $folder) -and ((Get-Item -LiteralPath $folder -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Writable output path contains a link: $folder"
    }
}
New-Item -ItemType Directory -Force -Path $output | Out-Null
[IO.File]::WriteAllText($config, $xml, (New-Object System.Text.UTF8Encoding $false))
Write-Host "Guest output persists in: $output"
Start-Process -FilePath $launcher -ArgumentList ('"{0}"' -f $config)
