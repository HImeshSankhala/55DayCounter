@echo off
cd /d "%~dp0.."
dotnet run --project "src\FiftyFiveDayCounter.App\FiftyFiveDayCounter.App.csproj" -c Release
