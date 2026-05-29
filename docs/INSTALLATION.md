# DaysCounter Installation Guide

## One-Step EXE Install From Pendrive

1. Build a release with:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-Release.ps1
   ```

2. Copy `dist\release\DaysCounterInstaller.exe` to a pendrive.
3. Take the pendrive to the hotel company PC.
4. Double-click `DaysCounterInstaller.exe`.
5. Choose whether to create a Desktop shortcut.
6. Open the app from the Desktop shortcut or Start Menu shortcut named `DaysCounter`.

The installer does not need internet access because the app is published self-contained for `win-x64`.

## What The Installer Does

The installer:

- Stops known current and old app processes.
- Stops old PowerShell checker processes whose command line contains `55DayCounter.ps1` or `Check-55DayNotifications.ps1`.
- Removes known scheduled tasks:
  - `DaysCounter Alerts`
  - `55 Day Counter Alerts`
  - `55 Day Counter .NET Alerts`
  - `55DayCounterNetAlerts`
  - `55DayCounterNetAlertsXml`
- Removes known Desktop and Start Menu shortcuts.
- Removes `%LOCALAPPDATA%\DaysCounter` and `%LOCALAPPDATA%\55DayCounter`, including old guest data.
- Installs the self-contained .NET app to `%LOCALAPPDATA%\DaysCounter`.
- Creates app and uninstall shortcuts.
- Writes installer details to `%LOCALAPPDATA%\DaysCounter\install.log`.

This is intentionally a fresh install. Old `guests.json` data is not preserved.

## Normal Daily Use

1. Open `DaysCounter`.
2. Set `Cycle days` for the hotel, for example 14, 30, or 55.
3. Add guests with guest name, room number, and check-in date.
4. Review the automatically calculated checkout date.
5. Sort by room if needed.
6. Use `Today's List` to preview overdue guests plus guests checking out today or in the next 5 days.
7. Use `Export CSV` to save the active guest list in the current visible table order.
8. Use `Complete` or `Cancel Cycle` when a guest cycle ends. The row is permanently removed after confirmation.

## Notification Setup

The app owns notification scheduling. The installer only cleans old scheduled tasks; it does not create a default new one.

1. Open the app.
2. On first launch, allow the test notification flow.
3. If the test notification does not appear, let the app open Windows Notification settings and allow notifications.
4. Click `Schedule`.
5. Enable daily scheduled notification checks.
6. Choose the daily notification time.
7. Save.

The scheduled task name is:

```text
DaysCounter Alerts
```

It runs:

```text
%LOCALAPPDATA%\DaysCounter\DaysCounter.App.exe --check-notifications
```

Notification troubleshooting log:

```text
%LOCALAPPDATA%\DaysCounter\notification-check.log
```

## Verify Notifications

Manual alert test:

1. Add a test guest.
2. Set the check-in date so checkout is within the next 5 days.
3. Save the guest.
4. Confirm the guest shows `Due Soon`, `Due Today`, or `Overdue`.
5. Click `Check Alerts`.
6. Confirm a Windows notification appears.

Scheduled alert test:

1. Click `Schedule`.
2. Set the daily time 2-3 minutes ahead.
3. Save and close the app.
4. Wait for the notification.
5. Click the notification and confirm the app opens with Today's List.
6. If no notification appears, check `notification-check.log`.

## If Notifications Do Not Show

Check:

- Windows notifications are enabled.
- Do Not Disturb / Focus Assist is off.
- The guest is overdue, due today, or due within the next 5 days.
- Task Scheduler contains `DaysCounter Alerts`.
- The scheduled task action points to `DaysCounter.App.exe --check-notifications`.
- `notification-check.log` shows the scheduled check started.

## Uninstall

1. Open the Start Menu.
2. Click `Uninstall DaysCounter`.
3. Confirm removal.

The uninstaller removes:

- installed app folder and local guest data
- Desktop and Start Menu shortcuts
- scheduled task `DaysCounter Alerts`
- known legacy task names
- known running .NET or legacy PowerShell app processes

Uninstall log:

```text
%TEMP%\DaysCounter-uninstall.log
```

If the Start Menu shortcut is missing, run:

```text
%LOCALAPPDATA%\DaysCounter\Uninstall-DaysCounter.cmd
```

## Script Install Fallback

If the `.exe` bootstrap installer is blocked by company policy:

1. Copy the generated `dist\script-install` folder to the hotel PC.
2. Double-click `Install-DaysCounter.cmd`.
3. Follow the shortcut prompt.
