$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$NotifierPath = Join-Path $AppDir "Check-55DayNotifications.ps1"
$TaskName = "55 Day Counter Alerts"

if (-not (Test-Path $NotifierPath)) {
    Write-Host "Cannot find Check-55DayNotifications.ps1"
    exit 1
}

$actionArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$NotifierPath`""
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $actionArgs
$trigger = New-ScheduledTaskTrigger -Daily -At 9:00AM
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel LeastPrivilege

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Checks 55 Day Counter guests and shows due-soon Windows notifications." -Force | Out-Null

Write-Host "Daily 55 Day Counter notifications are scheduled for 9:00 AM."
