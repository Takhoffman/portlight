#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
cd "$ROOT_DIR"
swift build -c release

APP="$ROOT_DIR/dist/Portlight.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT_DIR/.build/release/Portlight" "$APP/Contents/MacOS/Portlight"
cp "$ROOT_DIR/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT_DIR/Resources/Portlight.icns" "$APP/Contents/Resources/Portlight.icns"
echo "Built $APP"
