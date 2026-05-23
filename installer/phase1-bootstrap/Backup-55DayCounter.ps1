$ErrorActionPreference = "Stop"

$InstallDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataPath = Join-Path $InstallDir "guests.json"
$BackupRoot = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "55DayCounter_Backups"

if (-not (Test-Path $DataPath)) {
    Write-Host "No guests.json file was found in $InstallDir"
    exit 1
}

if (-not (Test-Path $BackupRoot)) {
    New-Item -ItemType Directory -Path $BackupRoot | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = Join-Path $BackupRoot "guests-$timestamp.json"
Copy-Item -LiteralPath $DataPath -Destination $backupPath -Force

Write-Host "Guest database backup created:"
Write-Host $backupPath
