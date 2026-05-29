$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $ScriptDir
$Dist = Join-Path $Root "dist"
$Publish = Join-Path $Dist "dotnet-app"
$Payload = Join-Path $Dist "payload-temp"
$Release = Join-Path $Dist "release"
$ScriptInstall = Join-Path $Dist "script-install"
$PayloadZip = Join-Path $Dist "DaysCounter_EXE_Payload.zip"
$Installer = Join-Path $Dist "DaysCounterInstaller.exe"
$CommittedInstaller = Join-Path $Root "installer\phase1-bootstrap\DaysCounterInstaller.exe"
$Compiler = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$Icon = Join-Path $Root "assets\DaysCounter.ico"
$Bootstrap = Join-Path $Root "installer\phase1-bootstrap\InstallerBootstrap.cs"
$Project = Join-Path $Root "src\FiftyFiveDayCounter.App\FiftyFiveDayCounter.App.csproj"

if (-not (Test-Path $Compiler)) {
    throw "C# compiler not found at $Compiler"
}

if (Test-Path $Dist) {
    Remove-Item -LiteralPath $Dist -Recurse -Force
}
New-Item -ItemType Directory -Path $Publish | Out-Null
New-Item -ItemType Directory -Path $Payload | Out-Null
New-Item -ItemType Directory -Path $Release | Out-Null
New-Item -ItemType Directory -Path $ScriptInstall | Out-Null

dotnet restore $Project `
    -r win-x64 `
    --ignore-failed-sources `
    -p:NuGetAudit=false

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

dotnet publish $Project `
    -c Release `
    -r win-x64 `
    --self-contained true `
    --no-restore `
    -p:PublishSingleFile=false `
    -o $Publish

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Copy-Item -Path (Join-Path $Publish "*") -Destination $Payload -Recurse -Force
Copy-Item -Path (Join-Path $Publish "*") -Destination $ScriptInstall -Recurse -Force

$SupportFiles = @(
    @{ Source = "installer\phase1-bootstrap\Install-DaysCounter.ps1"; Destination = "Install-DaysCounter.ps1" },
    @{ Source = "installer\phase1-bootstrap\Install-DaysCounter.cmd"; Destination = "Install-DaysCounter.cmd" },
    @{ Source = "installer\phase1-bootstrap\Uninstall-DaysCounter.ps1"; Destination = "Uninstall-DaysCounter.ps1" },
    @{ Source = "installer\phase1-bootstrap\Uninstall-DaysCounter.cmd"; Destination = "Uninstall-DaysCounter.cmd" },
    @{ Source = "VERSION"; Destination = "VERSION" },
    @{ Source = "README.md"; Destination = "README.md" },
    @{ Source = "docs\INSTALLATION.md"; Destination = "INSTALLATION.md" },
    @{ Source = "docs\SYSTEM_ARCHITECTURE.md"; Destination = "SYSTEM_ARCHITECTURE.md" }
)

foreach ($file in $SupportFiles) {
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
Copy-Item -LiteralPath (Join-Path $Root "installer\phase1-bootstrap\Uninstall-DaysCounter.cmd") -Destination $Release -Force
Copy-Item -LiteralPath (Join-Path $Root "installer\phase1-bootstrap\Uninstall-DaysCounter.ps1") -Destination $Release -Force

$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $Installer
$hash.Hash | Set-Content -LiteralPath (Join-Path $Dist "DaysCounterInstaller.sha256") -Encoding ASCII

Remove-Item -LiteralPath $PayloadZip -Force
Remove-Item -LiteralPath $Payload -Recurse -Force

Write-Host "Release built in $Dist"
Write-Host "Self-contained app: $Publish"
Write-Host "Installer: $Installer"
Write-Host "Checked-in installer refreshed: $CommittedInstaller"
Write-Host "Release folder: $Release"
Write-Host "Script-install fallback folder: $ScriptInstall"
