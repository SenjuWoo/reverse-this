# Offline safety tests for the optional scheduled maintenance wrapper.
# Uses -WhatIf only; it never creates, changes, or removes a real scheduled task.
$ErrorActionPreference = 'Stop'
$hostExe = (Get-Process -Id $PID).Path
$root = Join-Path ([IO.Path]::GetTempPath()) ('rt-register-' + [guid]::NewGuid().ToString('N') + " Operator's Kit & ü")
$register = Join-Path $PSScriptRoot '../Register-Maintenance.ps1'
New-Item -ItemType Directory -Force -Path $root | Out-Null
try {
    # A fake child would create ran.txt if -WhatIf failed to block execution.
    Set-Content -LiteralPath (Join-Path $root 'Maintain.ps1') -Encoding ASCII -Value @'
param([switch]$All)
Set-Content -LiteralPath (Join-Path $PSScriptRoot 'ran.txt') -Value 'ran'
exit 0
'@

    $global:LASTEXITCODE = 0
    $output = & $hostExe -NoProfile -ExecutionPolicy Bypass -File $register -Root $root -RunNow -WhatIf 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "-RunNow -WhatIf failed: $output" }
    if (Test-Path -LiteralPath (Join-Path $root 'ran.txt')) { throw '-RunNow -WhatIf executed Maintain.ps1' }
    if ($output -notmatch 'What if:') { throw '-RunNow -WhatIf did not report a preview' }

    $taskName = 'ReverseThis-Maintenance-Test-' + [guid]::NewGuid().ToString('N')
    $global:LASTEXITCODE = 0
    $removeOutput = & $hostExe -NoProfile -ExecutionPolicy Bypass -File $register -Remove -TaskName $taskName -WhatIf 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "-Remove -WhatIf failed: $removeOutput" }
    if ($removeOutput -match 'removed scheduled task') { throw '-Remove -WhatIf falsely reported removal' }
    if ($removeOutput -notmatch 'What if:') { throw '-Remove -WhatIf did not report a preview' }

    $registerOutput = & $hostExe -NoProfile -ExecutionPolicy Bypass -File $register -Root $root -TaskName $taskName -WhatIf 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "-register -WhatIf failed: $registerOutput" }
    if ($registerOutput -notmatch 'What if:') { throw '-register -WhatIf did not report a preview' }
    if ($registerOutput -match 'registered ReverseThis-Maintenance') { throw '-register -WhatIf falsely reported registration' }

    $global:LASTEXITCODE = 0
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $badTime = & $hostExe -NoProfile -ExecutionPolicy Bypass -File $register -Root $root -At '25:00' -WhatIf 2>&1 | Out-String
    $ErrorActionPreference = $oldPreference
    if ($LASTEXITCODE -eq 0) { throw 'invalid -At was accepted' }

    $bareRoot = Join-Path ([IO.Path]::GetTempPath()) ('rt-register-bare-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $bareRoot | Out-Null
    try {
        $global:LASTEXITCODE = 0
        $bareRemove = & $hostExe -NoProfile -ExecutionPolicy Bypass -File $register -Root $bareRoot -Remove -TaskName $taskName -WhatIf 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw "-Remove without Maintain.ps1 failed: $bareRemove" }
    } finally {
        Remove-Item -LiteralPath $bareRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Output 'scheduled maintenance preview checks ok'
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
