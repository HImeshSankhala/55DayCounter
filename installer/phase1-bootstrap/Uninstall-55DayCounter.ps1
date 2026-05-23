$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $env:LOCALAPPDATA "55DayCounter"
$TaskName = "55 Day Counter Alerts"
$LogPath = Join-Path $env:TEMP "55DayCounter-uninstall.log"
Set-Location $env:TEMP

function Write-UninstallLog {
    param([string]$Message)

    $line = "{0} {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $Message
    try {
        Add-Content -Path $LogPath -Value $line -Encoding UTF8
    }
    catch {
        Write-Host "Could not write uninstall log: $($_.Exception.Message)"
    }
}

try {
    Add-Type -AssemblyName System.Windows.Forms
}
catch {
}

$appMutex = New-Object System.Threading.Mutex($false, "55DayCounterAppRunning")
$appLock = $false
try {
    $appLock = $appMutex.WaitOne(0)
    if (-not $appLock) {
        if ("System.Windows.Forms.MessageBox" -as [type]) {
            [System.Windows.Forms.MessageBox]::Show(
                "55 Day Counter is currently open. Close the app, then run the uninstaller again.",
                "55 Day Counter Uninstaller",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
        }
        else {
            Write-Host "55 Day Counter is currently open. Close it and run this again."
        }
        exit 1
    }
}
finally {
    if ($appLock) { $appMutex.ReleaseMutex() }
    $appMutex.Dispose()
}

$backupData = $false
if ("System.Windows.Forms.MessageBox" -as [type]) {
    $choice = [System.Windows.Forms.MessageBox]::Show(
        "Do you want to back up the guest database before uninstalling?",
        "55 Day Counter Uninstaller",
        [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    if ($choice -eq [System.Windows.Forms.DialogResult]::Cancel) {
        Write-UninstallLog "Uninstall canceled by user."
        exit 0
    }
    $backupData = ($choice -eq [System.Windows.Forms.DialogResult]::Yes)
}
else {
    $reply = Read-Host "Back up guest database before uninstalling? Y/N"
    $backupData = ($reply -match "^[Yy]")
}

Write-UninstallLog "Uninstalling 55 Day Counter..."

try {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
    Write-UninstallLog "Scheduled task removed: $TaskName"
}
catch {
    Write-UninstallLog "Scheduled task was not removed or did not exist: $($_.Exception.Message)"
}

$desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "55 Day Counter.lnk"
$startMenuShortcut = Join-Path ([Environment]::GetFolderPath("Programs")) "55 Day Counter.lnk"
$startMenuUninstallShortcut = Join-Path ([Environment]::GetFolderPath("Programs")) "Uninstall 55 Day Counter.lnk"
$startMenuBackupShortcut = Join-Path ([Environment]::GetFolderPath("Programs")) "Backup 55 Day Counter Data.lnk"

foreach ($shortcut in @($desktopShortcut, $startMenuShortcut, $startMenuUninstallShortcut, $startMenuBackupShortcut)) {
    try {
        if (Test-Path $shortcut) {
            Remove-Item -LiteralPath $shortcut -Force
            Write-UninstallLog "Shortcut removed: $shortcut"
        }
    }
    catch {
        Write-UninstallLog "Shortcut could not be removed: $shortcut - $($_.Exception.Message)"
    }
}

$dataPath = Join-Path $InstallDir "guests.json"
if ($backupData -and (Test-Path $dataPath)) {
    $backupDir = Join-Path ([Environment]::GetFolderPath("MyDocuments")) ("55DayCounter_Backup_{0}" -f (Get-Date).ToString("yyyyMMdd_HHmmss"))
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Copy-Item -LiteralPath $dataPath -Destination (Join-Path $backupDir "guests.json") -Force
    Write-UninstallLog "Guest database backed up to: $backupDir"
}

try {
    if (Test-Path $InstallDir) {
        Remove-Item -LiteralPath $InstallDir -Recurse -Force
        Write-UninstallLog "Installed app folder removed: $InstallDir"
    }
}
catch {
    Write-UninstallLog "Installed app folder could not be fully removed: $($_.Exception.Message)"
    throw
}

if ("System.Windows.Forms.MessageBox" -as [type]) {
    [System.Windows.Forms.MessageBox]::Show(
        "55 Day Counter was uninstalled.`n`nLog: $LogPath",
        "55 Day Counter Uninstaller",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}
else {
    Write-Host "55 Day Counter was uninstalled. Log: $LogPath"
}
