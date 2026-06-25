#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
APP="RcloneNext.app"
RES="Sources/RcloneNext/Resources"
WHITE="white-icon/Assets.xcassets/AppIcon.appiconset"
COLOR="color-icon/Assets.xcassets/AppIcon.appiconset"

mkdir -p "$RES"

# In-app UI: white icon set.
if [ -d "$WHITE" ]; then
  cp "$WHITE/32.png" "$RES/app-icon-white-32.png"
fi

# App logo (About, dock icon, .icns): color icon set.
if [ -d "$COLOR" ]; then
  cp "$COLOR/128.png" "$RES/app-icon-color-128.png"
  cp "$COLOR/512.png" "$RES/app-icon-color-512.png"

  ICONSET="Packaging/AppIcon.iconset"
  rm -rf "$ICONSET" Packaging/AppIcon.icns
  mkdir -p "$ICONSET"
  cp "$COLOR/16.png"   "$ICONSET/icon_16x16.png"
  cp "$COLOR/32.png"   "$ICONSET/icon_16x16@2x.png"
  cp "$COLOR/32.png"   "$ICONSET/icon_32x32.png"
  cp "$COLOR/64.png"   "$ICONSET/icon_32x32@2x.png"
  cp "$COLOR/128.png"  "$ICONSET/icon_128x128.png"
  cp "$COLOR/256.png"  "$ICONSET/icon_128x128@2x.png"
  cp "$COLOR/256.png"  "$ICONSET/icon_256x256.png"
  cp "$COLOR/512.png"  "$ICONSET/icon_256x256@2x.png"
  cp "$COLOR/512.png"  "$ICONSET/icon_512x512.png"
  cp "$COLOR/1024.png" "$ICONSET/icon_512x512@2x.png"
  iconutil -c icns "$ICONSET" -o Packaging/AppIcon.icns
  rm -rf "$ICONSET"
fi

swift build -c release
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/RcloneNext" "$APP/Contents/MacOS/RcloneNext"
cp "Packaging/Info.plist"      "$APP/Contents/Info.plist"
[ -f "Packaging/AppIcon.icns" ] && cp "Packaging/AppIcon.icns" "$APP/Contents/Resources/"
# Flat PNGs in the app bundle (Bundle.main) — portable without .build paths.
for icon in "$RES"/app-icon-*.png; do
  [ -f "$icon" ] || continue
  cp "$icon" "$APP/Contents/Resources/"
done
if ! ls "$APP/Contents/Resources"/app-icon-*.png >/dev/null 2>&1; then
  echo "error: no app-icon PNGs in $RES — check white-icon/ and color-icon/" >&2
  exit 1
fi
codesign --force --deep --sign - "$APP"
echo "Built $APP — double-click in Finder or run: open $APP"
