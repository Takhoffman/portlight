#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
VERSION=${1:-}
SIGNING_IDENTITY=${DEVELOPER_ID_APPLICATION:-Developer ID Application: Takayuki Hoffman (KF4GF4J4K9)}
NOTARY_PROFILE=${NOTARYTOOL_PROFILE:-SSDWatcherNotary}

if [[ ! $VERSION =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    print -u2 "Usage: scripts/release.sh <version>"
    exit 64
fi

SOURCE_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Resources/Info.plist")
if [[ $SOURCE_VERSION != $VERSION ]]; then
    print -u2 "Info.plist version $SOURCE_VERSION does not match requested release $VERSION"
    exit 1
fi

"$ROOT_DIR/scripts/build-app.sh"
APP="$ROOT_DIR/dist/Portlight.app"
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/portlight-release.XXXXXX")
trap 'rm -rf "$TEMP_DIR"' EXIT

codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

NOTARY_ZIP="$TEMP_DIR/Portlight-notarization.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$NOTARY_ZIP"
xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"

RELEASE_ZIP="$ROOT_DIR/dist/Portlight-$VERSION.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$RELEASE_ZIP"
(
    cd "$ROOT_DIR/dist"
    shasum -a 256 "Portlight-$VERSION.zip" > SHA256SUMS
)

print "Release ready: $RELEASE_ZIP"
