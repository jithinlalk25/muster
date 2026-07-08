#!/bin/bash
# Cut a signed, notarized, stapled Muster release DMG.
#
# Prerequisites (one-time — see docs/RELEASING.md):
#   - Apple Developer Program membership + a "Developer ID Application" certificate
#     imported into your login keychain.
#   - notarytool credentials stored as a keychain profile:
#       xcrun notarytool store-credentials "<profile>" \
#         --apple-id <email> --team-id <TEAMID> --password <app-specific-password>
#
# Usage:
#   MUSTER_SIGN_ID="Developer ID Application: Your Name (TEAMID)" \
#   MUSTER_NOTARY_PROFILE="muster-notary" \
#     ./Scripts/release.sh
#
# Output: dist/Muster-<version>.dmg (notarized + stapled) and the sha256 to paste
# into the Homebrew cask.
set -euo pipefail

cd "$(dirname "$0")/.."

: "${MUSTER_SIGN_ID:?set MUSTER_SIGN_ID to your \"Developer ID Application: … (TEAMID)\" identity}"
: "${MUSTER_NOTARY_PROFILE:?set MUSTER_NOTARY_PROFILE to your notarytool keychain profile name}"

VERSION="$(sed -n 's/.*version = "\([0-9][^"]*\)".*/\1/p' Sources/MusterCore/Version.swift | head -1)"
[ -n "$VERSION" ] || { echo "!! could not parse version from Sources/MusterCore/Version.swift" >&2; exit 1; }

APP="Muster.app"
DMG="dist/Muster-$VERSION.dmg"
STAGE="dist/dmg"

# ---- Preflight: fail early with clear messages -------------------------------
echo "==> Preflight"
if ! security find-identity -v -p codesigning | grep -qF "$MUSTER_SIGN_ID"; then
    echo "!! signing identity not found in keychain: $MUSTER_SIGN_ID" >&2
    echo "   available identities:" >&2
    security find-identity -v -p codesigning >&2
    exit 1
fi
if ! xcrun notarytool history --keychain-profile "$MUSTER_NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "!! notarytool profile '$MUSTER_NOTARY_PROFILE' not usable. Create it with:" >&2
    echo "   xcrun notarytool store-credentials \"$MUSTER_NOTARY_PROFILE\" --apple-id <email> --team-id <TEAMID> --password <app-specific-password>" >&2
    exit 1
fi

# ---- Build + sign (build-app.sh signs when MUSTER_SIGN_ID is set) ------------
export MUSTER_SIGN_ID
./Scripts/build-app.sh

# ---- Package a DMG with a drag-to-Applications layout ------------------------
echo "==> Packaging $DMG"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE" dist
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Muster $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

# ---- Notarize the DMG + staple the ticket -----------------------------------
echo "==> Notarizing (this can take a few minutes)…"
xcrun notarytool submit "$DMG" --keychain-profile "$MUSTER_NOTARY_PROFILE" --wait
echo "==> Stapling"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature -v "$DMG" || true

# ---- Report: sha256 + ready-to-paste cask stanza ----------------------------
SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"
echo
echo "======================================================================"
echo "  Release artifact : $DMG"
echo "  Version          : $VERSION"
echo "  sha256           : $SHA"
echo "----------------------------------------------------------------------"
echo "  Next:"
echo "   1) gh release create v$VERSION \"$DMG\" --title \"Muster $VERSION\" --generate-notes"
echo "   2) In your tap, set  version \"$VERSION\"  and  sha256 \"$SHA\"  in Casks/muster.rb, then push."
echo "======================================================================"
