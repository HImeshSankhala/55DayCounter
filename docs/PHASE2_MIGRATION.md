# Phase 2 Migration Plan

## Goal

Move 55 Day Counter from a PowerShell WinForms utility into a proper Windows product with a compiled app, durable storage, managed installer, and reliable notification identity.

## Current Status

The .NET SDK is now available and the first side-by-side .NET preview has been started.

Current implementation:

```text
src/FiftyFiveDayCounter.Core
src/FiftyFiveDayCounter.Storage
src/FiftyFiveDayCounter.App
tests/FiftyFiveDayCounter.Core.Tests
```

## Target Stack

- UI: WinForms first, to reduce migration risk from the PowerShell WinForms pilot
- Language: C#
- Storage: JSON compatibility first, SQLite later
- Installer: MSIX, WiX, or Inno Setup
- Notifications: Windows toast notifications with app identity
- Data migration: import existing `guests.json` into SQLite

## Proposed Project Structure

```text
src/
  FiftyFiveDayCounter.App/
  FiftyFiveDayCounter.Core/
  FiftyFiveDayCounter.Storage/
tests/
  FiftyFiveDayCounter.Core.Tests/
installer/
  wix-or-inno/
docs/
  release-checklists/
```

## Migration Steps

1. Keep the current PowerShell app as the pilot/stable utility.
2. Extract business rules into C# core classes:
   - 55th-day calculation
   - status calculation
   - due/overdue list selection
3. Add automated tests around the business rules. Started.
4. Build a compatible JSON storage layer. Started.
5. Build WinForms preview UI matching the current workflow. Started.
6. Build SQLite schema and migration from `guests.json`.
7. Add real Windows toast notifications.
8. Add signed installer and uninstall flow.
9. Pilot side by side with the current utility.
10. Migrate production data.

## Release Gate For Phase 2

Phase 2 should not replace the current app until:

- JSON migration into SQLite is tested.
- Add/edit/complete/cancel workflows pass.
- Today's List includes overdue, due today, and next 5 days.
- Notifications work after reboot and user login.
- Installer appears in Windows Apps & Features.
- Uninstall removes scheduled tasks and app files.
- Existing guest data survives upgrade.
