# Phase 1 Release Checklist

## Current App

- Add guest with valid name, room, check-in date.
- Required-field validation keeps dialog open.
- Edit guest and confirm 55th day recalculates.
- Duplicate active room warns on add and edit.
- Complete cycle removes it from alerts.
- Cancel cycle removes it from alerts.
- Search filters by guest, room, and notes.
- Status filter works for all statuses.

## Date Rules

- Check-in counts as day 1.
- 55th day is check-in + 54 days.
- Notify date is 55th day - 5 days.
- Overdue appears after the 55th day.
- Today's List includes overdue, due today, and next 5 days.

## Notifications

- `Test Alert` displays a Windows notification.
- `Check Alerts` displays due/overdue summary.
- Scheduled task exists: `55 Day Counter Alerts`.
- Scheduled task points to installed `Check-55DayNotifications.ps1`.
- App still works if scheduled task is blocked.

## Installer

- Installer preserves existing `guests.json`.
- Desktop shortcut prompt works.
- Start Menu shortcut is created.
- Uninstall shortcut is created.
- Uninstaller removes scheduled task and shortcuts.
- Uninstaller offers database backup.

## Data Safety

- `Backup-55DayCounter.cmd` creates a backup in Documents.
- App does not overwrite unreadable `guests.json`.
- Generated ZIP/payload folders are not committed.
