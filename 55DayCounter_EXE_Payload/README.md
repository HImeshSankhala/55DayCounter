# 55 Day Counter

A small Windows desktop app for tracking guest 55-day cycles.

## Run

Double-click `Start-55DayCounter.cmd`.

## Install On A Hotel PC

For a one-step install from a pendrive, double-click `55DayCounterInstaller.exe`.

The installer copies the app to `%LOCALAPPDATA%\55DayCounter`, asks whether to create a Desktop shortcut, creates a Start Menu shortcut, preserves existing guest data during upgrades, and installs daily 9:00 AM notification checks.

See `INSTALLATION.md` for full installation and notification verification steps.

## What it does

- Stores guest name, room number, check-in date, notes, and cycle status.
- Calculates the 55th day automatically. Check-in counts as day 1, so the 55th day is check-in + 54 days.
- Shows the notification date, which is 5 days before the 55th day.
- Lets you add, edit, complete, and cancel cycles.
- Lets you search, filter by status, and export records to CSV.
- `Today's List` previews guests checking out today or in the next 5 days, then saves that list as an Excel-readable `.xls` file.
- Uses color status:
  - Blue: active
  - Yellow: within 5 days
  - Orange: due today
  - Red: overdue
  - Green: completed
  - Gray: canceled
- Saves records in `guests.json` next to the app.

## Notifications

The app shows Windows tray balloon alerts for guests who are within 5 days of the 55th day while the app is running. Use `Check Alerts` to manually check due-soon guests.

For alerts even when the main app is closed, double-click `Install-DailyNotifications.cmd`. It creates a Windows scheduled task that checks once per day at 9:00 AM.
