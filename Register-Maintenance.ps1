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
function Test-ReverseThisTask($task) {
    if (-not $task) { return $false }
    if ([string]$task.Description -notmatch '^Reverse THIS! (?:weekly cleanup|maintenance)') { return $false }
    $action = @($task.Actions)[0]
    if (-not $action) { return $false }
    $exe = [IO.Path]::GetFileName([string]$action.Execute).ToLowerInvariant()
    if ($exe -notin @('powershell.exe', 'pwsh.exe')) { return $false }
    return [string]$action.Arguments -match 'Maintain\.ps1|EncodedCommand'
}
$maintain = Join-Path $Root 'Maintain.ps1'

if ($Remove) {
    if (-not $PSCmdlet.ShouldProcess($TaskName, 'remove scheduled task')) { exit 0 }
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        if (-not (Test-ReverseThisTask $task)) { throw "scheduled task '$TaskName' is not owned by Reverse THIS!; refusing to remove it." }
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "removed scheduled task: $TaskName"
    } else {
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
    if ($oldOwner -and (Get-Normalized $oldOwner) -ne $Root) {
        Write-Host "existing Reverse THIS! task targets $oldOwner; re-registering replaces it with $Root."
    }
}
if ($PSCmdlet.ShouldProcess($TaskName, 'register weekly maintenance')) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description $description -Force | Out-Null
    $registered = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
    Write-Host "registered $($registered.TaskName) weekly at $At (user task; remove with -Remove)"
}
