# 55 Day Counter Installation Guide

## One-Step EXE Install From Pendrive

1. Copy `55DayCounterInstaller.exe` to a pendrive.
2. Take the pendrive to the hotel company PC.
3. Double-click `55DayCounterInstaller.exe`.
4. When asked, choose whether to create a Desktop shortcut.
5. Wait for the success message.
6. Open the app from the Desktop shortcut if you created one, or from the Start Menu shortcut named `55 Day Counter`.

The installer does not need internet access.

## What The Installer Does

The installer:

- Extracts the required app files automatically.
- Copies the app to `%LOCALAPPDATA%\55DayCounter`.
- Asks whether to create a Desktop shortcut.
- Creates a Start Menu shortcut.
- Creates an empty `guests.json` database if one does not already exist.
- Preserves an existing `guests.json` database during upgrades.
- Installs a Windows Scheduled Task named `55 Day Counter Alerts`.
- Schedules notification checks every day at 9:00 AM.

The installer intentionally does not copy `guests.json` from the pendrive. This prevents test data from being installed on the hotel PC.

## Normal Daily Use

1. Open `55 Day Counter` from the Desktop shortcut.
2. Add guests with guest name, room number, and check-in date.
3. Review the automatically calculated 55th day.
4. Use `Today's List` to preview guests checking out today or in the next 5 days.
5. Use `Download Excel` from the preview if a report is needed.
6. Use `Complete` or `Cancel Cycle` when a guest cycle ends.

## Notification Setup

The one-step installer already installs the notification task.

Notification behavior:

- If the app is open, it checks notifications when opened and every hour.
- If the app is closed, the scheduled task checks once per day at 9:00 AM.
- Notifications are shown for guests due today or due within the next 5 days.
- The app sends at most one automatic reminder per guest per day during the warning window.

## Verify Notifications

1. Add a test guest.
2. Set the check-in date to 50 days ago.
3. Save the guest.
4. Confirm the guest shows `Due Soon`.
5. Click `Check Alerts`.
6. Confirm a Windows notification appears.

To verify the daily scheduled task:

1. Open Windows Task Scheduler.
2. Find `55 Day Counter Alerts`.
3. Right-click it.
4. Click `Run`.
5. Confirm a notification appears if any guest is due today or within the next 5 days.

## If Notifications Do Not Show

Check:

- Windows notifications are enabled.
- Focus Assist / Do Not Disturb is off.
- The guest is due today or within the next 5 days.
- The guest is not completed or canceled.
- Task Scheduler contains `55 Day Counter Alerts`.
- The scheduled task points to `%LOCALAPPDATA%\55DayCounter\Check-55DayNotifications.ps1`.

## Upgrade Later

1. Copy the updated `55DayCounterInstaller.exe` to a pendrive.
2. On the hotel PC, double-click `55DayCounterInstaller.exe` again.
3. The app files will be replaced.
4. Existing guest data will be preserved.

## Script Install Fallback

If the `.exe` is blocked by company policy, use the script installer instead:

1. Copy the full app folder to the hotel PC.
2. Double-click `Install-55DayCounter.cmd`.
3. Follow the same shortcut prompt.
