# DaysCounter System Architecture

## Purpose

DaysCounter is a local Windows desktop app for tracking hotel guest cycle deadlines. Staff enter guest name, room number, and check-in date. The hotel sets the cycle length globally:

```text
checkout date = check-in date + (cycle days - 1)
notification date = checkout date - 5 days
```

The default cycle length is 55 days, but it can be changed to values such as 14 or 30 days from the main screen.

## Product Architecture

The final product is **.NET only**.

```text
src/FiftyFiveDayCounter.App      WinForms UI, notifications, scheduling
src/FiftyFiveDayCounter.Core     date/status/business rules
src/FiftyFiveDayCounter.Storage  JSON storage
installer/phase1-bootstrap       bootstrap installer and uninstall scripts
legacy/powershell-pilot          archived pilot only, not shipped
scripts/Build-Release.ps1        self-contained release builder
dist/                            generated output, ignored by Git
```

The release build publishes a self-contained `win-x64` app so hotel PCs do not need the .NET runtime installed separately.

## Installed Runtime

Install location:

```text
%LOCALAPPDATA%\DaysCounter
```

Main executable:

```text
DaysCounter.App.exe
```

Installer behavior:

- removes known current and old 55 Day Counter folders, shortcuts, scheduled tasks, and processes
- removes old local guest data for a fresh install
- copies the self-contained .NET app
- creates Desktop and Start Menu shortcuts
- installs an uninstaller shortcut
- logs to `%LOCALAPPDATA%\DaysCounter\install.log`

Uninstaller behavior:

- removes installed app files and local data
- removes known DaysCounter and 55 Day Counter shortcuts
- removes current and legacy scheduled task names
- stops known .NET and legacy PowerShell app processes
- logs to `%TEMP%\DaysCounter-uninstall.log`

## Component Flow

```mermaid
flowchart TD
    User["Front Desk User"] --> App["DaysCounter.App.exe"]
    App --> Settings["settings.json"]
    App --> Data["guests.json"]
    App --> CSV["CSV Export"]
    App --> Today["Today's List"]
    App --> Notify["Windows Notifications"]
    App --> Schedule["Schedule Button"]
    Schedule --> Task["Task Scheduler: DaysCounter Alerts"]
    Task --> Check["DaysCounter.App.exe --check-notifications"]
    Check --> Settings
    Check --> Data
    Check --> Notify
    Notify --> Click["Notification Click"]
    Click --> TodayOpen["DaysCounter.App.exe --today-list"]
```

## Data Storage

Guest data is stored locally as JSON:

```text
%LOCALAPPDATA%\DaysCounter\guests.json
```

Settings are stored in:

```text
%LOCALAPPDATA%\DaysCounter\settings.json
```

Guest records contain:

```text
Id
GuestName
RoomNumber
CheckInDate
CheckOutDate
NotifyDate
Status
Notes
```

Dates are local calendar dates. Complete and Cancel permanently remove a guest record after confirmation.

## Cycle Length

`settings.json` stores `CycleLengthDays`. The app clamps it between 1 and 365 days.

When the hotel changes the cycle length, active guest checkout and notification dates are recalculated from each guest's check-in date. Check-in always counts as day 1.

## Notification Architecture

The app has one scheduled notification task:

```text
DaysCounter Alerts
```

The task action is:

```text
%LOCALAPPDATA%\DaysCounter\DaysCounter.App.exe --check-notifications
```

The installed app owns task creation through the `Schedule` button. The installer only removes old tasks during cleanup and does not create a default notification schedule.

The first app launch sends a test notification and can open Windows Notification settings. Windows notification permission cannot be silently granted by the app.

Scheduled check troubleshooting log:

```text
%LOCALAPPDATA%\DaysCounter\notification-check.log
```

## Release Outputs

`scripts/Build-Release.ps1` creates:

```text
dist\dotnet-app\DaysCounter.App.exe
dist\DaysCounterInstaller.exe
dist\DaysCounterInstaller.sha256
dist\release\
dist\script-install\
```

The installer executable is also copied to:

```text
installer\phase1-bootstrap\DaysCounterInstaller.exe
```

## Operational Notes

- No internet connection is required after the release is built.
- The app installs per-user under `%LOCALAPPDATA%` to avoid administrator rights.
- Company PCs may still block unsigned executables, Windows notifications, or scheduled tasks by policy.
- The legacy PowerShell pilot is retained only for reference and rollback analysis; it is not part of the final release payload.
