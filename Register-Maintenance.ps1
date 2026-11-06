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
$maintain = Join-Path $Root 'Maintain.ps1'
if (-not (Test-Path -LiteralPath $maintain -PathType Leaf)) { throw "Maintain.ps1 is missing under $Root" }

if ($Remove) {
    if (-not $PSCmdlet.ShouldProcess($TaskName, 'remove scheduled task')) { exit 0 }
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "removed scheduled task: $TaskName"
    } else {
        Write-Host "scheduled task not present: $TaskName"
    }
    exit 0
}
if ($RunNow) {
    if (-not $PSCmdlet.ShouldProcess($maintain, 'run full maintenance now')) { exit 0 }
    & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $maintain -All
    exit $LASTEXITCODE
}
if ($At -notmatch '^\d{1,2}:\d{2}$') { throw 'At must be HH:mm, for example 03:30.' }
$logDir = Join-Path $env:LOCALAPPDATA 'ReverseThis'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir 'maintenance.log'
$argument = '-NoProfile -ExecutionPolicy Bypass -Command "& ''{0}'' -All *>> ''{1}''"' -f $maintain, $log
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argument
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At $At
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew
$description = 'Reverse THIS! weekly cleanup, tool update, and local checks. Owner: ' + $Root
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    $oldOwner = if ($existing.Description -match 'Owner:\s*(.+)$') { $matches[1].Trim() } else { '' }
    if ($oldOwner -and (Get-Normalized $oldOwner) -ne $Root) {
        Write-Host "existing task targets $oldOwner; re-registering replaces it with $Root."
    }
}
if ($PSCmdlet.ShouldProcess($TaskName, 'register weekly maintenance')) {
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description $description -Force | Out-Null
    $registered = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
    Write-Host "registered $($registered.TaskName) weekly at $At (user task; remove with -Remove)"
}
