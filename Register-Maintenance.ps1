# Register or remove a user-scoped weekly maintenance task for this kit.
# It never enables a service, changes another owner, or runs without the user's request.
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Root,
    [switch]$Remove,
    [string]$At = '03:30',
    [string]$TaskName = 'ReverseThis-Maintenance',
    [switch]$RunNow
)

$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = Split-Path -Parent $MyInvocation.MyCommand.Path }
$Root = [IO.Path]::GetFullPath($Root).TrimEnd('\')
function Get-Normalized([string]$Path) {
    if (-not $Path) { return '' }
    return [IO.Path]::GetFullPath($Path).TrimEnd('\')
}
function Get-TaskOwner($task) {
    if (-not $task -or -not $task.Description) { return '' }
    if ($task.Description -match 'Owner:\s*(.+)$') { return $matches[1].Trim() }
    return ''
}
function Get-CanonicalPath([string]$Path) {
    if (-not $Path) { return '' }
    try { return [IO.Path]::GetFullPath($Path).TrimEnd('\') } catch { return '' }
}
function Get-ReverseThisTaskInfo($task) {
    if (-not $task) { return $null }
    if ([string]$task.Description -notmatch '^Reverse THIS! (?:weekly cleanup|maintenance)') { return $null }
    $actions = @($task.Actions)
    if ($actions.Count -ne 1) { return $null }
    $action = $actions[0]
    if (-not $action) { return $null }
    if ([IO.Path]::GetFileName([string]$action.Execute).ToLowerInvariant() -notin @('powershell.exe', 'pwsh.exe')) { return $null }
    $owner = Get-CanonicalPath (Get-TaskOwner $task)
    if (-not $owner) { return $null }
    $arguments = [string]$action.Arguments
    $script = $null
    $kind = $null
    if ($arguments -match '(?i)^\s*(?:-NoProfile\s+|-ExecutionPolicy\s+Bypass\s+|-NonInteractive\s+)*-EncodedCommand\s+([A-Za-z0-9+/=]+)\s*$') {
        try { $decoded = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($matches[1])) }
        catch { return $null }
        if ($decoded -notmatch "^\s*&\s*'((?:[^']|'')+)'\s+-All\s+\*>>\s*'((?:[^']|'')+)'\s*$") { return $null }
        $script = $matches[1].Replace("''", "'")
        $kind = 'encoded'
    } elseif ($arguments -match '(?i)^\s*(?:-NoProfile\s+|-ExecutionPolicy\s+Bypass\s+|-NonInteractive\s+)*-File\s+(?:"([^"]+)"|''([^'']+)''|(\S+))\s+-All\s*$') {
        $script = @($matches[1], $matches[2], $matches[3]) | Where-Object { $_ } | Select-Object -First 1
        $kind = 'legacy'
    } else {
        return $null
    }
    $scriptPath = Get-CanonicalPath $script
    if (-not $scriptPath -or [IO.Path]::GetFileName($scriptPath) -ne 'Maintain.ps1') { return $null }
    if (-not [string]::Equals((Get-CanonicalPath (Split-Path -Parent $scriptPath)), $owner, [StringComparison]::OrdinalIgnoreCase)) { return $null }
    return [pscustomobject]@{ Owner = $owner; Script = $scriptPath; Kind = $kind }
}
function Test-ReverseThisTask($task, [string]$ExpectedRoot = '') {
    $info = Get-ReverseThisTaskInfo $task
    if (-not $info) { return $false }
    if ($ExpectedRoot -and -not [string]::Equals($info.Owner, (Get-CanonicalPath $ExpectedRoot), [StringComparison]::OrdinalIgnoreCase)) { return $false }
    return $true
}
$maintain = Join-Path $Root 'Maintain.ps1'

if ($Remove) {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        if (-not (Test-ReverseThisTask $task $Root)) { throw "scheduled task '$TaskName' is not owned by this checkout ($Root); refusing to remove it. Re-register from the recorded owner or remove it explicitly in Task Scheduler." }
        if (-not $PSCmdlet.ShouldProcess($TaskName, 'remove scheduled task')) { exit 0 }
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "removed scheduled task: $TaskName"
    } else {
        if (-not $PSCmdlet.ShouldProcess($TaskName, 'remove scheduled task')) { Write-Host "scheduled task not present: $TaskName"; exit 0 }
        Write-Host "scheduled task not present: $TaskName"
    }
    exit 0
}
if (-not (Test-Path -LiteralPath $maintain -PathType Leaf)) { throw "Maintain.ps1 is missing under $Root" }
if ($RunNow) {
    if (-not $PSCmdlet.ShouldProcess($maintain, 'run full maintenance now')) { exit 0 }
    & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $maintain -All
    exit $LASTEXITCODE
}
try { [void][datetime]::ParseExact($At, 'HH:mm', [Globalization.CultureInfo]::InvariantCulture) }
catch { throw 'At must be a real HH:mm time, for example 03:30.' }
$logDir = Join-Path $env:LOCALAPPDATA 'ReverseThis'
$log = Join-Path $logDir 'maintenance.log'
$escapedMaintain = $maintain.Replace("'", "''")
$escapedLog = $log.Replace("'", "''")
$command = "& '$escapedMaintain' -All *>> '$escapedLog'"
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
$argument = '-NoProfile -ExecutionPolicy Bypass -EncodedCommand ' + $encoded
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argument
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At $At
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew
$description = 'Reverse THIS! maintenance; Owner: ' + $Root
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    if (-not (Test-ReverseThisTask $existing)) {
        throw "scheduled task '$TaskName' exists but is not owned by Reverse THIS!; refusing to replace it. Choose another -TaskName or remove it with its owner."
    }
    $oldOwner = Get-TaskOwner $existing
    if (-not $oldOwner) { throw "scheduled task '$TaskName' has no recognizable owner; refusing to replace it." }
    if ((Get-Normalized $oldOwner) -ne $Root -and (Test-Path -LiteralPath $oldOwner -PathType Container)) {
        throw "scheduled task '$TaskName' belongs to another existing checkout at $oldOwner; refusing to replace it."
    }
    if ((Get-Normalized $oldOwner) -ne $Root) {
        Write-Host "existing Reverse THIS! task targets missing owner $oldOwner; re-registering replaces it with $Root."
    }
}
if ($PSCmdlet.ShouldProcess($TaskName, 'register weekly maintenance')) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description $description -Force | Out-Null
    $registered = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
    Write-Host "registered $($registered.TaskName) weekly at $At (user task; remove with -Remove)"
}
