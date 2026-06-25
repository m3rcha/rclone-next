-<p align="center">
  <img src="rclone-next-horizontal.svg" alt="Rclone Next" width="280">
</p>
-
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

The app lives in the menu bar (no Dock icon). Click the menu bar icon to open the quick panel, or use **Open Rclone Next** for the full window.

## Features

- Browse remotes with breadcrumb navigation, listing cache, and a bottom action bar (mount, upload, download, delete)
- Toolbar navigation: up one level and refresh
- Upload, download, delete, rename, public links, open-in-app
- Mount remotes via macFUSE with persistence and auto-remount
- Sync / Copy / Move jobs with dry-run preview
- OAuth and credential-based remote setup
- Dashboard with storage gauges and update checks
- Custom branding: white icons in-app, color icon for About / app bundle

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

### Branding assets

| Path | Use |
|------|-----|
| `color-icon/` | App logo — About, welcome, `.icns` / dock icon |
| `white-icon/` | In-app UI — menu bar, panel headers, dashboard |
| `rclone-next-horizontal.svg` | README / docs wordmark |
| `rclone-next-icon.svg` | Source icon artwork |

`./bundle.sh` copies rasterized PNGs into `Sources/RcloneNext/Resources/` and builds `Packaging/AppIcon.icns` from the color icon set.

### Manual test checklist

1. `./bundle.sh && open RcloneNext.app` — menu bar icon appears, logos load in About
2. Add Remote (⌘N): try a credential backend and an OAuth backend
3. Browse a remote — use bottom bar for file actions; toolbar for up/refresh
4. Mount a remote → appears in Finder; unmount on quit
5. Sync job (⇧⌘S) with dry-run on, then off
6. Settings (⌘,) — verify custom rclone path or auto-detect

## License

Apache 2.0 — see [`LICENSE`](LICENSE).
