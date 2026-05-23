# 55 Day Counter Roadmap

This roadmap initiates the first two delivery phases for 55 Day Counter.

## Phase 1: Stabilized Hotel Pilot

### Goal

Keep the current PowerShell WinForms app usable for real hotel testing while improving data safety, supportability, installation, backup, and release discipline.

### Deliverables

- Offline Windows app installed from a pendrive.
- Versioned app display using `VERSION`.
- One-step installer and clean uninstaller.
- Backup helper for `guests.json`.
- Stable Start Menu shortcuts for launch, backup, and uninstall.
- Release build script that writes generated artifacts only to `dist/`.
- Documentation for install, notification verification, backup, uninstall, and release checks.

### Scope

1. Core workflow
   - Add, edit, complete, and cancel cycles.
   - Calculate 55th day as check-in + 54 days.
   - Recalculate status from the current local date.
   - Warn on duplicate active room during add and edit.

2. Operational workflow
   - Search and status filter.
   - Today's List includes overdue, due today, and next 5 days.
   - Exclude completed and canceled cycles from operational alerts and Today's List.
   - Export all records to CSV.
   - Export Today's List to Excel-readable `.xls`.

3. Notifications
   - Test Alert button.
   - Manual Check Alerts.
   - Daily scheduled task at 9:00 AM when allowed by Windows policy.
   - Automatic reminders at most once per guest per day.

4. Data safety
   - Preserve `guests.json` during upgrade.
   - Protect unreadable `guests.json` from overwrite.
   - Add manual backup helper.
   - Uninstaller offers database backup before removal.

5. Release hygiene
   - Generated packages ignored by Git.
   - Releases built with `Build-Release.ps1`.
   - No test guest data in release payloads.

### Acceptance Criteria

- App launches on a non-admin Windows user profile.
- Installer can install offline from a pendrive.
- Reinstall preserves existing guest records.
- Uninstaller removes scheduled task and shortcuts.
- Staff can back up guest data.
- Today's List correctly includes overdue, due today, and next 5 days.
- Notifications can be manually tested.
- Docs match shipped behavior.

## Phase 2: Proper Windows Product

### Goal

Create a compiled .NET Windows app that can eventually replace the PowerShell pilot with stronger maintainability, testability, storage, packaging, and notification identity.

### Current Status

The .NET SDK is installed and the first side-by-side compiled WinForms preview has been created under `src/`.

### Recommended Stack

- C# / .NET 8
- WinForms first, because it maps cleanly from the current app
- Core business-rules project
- JSON compatibility during migration
- SQLite as the target durable storage
- Separate notification executable for Task Scheduler
- WiX, MSIX, or Inno Setup for production installer
- Signed installer and executable for company PCs

### Proposed Structure

```text
src/
  FiftyFiveDayCounter.App/
  FiftyFiveDayCounter.Core/
  FiftyFiveDayCounter.Storage/
  FiftyFiveDayCounter.Notifier/
  FiftyFiveDayCounter.Installer/
tests/
  FiftyFiveDayCounter.Core.Tests/
  FiftyFiveDayCounter.Storage.Tests/
docs/
  release-checklists/
legacy/
  PowerShell pilot files, after migration starts
```

### Migration Sequence

1. Install .NET SDK.
2. Create `FiftyFiveDayCounter.Core`. Started.
3. Port pure rules:
   - 55th-day calculation
   - status calculation
   - Today’s List selection
   - notification eligibility
   - duplicate room validation
4. Add automated tests for the rules. Started.
5. Add JSON reader/writer compatible with current `guests.json`. Started.
6. Build a minimal WinForms preview app side by side. Started.
7. Add SQLite repository and JSON-to-SQLite migration.
8. Replace PowerShell notification checker with .NET notifier.
9. Replace bootstrap installer with proper installer.
10. Pilot .NET preview before switching production shortcuts.

### Acceptance Criteria

- Automated rule tests pass.
- Existing `guests.json` imports correctly.
- Add/edit/complete/cancel parity with PowerShell app.
- Today’s List parity with overdue inclusion.
- Notifications work after reboot and login.
- Installer supports install, upgrade, repair, and uninstall.
- Existing guest data survives upgrade.
- App appears in Windows Apps & Features.

## Sequencing

1. Finish Phase 1 stabilization before replacing the UI.
2. Keep PowerShell pilot as the stable production path.
3. Start Phase 2 side by side after .NET SDK is available.
4. Move business rules first, UI second, installer last.
5. Do not change production data format until backup and migration tests exist.
