# Expense

Minimal expense tracker. Multiple boards (one per period). Themes + styles. CSV export. Categories.

Built with Flutter 3.24.5. Android only. APKs built via GitHub Actions.

## Features

- **Boards** — multiple boards, one per period (week, day, month, etc.)
- **Entries** — label on the left, amount on the right, black line + total at the bottom
- **Rename / delete** — long-press a board; rename from the detail screen too
- **6 themes** — Classic White, Midnight, Pastel, Forest, Sunset, Slate
- **3 styles** — Ruled (subtle dividers), Boxed (cards), Minimal (clean)
- **Swipe to delete** an entry + undo snackbar
- **Quick-add** FAB with numeric keyboard + category dropdown
- **Category totals** — proportional bar at the bottom of each board
- **CSV export** via system share sheet

## Build

CI builds APKs on every push to `main`. Artifacts (`app-debug-apk`, `app-release-apks`) under the workflow run.

To build locally (Android SDK required):

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

## Storage

Hive boxes on disk in app documents directory. Survives app close; cleared on uninstall.

## Stack

Flutter 3.24.5 · provider · hive_flutter · intl · uuid · share_plus · flutter_launcher_icons
