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
$maintain = Join-Path $Root 'Maintain.ps1'
if (-not (Test-Path -LiteralPath $maintain -PathType Leaf)) { throw "Maintain.ps1 is missing under $Root" }

if ($Remove) {
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
    & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $maintain -All
    exit $LASTEXITCODE
}
if ($At -notmatch '^\d{1,2}:\d{2}$') { throw 'At must be HH:mm, for example 03:30.' }

$argument = '-NoProfile -ExecutionPolicy Bypass -File "' + $maintain + '" -All'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argument
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At $At
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew
$description = 'Reverse THIS! weekly cleanup, tool update, and local checks. Owner: ' + $Root
if ($PSCmdlet.ShouldProcess($TaskName, 'register weekly maintenance')) {
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description $description -Force | Out-Null
    $registered = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
    Write-Host "registered $($registered.TaskName) weekly at $At (user task; remove with -Remove)"
}
