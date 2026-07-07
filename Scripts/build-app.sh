#!/bin/bash
# Assemble Muster.app from the release build: the Muster executable + bundled
# muster-hook + an LSUIElement Info.plist. Idempotent; overwrites any prior app.
set -euo pipefail

CONFIG=release
APP="Muster.app"
BUNDLE_ID="com.jlk.muster"
VERSION="0.1.0"   # keep in sync with Muster.version

cd "$(dirname "$0")/.."

echo "==> Building ($CONFIG)…"
swift build -c "$CONFIG" --product Muster
swift build -c "$CONFIG" --product muster-hook
BIN="$(swift build -c "$CONFIG" --show-bin-path)"

echo "==> Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN/Muster" "$APP/Contents/MacOS/Muster"
cp "$BIN/muster-hook" "$APP/Contents/MacOS/muster-hook"
chmod +x "$APP/Contents/MacOS/Muster" "$APP/Contents/MacOS/muster-hook"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Muster</string>
    <key>CFBundleDisplayName</key><string>Muster</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>Muster</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Done: $APP"
