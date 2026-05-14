$ErrorActionPreference = "Stop"

$SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallDir = Join-Path $env:LOCALAPPDATA "55DayCounter"
$TaskName = "55 Day Counter Alerts"
$Warnings = New-Object System.Collections.ArrayList
$LogPath = Join-Path $InstallDir "install.log"

function Write-InstallLog {
    param([string]$Message)

    $line = "{0} {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $Message
    try {
        Add-Content -Path $LogPath -Value $line -Encoding UTF8
    }
    catch {
        Write-Host "Could not write install log: $($_.Exception.Message)"
    }
}

function Add-InstallWarning {
    param([string]$Message)

    [void]$Warnings.Add($Message)
    Write-InstallLog "WARNING: $Message"
}

$RequiredFiles = @(
    "55DayCounter.ps1",
    "Start-55DayCounter.cmd",
    "Check-55DayNotifications.ps1",
    "Install-DailyNotifications.ps1",
    "Install-DailyNotifications.cmd",
    "55DayCounter.ico",
    "README.md",
    "INSTALLATION.md",
    "SYSTEM_ARCHITECTURE.md"
)

foreach ($file in $RequiredFiles) {
    $sourcePath = Join-Path $SourceDir $file
    if (-not (Test-Path $sourcePath)) {
        throw "Missing required file: $file"
    }
}

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir | Out-Null
}

Write-InstallLog "Installing 55 Day Counter..."
Write-InstallLog "Source: $SourceDir"
Write-InstallLog "Target: $InstallDir"

foreach ($file in $RequiredFiles) {
    Copy-Item -Path (Join-Path $SourceDir $file) -Destination (Join-Path $InstallDir $file) -Force
}

$dataPath = Join-Path $InstallDir "guests.json"
if (-not (Test-Path $dataPath)) {
    "[]" | Set-Content -Path $dataPath -Encoding UTF8
    Write-InstallLog "Created a new empty guest database."
}
else {
    Write-InstallLog "Existing guest database preserved."
}

$startCmd = Join-Path $InstallDir "Start-55DayCounter.cmd"
$notifierPath = Join-Path $InstallDir "Check-55DayNotifications.ps1"
$iconPath = Join-Path $InstallDir "55DayCounter.ico"

$shell = New-Object -ComObject WScript.Shell

$createDesktopShortcut = $true
try {
    Add-Type -AssemblyName System.Windows.Forms
    $choice = [System.Windows.Forms.MessageBox]::Show(
        "Create a Desktop shortcut for 55 Day Counter?",
        "55 Day Counter Installer",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    $createDesktopShortcut = ($choice -eq [System.Windows.Forms.DialogResult]::Yes)
}
catch {
    $reply = Read-Host "Create a Desktop shortcut? Y/N"
    $createDesktopShortcut = ($reply -match "^[Yy]")
}

if ($createDesktopShortcut) {
    try {
        $desktopShortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "55 Day Counter.lnk"
        $desktopShortcut = $shell.CreateShortcut($desktopShortcutPath)
        $desktopShortcut.TargetPath = $startCmd
        $desktopShortcut.WorkingDirectory = $InstallDir
        $desktopShortcut.Description = "Open 55 Day Counter"
        $desktopShortcut.IconLocation = $iconPath
        $desktopShortcut.Save()
        Write-InstallLog "Desktop shortcut created."
    }
    catch {
        Add-InstallWarning "Desktop shortcut could not be created. $($_.Exception.Message)"
    }
}

try {
    $programsDir = [Environment]::GetFolderPath("Programs")
    $startMenuShortcutPath = Join-Path $programsDir "55 Day Counter.lnk"
    $startMenuShortcut = $shell.CreateShortcut($startMenuShortcutPath)
    $startMenuShortcut.TargetPath = $startCmd
    $startMenuShortcut.WorkingDirectory = $InstallDir
    $startMenuShortcut.Description = "Open 55 Day Counter"
    $startMenuShortcut.IconLocation = $iconPath
    $startMenuShortcut.Save()
    Write-InstallLog "Start Menu shortcut created."
}
catch {
    Add-InstallWarning "Start Menu shortcut could not be created. $($_.Exception.Message)"
}

try {
    $actionArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$notifierPath`""
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $actionArgs
    $trigger = New-ScheduledTaskTrigger -Daily -At 9:00AM
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel LeastPrivilege
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Checks 55 Day Counter guests and shows due-soon Windows notifications." -Force | Out-Null
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
    Write-InstallLog "Daily notification task installed: $($task.TaskName)"
}
catch {
    Add-InstallWarning "Daily notifications could not be installed automatically. The app is installed and usable, but Windows may have blocked scheduled-task creation. Error: $($_.Exception.Message)"
}

Write-InstallLog "Installation complete."
Write-InstallLog "Installed app folder: $InstallDir"
Write-InstallLog "Shortcuts:"
if ($createDesktopShortcut) {
    Write-InstallLog "  Desktop: requested"
}
else {
    Write-InstallLog "  Desktop: skipped by user"
}
Write-InstallLog "  Start Menu: requested"
Write-InstallLog "Daily notification task: $TaskName at 9:00 AM"

try {
    Add-Type -AssemblyName System.Windows.Forms
    if ($Warnings.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "55 Day Counter was installed, but there were warnings:`n`n$($Warnings -join "`n`n")`n`nLog: $LogPath",
            "55 Day Counter Installer",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
    }
    else {
        [System.Windows.Forms.MessageBox]::Show(
            "55 Day Counter installed successfully.",
            "55 Day Counter Installer",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
}
catch {
    if ($Warnings.Count -gt 0) {
        Write-Host "Installed with warnings. See $LogPath"
    }
    else {
        Write-Host "Installed successfully."
    }
}

exit 0
