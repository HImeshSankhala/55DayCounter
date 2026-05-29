$ErrorActionPreference = "Stop"

$SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProductName = "DaysCounter"
$InstallDir = Join-Path $env:LOCALAPPDATA "DaysCounter"
$LegacyInstallDir = Join-Path $env:LOCALAPPDATA "55DayCounter"
$TempLogPath = Join-Path $env:TEMP "DaysCounter-install.log"
$FinalLogPath = Join-Path $InstallDir "install.log"
$TaskNames = @(
    "DaysCounter Alerts",
    "55 Day Counter Alerts",
    "55 Day Counter .NET Alerts",
    "55DayCounterNetAlerts",
    "55DayCounterNetAlertsXml"
)
$ShortcutNames = @(
    "DaysCounter.lnk",
    "Uninstall DaysCounter.lnk",
    "55 Day Counter.lnk",
    "Uninstall 55 Day Counter.lnk",
    "Backup 55 Day Counter Data.lnk"
)
$Warnings = New-Object System.Collections.ArrayList

function Write-InstallLog {
    param([string]$Message)

    $line = "{0} {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $Message
    Add-Content -Path $TempLogPath -Value $line -Encoding UTF8
}

function Add-InstallWarning {
    param([string]$Message)

    [void]$Warnings.Add($Message)
    Write-InstallLog "WARNING: $Message"
}

function Stop-KnownProcesses {
    Write-InstallLog "Stopping known DaysCounter and old 55 Day Counter processes..."

    Get-Process -Name "DaysCounter.App","FiftyFiveDayCounter.App" -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Write-InstallLog "Stopping process: $($_.ProcessName) ($($_.Id))"
            Stop-Process -Id $_.Id -Force -ErrorAction Stop
        }
        catch {
            Add-InstallWarning "Could not stop process $($_.Id). $($_.Exception.Message)"
        }
    }

    try {
        Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe' OR Name = 'pwsh.exe'" -ErrorAction Stop |
            Where-Object {
                $_.CommandLine -and
                ($_.CommandLine -like "*55DayCounter.ps1*" -or $_.CommandLine -like "*Check-55DayNotifications.ps1*")
            } |
            ForEach-Object {
                try {
                    Write-InstallLog "Stopping legacy PowerShell process: $($_.ProcessId)"
                    Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop
                }
                catch {
                    Add-InstallWarning "Could not stop legacy process $($_.ProcessId). $($_.Exception.Message)"
                }
            }
    }
    catch {
        Add-InstallWarning "Could not scan legacy PowerShell processes. $($_.Exception.Message)"
    }
}

function Remove-KnownScheduledTasks {
    foreach ($taskName in $TaskNames) {
        try {
            $serviceType = [type]::GetTypeFromProgID("Schedule.Service")
            if ($null -ne $serviceType) {
                $service = [Activator]::CreateInstance($serviceType)
                $service.Connect()
                $root = $service.GetFolder("\")
                try {
                    $root.DeleteTask($taskName, 0)
                    Write-InstallLog "Scheduled task removed: $taskName"
                    continue
                }
                catch {
                }
            }
        }
        catch {
        }

        try {
            schtasks.exe /Delete /TN $taskName /F | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-InstallLog "Scheduled task removed: $taskName"
            }
        }
        catch {
            Write-InstallLog "Scheduled task not present or could not be removed: $taskName"
        }
    }
}

function Remove-KnownShortcuts {
    $folders = @(
        [Environment]::GetFolderPath("Desktop"),
        [Environment]::GetFolderPath("Programs")
    )

    foreach ($folder in $folders) {
        foreach ($shortcutName in $ShortcutNames) {
            $path = Join-Path $folder $shortcutName
            if (Test-Path -LiteralPath $path) {
                try {
                    Remove-Item -LiteralPath $path -Force
                    Write-InstallLog "Shortcut removed: $path"
                }
                catch {
                    Add-InstallWarning "Could not remove shortcut $path. $($_.Exception.Message)"
                }
            }
        }
    }
}

function Remove-OldInstallFolder {
    foreach ($path in @($InstallDir, $LegacyInstallDir)) {
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }

        try {
            Remove-Item -LiteralPath $path -Recurse -Force
            Write-InstallLog "Old install folder removed: $path"
        }
        catch {
            Add-InstallWarning "Could not fully remove old install folder. $($_.Exception.Message)"
            throw
        }
    }
}

