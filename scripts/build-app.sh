#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
CONFIGURATION="${CONFIGURATION:-release}"
swift build -c "$CONFIGURATION"
BIN="$(swift build -c "$CONFIGURATION" --show-bin-path)/Delulu"
APP="$ROOT/dist/Delulu.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Delulu"
cp Resources/Info.plist "$APP/Contents/Info.plist"
swift scripts/generate-icon.swift "$ROOT/.build/Delulu.iconset"
iconutil -c icns "$ROOT/.build/Delulu.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
plutil -lint "$APP/Contents/Info.plist"
codesign --force --sign - --identifier app.delulu.menubar "$APP"
codesign --verify --strict "$APP"
printf '\nBuilt %s\nOpen it with: open "%s"\n' "$APP" "$APP"
