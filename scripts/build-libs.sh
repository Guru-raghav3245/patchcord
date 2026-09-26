#!/bin/bash
# Builds arm64 libusb + patched libmtp into vendor/prefix (sources are downloaded into vendor/src).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/vendor/src" PREFIX="$ROOT/vendor/prefix"
LIBUSB=1.0.30 LIBMTP=1.1.23
export MACOSX_DEPLOYMENT_TARGET=11.0 CFLAGS="-arch arm64 -O2" LDFLAGS="-arch arm64" PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
mkdir -p "$SRC" && cd "$SRC"
[ -f libusb-$LIBUSB.tar.bz2 ] || curl -fsSLO https://github.com/libusb/libusb/releases/download/v$LIBUSB/libusb-$LIBUSB.tar.bz2
[ -f libmtp-$LIBMTP.tar.gz ] || curl -fsSLO https://github.com/libmtp/libmtp/releases/download/v$LIBMTP/libmtp-$LIBMTP.tar.gz
rm -rf "$PREFIX" libusb-$LIBUSB libmtp-$LIBMTP
tar xf libusb-$LIBUSB.tar.bz2 && tar xf libmtp-$LIBMTP.tar.gz

# pipe2 is declared by newer SDKs but broken on macOS: libusb crashes in usbi_create_event without this.
(cd libusb-$LIBUSB && ac_cv_func_pipe2=no ./configure --prefix="$PREFIX" --disable-static && make -j8 && make install) >/dev/null
(cd libmtp-$LIBMTP && patch -p1 < "$ROOT/vendor/patches/libmtp-ct10.patch" \
  && ./configure --prefix="$PREFIX" --disable-static --disable-mtpz --with-udev=no && make -j8 && make install) >/dev/null
echo "Built into $PREFIX"
