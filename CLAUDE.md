# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Status

> **Reminder for the user (raise this at the start of the next session):** the multi-device picker has never been tested with two real devices. The user will soon have a second Android phone. Ask whether it's available, and if so, test with both it and the CT10 connected: both appear, switching between them works, and unplugging one leaves the other working.


Phases 0–5 (see `PLAN.md`) are done (some Phase 5 hardware checks are untested), and Phase 6 is done except publishing, which the user does: upload the 4 files in `dist/` and verified on a CT10, except the multi-device test above. Spec: `Activo MTP Tool — v1 Spec.md`.

## Build

To test the Gatekeeper first-launch flow, download the DMG through a browser (e.g. `python3 -m http.server` in `dist/`, then Safari). Hand-setting `com.apple.quarantine` with `xattr` doesn't propagate to the DMG's contents, and locally built files have no quarantine at all, so neither shows the warning.

```
./scripts/build-libs.sh   # one-time: downloads + builds arm64 libusb and patched libmtp into vendor/prefix (gitignored)
xcodegen generate         # project.yml -> MTPTool.xcodeproj (edit project.yml, not the xcodeproj)
xcodebuild -project MTPTool.xcodeproj -scheme MTPTool -configuration Debug -derivedDataPath build build
./scripts/make-dmg.sh     # Release build -> dist/MTPTool-<ver>.dmg + LGPL source archives + SHA256SUMS
```

To change the libmtp patch: extract a pristine `vendor/src/libmtp-1.1.23.tar.gz` somewhere, apply the current patch, edit, then regenerate `vendor/patches/libmtp-ct10.patch` as a `diff -u` against pristine sources with `a/src/...` and `b/src/...` paths, and rerun `build-libs.sh`.

`scripts/bundle-libs.sh` (post-build phase) copies the dylibs into `Contents/Frameworks`, rewrites install names to `@rpath`, and ad-hoc signs. `ENABLE_DEBUG_DYLIB: NO` is required or that codesign step fails. Xcode 27 can't target macOS 11, so the deployment target is 12.0 (spec says 11).

## CT10 / device gotchas

- `vendor/licenses/` holds the LGPL texts and `NOTICE.txt`. `bundle-libs.sh` copies them and the patch into `Contents/Resources/Licenses`. Update `NOTICE.txt` whenever the patch or a library version changes.
- `vendor/patches/libmtp-ct10.patch` also fixes upload cancel: libmtp didn't wait for the device after a cancelled send, and Android's f_mtp swallowed the next command as object data (60 s stall). The patch waits for device-ready and sends a zero-length packet. Android deletes the partial object itself.
- `vendor/patches/libmtp-ct10.patch`: libmtp USB-resets Android devices on close by default; the CT10 never recovers from that (every later session times out until replug). The patch adds a CT10 table entry without `FORCE_RESET_ON_CLOSE` and stops libmtp re-ORing Android default flags onto entries that set their own. Don't drop it.
- MacDroid and Android File Transfer take `UsbExclusiveOwner` of the device; the claim then fails with -3. Check with `ioreg -p IOUSB -w0 -l | grep UsbExclusiveOwner`.
- The CT10's clock reads 2018-01-01, so files created on it get that date. That's the device, not the app.
- The CT10 keeps the same libusb id (`bus-devnum`, e.g. `1-1`) across a replug, so `DeviceManager` re-validates held sessions on every rescan instead of trusting the id. A replug faster than the 1 s debounce is untested.
- The GUI app logs `[devices] ...` lines to stdout on every change (run the binary directly to see them). `scripts/reopen-test.c` checks open → close → reopen in one process.

## Architecture

- `App/DeviceManager.swift`: the device layer. `USBWatcher` (IOKit USB add/remove notifications) triggers a debounced (1 s) libmtp rescan. Every detected device stays open (one session each) until unplugged or the app quits (sessions are closed on `willTerminate`). All libmtp calls run on one serial `mtp` queue; results are published on main. If an open fails, `usbExclusiveOwner` reads the `UsbExclusiveOwner` IORegistry property to name the blocking app.
- `DeviceManager.list(device:storage:folder:)` lists one folder via `LIBMTP_Get_Files_And_Folders`. It blocks on the `mtp` queue, so the UI calls it from `Task.detached`. Root folder is `DeviceManager.rootFolder` (0xFFFFFFFF). libmtp returns NULL for both empty and failed listings; the error stack tells them apart.
- `App/Transfers.swift`: download/upload batches, one at a time. A planning step on the `mtp` queue expands folders (creating them locally or on the device) into a flat file list, then files copy one by one. Progress comes through libmtp's C callback, and returning 1 from it cancels. Downloads write `.name.mtpdownload` next to the destination and rename after a size check. Failed uploads delete the partial object and report only if it still exists.
- `App/FileOps.swift`: create folder, rename (`LIBMTP_Set_Object_Filename`, which works for files and folders), and delete, which recurses depth-first because not every device deletes non-empty folders. Async on the `mtp` queue, completion on main.
- `App/CLI.swift`: headless `--probe [/folder]`, `--get /dev/path <dir>`, `--put <path> /dev/folder`, `--cancel-after <s>`, `--mkdir`, `--rename /dev/path newname`, `--rm`. All use the first device's first storage.
- `App/ContentView.swift`: device picker (only shown for >1 device), error + Retry, and `BrowserView` (storage picker, breadcrumb, sortable `Table`). Double-click is a per-cell tap gesture because row primary actions need macOS 13.

## What this is

A free, native macOS (Apple Silicon only, macOS 11+) app for transferring files between a Mac and MTP Android devices, validated against the Activo CT10 DAP. USB only; no network calls, telemetry, or Full Disk Access.

## Planned architecture (from the spec)

- **App shell:** Swift + SwiftUI, built/archived with Xcode.
- **MTP layer:** libmtp + libusb, reached through a thin C interop layer (bridging header or small Objective-C++ shim).
- **Bundling constraint:** both libs are LGPL, so they must be bundled as **dynamic** `.dylib`s in `Contents/Frameworks` with rpaths fixed via `install_name_tool`. Do not statically link them. Nothing may require a separate user install.
- **Signing/packaging:** ad-hoc signed, no Developer ID or notarization. On macOS 15+ users need Privacy & Security → Open Anyway on first launch; right-click → Open no longer works. The DMG is built by `scripts/make-dmg.sh` with `hdiutil`.

## v1 behavior requirements that shape the design

- Hotplug detection (no manual refresh); multiple devices connected → user picks the active one.
- Enumerate all storages (internal + microSD); browse, copy both directions (incl. drag-and-drop), create/rename/delete on device.
- Files can be hundreds of MB (DSD/hi-res): transfers need progress + cancel and must not load whole files in memory.
- A dropped connection mid-transfer must be surfaced as a failure and must not leave a silent corrupt partial file.

## Out of scope for v1

Finder/FSKit mount, Developer ID signing, Sparkle auto-update, Wi-Fi MTP, PTP-only devices, Windows/Linux, App Store (sandboxing), localization, Intel support (open question).
