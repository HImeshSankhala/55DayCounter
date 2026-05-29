$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $env:LOCALAPPDATA "55DayCounter"
$LogPath = Join-Path $env:TEMP "55DayCounter-uninstall.log"
$TaskNames = @(
    "55 Day Counter Alerts",
    "55 Day Counter .NET Alerts",
    "55DayCounterNetAlerts",
    "55DayCounterNetAlertsXml"
)
$ShortcutNames = @(
    "55 Day Counter.lnk",
    "Uninstall 55 Day Counter.lnk",
    "Backup 55 Day Counter Data.lnk"
)

function Write-UninstallLog {
    param([string]$Message)

    $line = "{0} {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $Message
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

function Stop-KnownProcesses {
    Get-Process -Name "FiftyFiveDayCounter.App" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-UninstallLog "Stopping process: $($_.ProcessName) ($($_.Id))"
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }

    try {
        Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe' OR Name = 'pwsh.exe'" -ErrorAction Stop |
            Where-Object {
                $_.CommandLine -and
                ($_.CommandLine -like "*55DayCounter.ps1*" -or $_.CommandLine -like "*Check-55DayNotifications.ps1*")
            } |
            ForEach-Object {
                Write-UninstallLog "Stopping legacy PowerShell process: $($_.ProcessId)"
                Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            }
    }
    catch {
        Write-UninstallLog "Legacy PowerShell process scan skipped: $($_.Exception.Message)"
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
                    Write-UninstallLog "Scheduled task removed: $taskName"
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
                Write-UninstallLog "Scheduled task removed: $taskName"
            }
        }
        catch {
            Write-UninstallLog "Scheduled task not present or could not be removed: $taskName"
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
                Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
                Write-UninstallLog "Shortcut removed: $path"
            }
        }
    }
}

Set-Location $env:TEMP
Remove-Item -LiteralPath $LogPath -Force -ErrorAction SilentlyContinue
Write-UninstallLog "Uninstalling 55 Day Counter..."

try {
    Add-Type -AssemblyName System.Windows.Forms
    $choice = [System.Windows.Forms.MessageBox]::Show(
        "This will remove 55 Day Counter, local guest data, shortcuts, and scheduled notifications. Continue?",
        "55 Day Counter Uninstaller",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    if ($choice -ne [System.Windows.Forms.DialogResult]::Yes) {
        Write-UninstallLog "Uninstall canceled by user."
        exit 0
    }
}
catch {
    $reply = Read-Host "Remove 55 Day Counter and local data? Y/N"
    if ($reply -notmatch "^[Yy]") {
        Write-UninstallLog "Uninstall canceled by user."
        exit 0
    }
}

Stop-KnownProcesses
Remove-KnownScheduledTasks
Remove-KnownShortcuts

if (Test-Path -LiteralPath $InstallDir) {
    Remove-Item -LiteralPath $InstallDir -Recurse -Force
    Write-UninstallLog "Installed app folder removed: $InstallDir"
}

try {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "55 Day Counter was uninstalled.`n`nLog: $LogPath",
        "55 Day Counter Uninstaller",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}
catch {
    Write-Host "55 Day Counter was uninstalled. Log: $LogPath"
}
