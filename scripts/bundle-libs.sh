#!/bin/bash
# Copies libmtp/libusb into Contents/Frameworks, rewrites install names to @rpath, bundles their
# licences, and ad-hoc signs.
set -euo pipefail
LIB="$SRCROOT/vendor/prefix/lib"
FW="$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH"
mkdir -p "$FW"
for f in libmtp.9.dylib libusb-1.0.0.dylib; do
  cp -f "$LIB/$f" "$FW/$f"; chmod u+w "$FW/$f"
  install_name_tool -id "@rpath/$f" "$FW/$f"
done
install_name_tool -change "$LIB/libusb-1.0.0.dylib" "@rpath/libusb-1.0.0.dylib" "$FW/libmtp.9.dylib"
BIN="$TARGET_BUILD_DIR/$EXECUTABLE_PATH"
install_name_tool -change "$LIB/libmtp.9.dylib" "@rpath/libmtp.9.dylib" "$BIN"
# LGPL: ship licence texts, notice, and our libmtp changes with the libraries.
LIC="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/Licenses"
mkdir -p "$LIC"
cp -f "$SRCROOT"/vendor/licenses/* "$SRCROOT/vendor/patches/libmtp-ct10.patch" "$LIC/"
codesign --force --sign - "$FW"/*.dylib
codesign --force --sign - "$TARGET_BUILD_DIR/$WRAPPER_NAME"