function Copy-NewAppFiles {
    $excluded = @("Install-DaysCounter.ps1", "Install-DaysCounter.cmd")

    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    foreach ($item in Get-ChildItem -LiteralPath $SourceDir -Force) {
        if ($excluded -contains $item.Name) {
            continue
        }

        Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $InstallDir $item.Name) -Recurse -Force
    }

    if (-not (Test-Path -LiteralPath (Join-Path $InstallDir "DaysCounter.App.exe"))) {
        throw "Published app executable was not copied correctly."
    }

    Write-InstallLog "New .NET app files copied to: $InstallDir"
}

function Create-Shortcuts {
    $shell = New-Object -ComObject WScript.Shell
    $exePath = Join-Path $InstallDir "DaysCounter.App.exe"
    $iconPath = Join-Path $InstallDir "DaysCounter.ico"

    $createDesktopShortcut = $true
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $choice = [System.Windows.Forms.MessageBox]::Show(
            "Create a Desktop shortcut for $ProductName?",
            "$ProductName Installer",
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
            $desktopShortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "DaysCounter.lnk"
            $desktopShortcut = $shell.CreateShortcut($desktopShortcutPath)
            $desktopShortcut.TargetPath = $exePath
            $desktopShortcut.WorkingDirectory = $InstallDir
            $desktopShortcut.Description = "Open $ProductName"
            $desktopShortcut.IconLocation = $iconPath
            $desktopShortcut.Save()
            Write-InstallLog "Desktop shortcut created."
        }
        catch {
            Add-InstallWarning "Desktop shortcut could not be created. $($_.Exception.Message)"
        }
    }

    $programsDir = [Environment]::GetFolderPath("Programs")
    try {
        $startMenuShortcutPath = Join-Path $programsDir "DaysCounter.lnk"
        $startMenuShortcut = $shell.CreateShortcut($startMenuShortcutPath)
        $startMenuShortcut.TargetPath = $exePath
        $startMenuShortcut.WorkingDirectory = $InstallDir
        $startMenuShortcut.Description = "Open $ProductName"
        $startMenuShortcut.IconLocation = $iconPath
        $startMenuShortcut.Save()
        Write-InstallLog "Start Menu shortcut created."
    }
    catch {
        Add-InstallWarning "Start Menu shortcut could not be created. $($_.Exception.Message)"
    }

    try {
        $uninstallShortcutPath = Join-Path $programsDir "Uninstall DaysCounter.lnk"
        $uninstallCmd = Join-Path $InstallDir "Uninstall-DaysCounter.cmd"
        $uninstallShortcut = $shell.CreateShortcut($uninstallShortcutPath)
        $uninstallShortcut.TargetPath = $uninstallCmd
        $uninstallShortcut.WorkingDirectory = $InstallDir
        $uninstallShortcut.Description = "Uninstall $ProductName"
        $uninstallShortcut.IconLocation = $iconPath
        $uninstallShortcut.Save()
        Write-InstallLog "Start Menu uninstall shortcut created."
    }
    catch {
        Add-InstallWarning "Uninstall shortcut could not be created. $($_.Exception.Message)"
    }
}

Remove-Item -LiteralPath $TempLogPath -Force -ErrorAction SilentlyContinue
Write-InstallLog "Installing $ProductName .NET final product..."
Write-InstallLog "Source: $SourceDir"
Write-InstallLog "Target: $InstallDir"

Stop-KnownProcesses
Remove-KnownScheduledTasks
Remove-KnownShortcuts
Remove-OldInstallFolder
Copy-NewAppFiles
Create-Shortcuts

Copy-Item -LiteralPath $TempLogPath -Destination $FinalLogPath -Force
Write-InstallLog "Installation complete."
Copy-Item -LiteralPath $TempLogPath -Destination $FinalLogPath -Force

try {
    Add-Type -AssemblyName System.Windows.Forms
    if ($Warnings.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "$ProductName was installed, but there were warnings:`n`n$($Warnings -join "`n`n")`n`nLog: $FinalLogPath",
            "$ProductName Installer",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
    }
    else {
        [System.Windows.Forms.MessageBox]::Show(
            "$ProductName installed successfully.`n`nOld known app files, shortcuts, and scheduled tasks were cleaned first.",
            "$ProductName Installer",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
}
catch {
    if ($Warnings.Count -gt 0) {
        Write-Host "Installed with warnings. See $FinalLogPath"
    }
    else {
        Write-Host "Installed successfully. Log: $FinalLogPath"
    }
}

exit 0
