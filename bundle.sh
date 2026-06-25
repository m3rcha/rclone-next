#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
APP="RcloneNext.app"
swift build -c release
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/RcloneNext" "$APP/Contents/MacOS/RcloneNext"
cp "Packaging/Info.plist"      "$APP/Contents/Info.plist"
[ -f "Packaging/AppIcon.icns" ] && cp "Packaging/AppIcon.icns" "$APP/Contents/Resources/"
# Ad-hoc sign so Gatekeeper allows local launch without "damaged" prompts.
codesign --force --deep --sign - "$APP"
echo "Built $APP — double-click in Finder or run: open $APP"
