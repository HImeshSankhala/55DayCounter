$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $ScriptDir
$Dist = Join-Path $Root "dist"
$Payload = Join-Path $Dist "payload-temp"
$Release = Join-Path $Dist "release"
$ScriptInstall = Join-Path $Dist "script-install"
$PayloadZip = Join-Path $Dist "55DayCounter_EXE_Payload.zip"
$Installer = Join-Path $Dist "55DayCounterInstaller.exe"
$CommittedInstaller = Join-Path $Root "installer\phase1-bootstrap\55DayCounterInstaller.exe"
$Compiler = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$Icon = Join-Path $Root "assets\55DayCounter.ico"
$Bootstrap = Join-Path $Root "installer\phase1-bootstrap\InstallerBootstrap.cs"

$Files = @(
    @{ Source = "legacy\powershell-pilot\55DayCounter.ps1"; Destination = "55DayCounter.ps1" },
    @{ Source = "legacy\powershell-pilot\Start-55DayCounter.cmd"; Destination = "Start-55DayCounter.cmd" },
    @{ Source = "legacy\powershell-pilot\Check-55DayNotifications.ps1"; Destination = "Check-55DayNotifications.ps1" },
    @{ Source = "installer\phase1-bootstrap\Install-DailyNotifications.ps1"; Destination = "Install-DailyNotifications.ps1" },
    @{ Source = "installer\phase1-bootstrap\Install-DailyNotifications.cmd"; Destination = "Install-DailyNotifications.cmd" },
    @{ Source = "installer\phase1-bootstrap\Install-55DayCounter.ps1"; Destination = "Install-55DayCounter.ps1" },
    @{ Source = "installer\phase1-bootstrap\Install-55DayCounter.cmd"; Destination = "Install-55DayCounter.cmd" },
    @{ Source = "installer\phase1-bootstrap\Uninstall-55DayCounter.ps1"; Destination = "Uninstall-55DayCounter.ps1" },
    @{ Source = "installer\phase1-bootstrap\Uninstall-55DayCounter.cmd"; Destination = "Uninstall-55DayCounter.cmd" },
    @{ Source = "installer\phase1-bootstrap\Backup-55DayCounter.ps1"; Destination = "Backup-55DayCounter.ps1" },
    @{ Source = "installer\phase1-bootstrap\Backup-55DayCounter.cmd"; Destination = "Backup-55DayCounter.cmd" },
    @{ Source = "assets\55DayCounter.ico"; Destination = "55DayCounter.ico" },
    @{ Source = "VERSION"; Destination = "VERSION" },
    @{ Source = "README.md"; Destination = "README.md" },
    @{ Source = "docs\INSTALLATION.md"; Destination = "INSTALLATION.md" },
    @{ Source = "docs\SYSTEM_ARCHITECTURE.md"; Destination = "SYSTEM_ARCHITECTURE.md" }
)

if (-not (Test-Path $Compiler)) {
    throw "C# compiler not found at $Compiler"
}

if (Test-Path $Dist) {
    Remove-Item -LiteralPath $Dist -Recurse -Force
}
New-Item -ItemType Directory -Path $Payload | Out-Null
New-Item -ItemType Directory -Path $Release | Out-Null
New-Item -ItemType Directory -Path $ScriptInstall | Out-Null

foreach ($file in $Files) {
    $source = Join-Path $Root $file.Source
    if (-not (Test-Path $source)) {
        throw "Missing required release file: $($file.Source)"
    }
    Copy-Item -LiteralPath $source -Destination (Join-Path $Payload $file.Destination) -Force
    Copy-Item -LiteralPath $source -Destination (Join-Path $ScriptInstall $file.Destination) -Force
}

Compress-Archive -Path (Join-Path $Payload "*") -DestinationPath $PayloadZip -Force

& $Compiler `
    /nologo `
    /target:winexe `
    /out:$Installer `
    /win32icon:$Icon `
    /resource:"$PayloadZip,AppPayload" `
    /reference:System.Windows.Forms.dll `
    /reference:System.Drawing.dll `
    /reference:System.IO.Compression.dll `
    /reference:System.IO.Compression.FileSystem.dll `
    $Bootstrap

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Copy-Item -LiteralPath $Installer -Destination $Release -Force
Copy-Item -LiteralPath $Installer -Destination $CommittedInstaller -Force
Copy-Item -LiteralPath (Join-Path $Root "README.md") -Destination $Release -Force
Copy-Item -LiteralPath (Join-Path $Root "docs\INSTALLATION.md") -Destination (Join-Path $Release "INSTALLATION.md") -Force
Copy-Item -LiteralPath (Join-Path $Root "installer\phase1-bootstrap\Uninstall-55DayCounter.cmd") -Destination $Release -Force
Copy-Item -LiteralPath (Join-Path $Root "installer\phase1-bootstrap\Uninstall-55DayCounter.ps1") -Destination $Release -Force

$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $Installer
$hash.Hash | Set-Content -LiteralPath (Join-Path $Dist "55DayCounterInstaller.sha256") -Encoding ASCII

Remove-Item -LiteralPath $PayloadZip -Force
Remove-Item -LiteralPath $Payload -Recurse -Force

Write-Host "Release built in $Dist"
Write-Host "Installer: $Installer"
Write-Host "Checked-in installer refreshed: $CommittedInstaller"
Write-Host "Release folder: $Release"
Write-Host "Script-install fallback folder: $ScriptInstall"
