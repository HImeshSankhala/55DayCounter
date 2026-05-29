# 55 Day Counter Installation Guide

## One-Step EXE Install From Pendrive

1. Build a release with:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-Release.ps1
   ```

2. Copy `dist\release\55DayCounterInstaller.exe` to a pendrive.
3. Take the pendrive to the hotel company PC.
4. Double-click `55DayCounterInstaller.exe`.
5. Choose whether to create a Desktop shortcut.
6. Open the app from the Desktop shortcut or Start Menu shortcut named `55 Day Counter`.

The installer does not need internet access because the app is published self-contained for `win-x64`.

## What The Installer Does

The installer:

- Stops known old `55 Day Counter` app processes.
- Stops old PowerShell checker processes whose command line contains `55DayCounter.ps1` or `Check-55DayNotifications.ps1`.
- Removes known scheduled tasks:
  - `55 Day Counter Alerts`
  - `55 Day Counter .NET Alerts`
  - `55DayCounterNetAlerts`
  - `55DayCounterNetAlertsXml`
- Removes known Desktop and Start Menu shortcuts.
- Removes `%LOCALAPPDATA%\55DayCounter`, including old guest data.
- Installs the self-contained .NET app to `%LOCALAPPDATA%\55DayCounter`.
- Creates app and uninstall shortcuts.
- Writes installer details to `%LOCALAPPDATA%\55DayCounter\install.log`.

This is intentionally a fresh install. Old `guests.json` data is not preserved.

## Normal Daily Use

1. Open `55 Day Counter`.
2. Add guests with guest name, room number, and check-in date.
3. Review the automatically calculated 55th day.
4. Sort by room if needed.
5. Use `Today's List` to preview overdue guests plus guests checking out today or in the next 5 days.
6. Use `Export CSV` to save the active guest list in the current visible table order.
7. Use `Complete` or `Cancel Cycle` when a guest cycle ends. The row is permanently removed after confirmation.

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
55 Day Counter Alerts
```

It runs:

```text
%LOCALAPPDATA%\55DayCounter\FiftyFiveDayCounter.App.exe --check-notifications
```

Notification troubleshooting log:

```text
%LOCALAPPDATA%\55DayCounter\notification-check.log
```

## Verify Notifications

Manual alert test:

1. Add a test guest.
2. Set the check-in date to 50 days ago.
3. Save the guest.
4. Confirm the guest shows `Due Soon`.
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
- Task Scheduler contains `55 Day Counter Alerts`.
- The scheduled task action points to `FiftyFiveDayCounter.App.exe --check-notifications`.
- `notification-check.log` shows the scheduled check started.

## Uninstall

1. Open the Start Menu.
2. Click `Uninstall 55 Day Counter`.
3. Confirm removal.

The uninstaller removes:

- installed app folder and local guest data
- Desktop and Start Menu shortcuts
- scheduled task `55 Day Counter Alerts`
- known legacy task names
- known running .NET or legacy PowerShell app processes

Uninstall log:

```text
%TEMP%\55DayCounter-uninstall.log
```

If the Start Menu shortcut is missing, run:

```text
%LOCALAPPDATA%\55DayCounter\Uninstall-55DayCounter.cmd
```

## Script Install Fallback

If the `.exe` bootstrap installer is blocked by company policy:

1. Copy the generated `dist\script-install` folder to the hotel PC.
2. Double-click `Install-55DayCounter.cmd`.
3. Follow the shortcut prompt.
