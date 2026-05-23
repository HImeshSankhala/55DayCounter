@echo off
cd /d "%~dp0.."
dotnet build FiftyFiveDayCounter.slnx -c Release
if errorlevel 1 exit /b %errorlevel%
dotnet run --project "tests\FiftyFiveDayCounter.Core.Tests\FiftyFiveDayCounter.Core.Tests.csproj" -c Release --no-build
