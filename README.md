<p align="center">
  <img src="rclone-next-horizontal.svg" alt="Rclone Next" width="340">
</p>

<p align="center">
  <strong>A native macOS menu bar app for managing <a href="https://rclone.org">rclone</a></strong>
</p>

<p align="center">
  <a href="https://github.com/m3rcha/rclone-next/releases/latest"><img src="https://img.shields.io/github/v/release/m3rcha/rclone-next?label=release&sort=semver" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/m3rcha/rclone-next" alt="License"></a>
  <a href="https://github.com/m3rcha/rclone-next/actions/workflows/ci.yml"><img src="https://github.com/m3rcha/rclone-next/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-blue?logo=apple&logoColor=white" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5.10-orange?logo=swift&logoColor=white" alt="Swift">
</p>

<p align="center">
  <a href="https://m3rcha.github.io/rclone-next/">Website</a> ·
  <a href="https://github.com/m3rcha/rclone-next/releases/latest">Download</a> ·
  <a href="https://github.com/m3rcha/rclone-next/issues">Report Bug</a> ·
  <a href="https://github.com/m3rcha/rclone-next/issues">Request Feature</a>
</p>

---

Rclone Next wraps your **existing** `rclone` install — it does not replace it. Browse remotes, mount drives in Finder, transfer files, and run sync jobs from a native SwiftUI menu bar app instead of the terminal.

> **Note:** Not affiliated with the [rclone](https://rclone.org) project.

## Table of Contents

- [Features](#features)
- [Download](#download)
- [Requirements](#requirements)
- [Usage](#usage)
- [Build from Source](#build-from-source)
- [Development](#development)
- [Architecture](#architecture)
- [Links](#links)
- [License](#license)

## Features

- **Menu bar app** — quick panel + full manager window (no Dock icon)
- **Browse remotes** — breadcrumbs, listing cache, upload / download / delete / rename
- **Mount in Finder** — macFUSE mounts with persistence and auto-remount on launch
- **Sync jobs** — Copy, Sync, Move with dry-run preview
- **Add remotes** — OAuth and credential-based setup through rclone's config flow
- **Dashboard** — storage gauges, version info, and update checks for the app and rclone
- **Settings** — custom rclone binary path with auto-detect for Homebrew and `/usr/bin`

## Download

**[Latest release →](https://github.com/m3rcha/rclone-next/releases/latest)**

1. Download `RcloneNext.app.zip` from GitHub Releases
2. Unzip and move **Rclone Next** to Applications
3. Open the app — look for the icon in the menu bar (top right)
4. If macOS blocks the app: right-click → **Open** the first time

You still need [rclone](https://rclone.org/install/) and [macFUSE](https://macfuse.io/) installed separately.

## Requirements

| Need | Notes |
|------|-------|
| **macOS 14+** | Sonoma or later |
| **rclone** | Auto-discovered, or set a custom path in **Settings…** (⌘,) |
| **macFUSE** | Required for mounting remotes as Finder volumes |
| **Xcode** | Only for building from source (SwiftUI macros need the full SDK) |

## Usage

The app lives in the **menu bar** — click the icon for the quick panel (mounts, transfers, shortcuts).

| Action | How |
|--------|-----|
| Full window | **Open Rclone Next** in the panel, or open from the window menu |
| Add remote | ⌘N or **Add** in the panel |
| Sync / Copy / Move | ⇧⌘S or **Sync** in the panel |
| Settings | ⌘, |
| About & updates | Dashboard → **Software** section or toolbar **About** |

Browse a remote from the sidebar, use the **bottom action bar** for file operations and the **toolbar** for up / refresh.

## Build from Source

```bash
git clone https://github.com/m3rcha/rclone-next.git
cd rclone-next

swift build
swift run

# Package a local .app bundle
./bundle.sh
open RcloneNext.app
```

`swift build` fails with Command Line Tools only — install **full Xcode** first.

## Development

```bash
swift build
swift test
./bundle.sh   # optional: build RcloneNext.app
```

### Manual test checklist

1. `./bundle.sh && open RcloneNext.app` — menu bar icon appears, logos load in About
2. Add Remote (⌘N): try a credential backend and an OAuth backend
3. Browse a remote — bottom bar for file actions; toolbar for up / refresh
4. Mount a remote → appears in Finder; unmount on quit
5. Sync job (⇧⌘S) with dry-run on, then off
6. Settings (⌘,) — verify custom rclone path or auto-detect

### Branding assets

| Path | Use |
|------|-----|
| `color-icon/` | App logo — About, welcome, `.icns` |
| `white-icon/` | In-app UI — menu bar, panel, dashboard |
| `rclone-next-horizontal.svg` | README / docs wordmark |
| `rclone-next-icon.svg` | Source icon artwork |

`./bundle.sh` copies PNGs into `Sources/RcloneNext/Resources/` and builds `Packaging/AppIcon.icns`.

## Architecture

```
MenuBarExtra (panel)  +  Window (ContentView)
         │                        │
         └──── AppModel ──────────┘
                    │
      ┌─────────────┼─────────────┐
      │             │             │
 RcloneBackend  MountManager  BrowserModel
      │                           │
  rclone CLI                 FileListView
```

- **RcloneBackend** — thin async wrapper around the rclone CLI
- **AppModel / BrowserModel / MountManager** — `@MainActor @Observable` state
- **SwiftUI + AppKit** — menu bar panel, main window, sheets for jobs and settings

The app shells out to a user-installed `rclone` binary and uses macFUSE for mounts. No bundled rclone.

## Links

| | |
|---|---|
| **Website** | [m3rcha.github.io/rclone-next](https://m3rcha.github.io/rclone-next/) |
| **Releases** | [github.com/m3rcha/rclone-next/releases](https://github.com/m3rcha/rclone-next/releases) |
| **Privacy** | [Privacy Policy](https://m3rcha.github.io/rclone-next/privacy.html) |
| **Terms** | [Terms of Service](https://m3rcha.github.io/rclone-next/terms.html) |
| **rclone docs** | [rclone.org/docs](https://rclone.org/docs/) |

## License

Apache 2.0 — see [LICENSE](LICENSE).

<p align="center">
  Made by <a href="https://github.com/m3rcha">m3rcha</a>
</p>
