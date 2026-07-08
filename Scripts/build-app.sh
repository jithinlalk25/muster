#!/bin/bash
# Assemble Muster.app from a *universal* release build: the Muster executable +
# bundled muster-hook + an LSUIElement Info.plist. Idempotent; overwrites any prior app.
#
# Signing is optional and driven by the environment so this script can produce either
# an unsigned dev build (default) or a Developer ID-signed build (used by release.sh):
#   MUSTER_SIGN_ID  e.g. "Developer ID Application: Your Name (TEAMID)"
# When MUSTER_SIGN_ID is set, the nested binary and the app are signed with the
# hardened runtime (required for notarization).
set -euo pipefail

CONFIG=release
APP="Muster.app"
BUNDLE_ID="com.jlk.muster"

cd "$(dirname "$0")/.."

# Single source of truth for the version: Sources/MusterCore/Version.swift
VERSION="$(sed -n 's/.*version = "\([0-9][^"]*\)".*/\1/p' Sources/MusterCore/Version.swift | head -1)"
if [ -z "$VERSION" ]; then
    echo "!! could not parse version from Sources/MusterCore/Version.swift" >&2
    exit 1
fi

# Build a universal (arm64 + x86_64) binary so the app runs on Apple Silicon and Intel.
ARCHS=(--arch arm64 --arch x86_64)

echo "==> Building ($CONFIG, universal) v${VERSION}"
swift build -c "$CONFIG" "${ARCHS[@]}" --product Muster
swift build -c "$CONFIG" "${ARCHS[@]}" --product muster-hook
BIN="$(swift build -c "$CONFIG" "${ARCHS[@]}" --show-bin-path)"

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

# Optional Developer ID signing with the hardened runtime (sign the nested binary
# first, then the app). Skipped entirely when MUSTER_SIGN_ID is unset.
if [ -n "${MUSTER_SIGN_ID:-}" ]; then
    echo "==> Signing with: $MUSTER_SIGN_ID"
    codesign --force --options runtime --timestamp \
        --sign "$MUSTER_SIGN_ID" "$APP/Contents/MacOS/muster-hook"
    codesign --force --options runtime --timestamp \
        --sign "$MUSTER_SIGN_ID" "$APP"
    codesign --verify --strict --verbose=2 "$APP"
    echo "==> Signed & verified."
else
    echo "==> (unsigned dev build — set MUSTER_SIGN_ID to sign)"
fi

echo "==> Done: $APP (v$VERSION)"
