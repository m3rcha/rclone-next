# Rclone Next

A native **macOS menu-bar app** for managing [rclone](https://rclone.org): browse remotes, transfer files, mount drives, and run sync jobs.

Built with Swift / SwiftUI / AppKit. Requires **macOS 14+** and **Xcode** (SwiftUI macros need the full Xcode SDK).

## Requirements

| Need | Notes |
|------|-------|
| **Xcode** | `swift build` fails with CLT-only installs |
| **rclone** | Auto-discovered, or set a custom path in **Settings…** (⌘,) |
| **macFUSE** | Required for mounting remotes as Finder volumes |

## Quick start

```bash
swift build
swift run

# Package a local .app bundle
./bundle.sh
open RcloneNext.app
```

The app lives in the menu bar (no Dock icon). Click the drive glyph to open the quick panel, or use **Open Rclone Next** for the full window.

## Features

- Browse remotes with breadcrumb navigation and listing cache
- Upload, download, delete, rename, public links, open-in-app
- Mount remotes via macFUSE with persistence and auto-remount
- Sync / Copy / Move jobs with dry-run preview
- OAuth and credential-based remote setup
- Dashboard with storage gauges and update checks

## Settings

Open **Settings…** from the menu bar (⌘,) to override the rclone binary path. Leave the field empty to auto-detect Homebrew and `/usr/bin` installs.

## Development

```bash
swift build
swift test
./bundle.sh   # optional: build RcloneNext.app
```

### Architecture

- **RcloneBackend** — thin async wrapper around the rclone CLI
- **AppModel / BrowserModel / MountManager** — `@MainActor @Observable` state
- **SwiftUI** — menu-bar panel + main window; sheets for add-remote, jobs, settings

Full Xcode is required (SwiftUI macros). The app shells out to a user-installed `rclone` binary and uses macFUSE for mounts.

### Manual test checklist

1. `./bundle.sh && open RcloneNext.app` — menu-bar icon appears, no Dock icon
2. Add Remote (⌘N): try a credential backend and an OAuth backend
3. Browse a remote, upload/download, refresh listing
4. Mount a remote → appears in Finder; unmount on quit
5. Sync job (⇧⌘S) with dry-run on, then off
6. Settings (⌘,) — verify custom rclone path or auto-detect

## License

Apache 2.0 — see [`LICENSE`](LICENSE).
