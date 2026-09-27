#!/bin/bash
# Release build -> site/downloads/Patchcord-<version>.dmg (replacing the previous one), plus the library source archives LGPL requires us to publish
# next to it. Run scripts/build-libs.sh first.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
xcodegen generate >/dev/null
xcodebuild -project Patchcord.xcodeproj -scheme Patchcord -configuration Release -derivedDataPath build build -quiet
APP=build/Build/Products/Release/Patchcord.app
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
codesign --verify --deep --strict "$APP"

DIST="$ROOT/site/downloads" STAGE="$(mktemp -d)"
mkdir -p "$DIST"
rm -f "$DIST"/Patchcord-*.dmg
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp scripts/dmg-readme.txt "$STAGE/Read Me First.txt"
hdiutil create -volname "Patchcord $VERSION" -srcfolder "$STAGE" -format UDZO -ov "$DIST/Patchcord-$VERSION.dmg" >/dev/null
rm -rf "$STAGE"

# Source for the LGPL libraries shipped inside the app: libusb as released, libmtp with our patch applied.
cp vendor/src/libusb-1.0.30.tar.bz2 "$DIST/"
TMP="$(mktemp -d)"
tar xzf vendor/src/libmtp-1.1.23.tar.gz -C "$TMP"
(cd "$TMP/libmtp-1.1.23" && patch -p1 -s < "$ROOT/vendor/patches/libmtp-ct10.patch")
cp vendor/patches/libmtp-ct10.patch vendor/licenses/NOTICE.txt "$TMP/libmtp-1.1.23/"
rm -f "$DIST"/libmtp-1.1.23-*.tar.gz
tar czf "$DIST/libmtp-1.1.23-patchcord.tar.gz" -C "$TMP" libmtp-1.1.23
rm -rf "$TMP"

(cd "$DIST" && shasum -a 256 Patchcord-$VERSION.dmg libusb-1.0.30.tar.bz2 libmtp-1.1.23-patchcord.tar.gz > SHA256SUMS.txt)
ls -lh "$DIST"
