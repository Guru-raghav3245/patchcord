#!/bin/bash
# Release build -> dist/MTPTool-<version>.dmg, plus the library source archives LGPL requires us to publish
# next to it. Run scripts/build-libs.sh first.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
xcodegen generate >/dev/null
xcodebuild -project MTPTool.xcodeproj -scheme MTPTool -configuration Release -derivedDataPath build build -quiet
APP=build/Build/Products/Release/MTPTool.app
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
codesign --verify --deep --strict "$APP"

DIST="$ROOT/dist" STAGE="$(mktemp -d)"
mkdir -p "$DIST"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp scripts/dmg-readme.txt "$STAGE/Read Me First.txt"
hdiutil create -volname "MTP Tool $VERSION" -srcfolder "$STAGE" -format UDZO -ov "$DIST/MTPTool-$VERSION.dmg" >/dev/null
rm -rf "$STAGE"

# Source for the LGPL libraries shipped inside the app: libusb as released, libmtp with our patch applied.
cp vendor/src/libusb-1.0.30.tar.bz2 "$DIST/"
TMP="$(mktemp -d)"
tar xzf vendor/src/libmtp-1.1.23.tar.gz -C "$TMP"
(cd "$TMP/libmtp-1.1.23" && patch -p1 -s < "$ROOT/vendor/patches/libmtp-ct10.patch")
cp vendor/patches/libmtp-ct10.patch vendor/licenses/NOTICE.txt "$TMP/libmtp-1.1.23/"
tar czf "$DIST/libmtp-1.1.23-mtptool.tar.gz" -C "$TMP" libmtp-1.1.23
rm -rf "$TMP"

(cd "$DIST" && shasum -a 256 MTPTool-$VERSION.dmg libusb-1.0.30.tar.bz2 libmtp-1.1.23-mtptool.tar.gz > SHA256SUMS.txt)
ls -lh "$DIST"
