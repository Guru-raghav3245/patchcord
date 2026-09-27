# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Status

> **Reminder for the user (raise this at the start of the next session):** the multi-device picker has never been tested with two real devices. The user will soon have a second Android phone. Ask whether it's available, and if so, test with both it and the CT10 connected: both appear, switching between them works, and unplugging one leaves the other working.

v1.0 is built, and all six phases in `PLAN.md` are done and verified on an Activo CT10. The spec is `Activo MTP Tool — v1 Spec.md`; `PLAN.md` has per-phase detail and measurements.

- **Repo:** https://github.com/Guru-raghav3245/mtp-tool (private, branch `main`).
- **Release:** `dist/` holds `MTPTool-1.0.dmg`, the two LGPL source archives, and `SHA256SUMS.txt`.
- **Website:** https://mtptool.vercel.app — `site/` is a static page on Vercel (Hobby, project `mtptool`), linked to this GitHub repo; a push that changes `site/` or `vercel.json` deploys it (root `vercel.json` serves only `site/`). To release: run `make-dmg.sh`, replace `site/downloads/*` with the four `dist/` files, update the version/size/filenames in `site/index.html`, then commit and push.
- **Install flow:** verified with a real Safari download: warning → Privacy & Security → Open Anyway → launch. Later launches have no prompts.
- **Untested:**
  - Multi-device picker (see the reminder above)
  - microSD / second storage (no card available)
  - Real DSD files
  - Mac sleep/wake with the device connected
  - Switching USB port
  - CT10 screen turning off mid-transfer
  - Replug faster than the 1 s debounce
  - A second Mac
- **Known limit:** listing is about 9 ms per file on Android (libmtp queries objects one by one), so a flat 2,000-file folder takes about 18 s.
- **Possible next steps:** send the libmtp patch upstream; make the repo public (it would host the LGPL source).

## Build

```
./scripts/build-libs.sh   # one-time: downloads + builds arm64 libusb 1.0.30 and patched libmtp 1.1.23 into vendor/prefix
xcodegen generate         # project.yml -> MTPTool.xcodeproj (gitignored; edit project.yml, never the xcodeproj)
xcodebuild -project MTPTool.xcodeproj -scheme MTPTool -configuration Debug -derivedDataPath build build
./scripts/make-dmg.sh     # Release build -> dist/MTPTool-<ver>.dmg + LGPL source archives + SHA256SUMS
```

There are no unit tests. The app has headless commands for testing against a real device (see `App/CLI.swift` below); e.g. `build/Build/Products/Debug/MTPTool.app/Contents/MacOS/MTPTool --probe /`.

- **App icon:** `python3 scripts/make-icon.py` draws it into `App/Assets.xcassets/AppIcon.appiconset` (macOS ignores a single 1024 image, so it writes the full 16–512 set).
- **Post-build phase:** `scripts/bundle-libs.sh` copies the dylibs into `Contents/Frameworks`, rewrites their install names to `@rpath`, copies `vendor/licenses/*` and the patch into `Contents/Resources/Licenses`, and ad-hoc signs.
  - `ENABLE_DEBUG_DYLIB: NO` is required, or that codesign step fails.
  - Release has `CODE_SIGN_INJECT_BASE_ENTITLEMENTS: NO`, or ad-hoc builds ship `get-task-allow`.
- **Deployment target:** macOS 12.0, because Xcode 27 can't target 11 (the spec says 11). The libraries are built for 11.0.
- **libusb:** `build-libs.sh` passes `ac_cv_func_pipe2=no`. Newer SDKs expose `pipe2`, and libusb then crashes in `usbi_create_event`.
- **Changing the libmtp patch:**
  1. Extract a pristine `vendor/src/libmtp-1.1.23.tar.gz` and apply the current patch.
  2. Edit the sources.
  3. Regenerate `vendor/patches/libmtp-ct10.patch` as a `diff -u` against pristine sources, with `a/src/...` and `b/src/...` paths.
  4. Rerun `build-libs.sh`.
  5. Update `vendor/licenses/NOTICE.txt` whenever the patch or a library version changes.
- **Gatekeeper testing:** only a real browser download reproduces the first-launch warning (e.g. `python3 -m http.server` in `dist/`, then Safari). Hand-set `com.apple.quarantine` doesn't propagate into the DMG, and locally built files have no quarantine at all.

## CT10 / device gotchas

- **`vendor/patches/libmtp-ct10.patch` is essential; don't drop it.** It fixes four things:
  - **Reset on close:** libmtp USB-resets Android devices on close by default, and the CT10 then times out on every later session until replugged. The patch adds a CT10 table entry without `FORCE_RESET_ON_CLOSE`, and stops libmtp re-ORing Android default flags onto entries that set their own.
  - **Upload cancel:** libmtp didn't wait for the device after a cancelled send, so Android's f_mtp swallowed the next command as object data (a 60 s stall). The patch waits for device-ready and sends a zero-length packet. Android deletes the partial object itself.
  - **Rename leaks:** two small leaks in `LIBMTP_Set_Object_Filename`.
- **Busy device:** MacDroid and Android File Transfer take `UsbExclusiveOwner` of the device, and the claim then fails with -3. Check with `ioreg -p IOUSB -w0 -l | grep UsbExclusiveOwner`.
- **Device clock:** the CT10's clock reads 2018-01-01, so files created on it get that date. That's the device, not the app.
- **Stable id:** the CT10 keeps the same libusb id (`bus-devnum`, e.g. `1-1`) across a replug, so `DeviceManager` re-validates held sessions on every rescan instead of trusting the id.
- **Debugging:** the GUI app logs `[devices] ...` lines to stdout on every change (run the binary directly to see them). `scripts/reopen-test.c` checks open → close → reopen in one process.

## Architecture

Swift + SwiftUI over libmtp/libusb through a bridging header (`App/Bridging-Header.h`), with no shim. Both libraries are LGPL, so they stay **dynamic** `.dylib`s in `Contents/Frameworks`. Never link them statically.

- `App/DeviceManager.swift`: the device layer.
  - **Hotplug:** `USBWatcher` (IOKit USB add/remove notifications) triggers a debounced (1 s) libmtp rescan.
  - **Sessions:** every detected device stays open (one session each) until unplugged or the app quits; sessions are closed on `willTerminate`.
  - **Threading:** all libmtp calls run on one serial `mtp` queue, and results are published on main.
  - **Busy device:** if an open fails, `usbExclusiveOwner` reads the `UsbExclusiveOwner` IORegistry property to name the blocking app.
  - **Listing:** `list(device:storage:folder:)` blocks on the `mtp` queue, so the UI calls it from `Task.detached`. The root folder is `DeviceManager.rootFolder` (0xFFFFFFFF). libmtp returns NULL for both empty and failed listings; the error stack tells them apart.
- `App/Transfers.swift`: download/upload batches, one at a time.
  - **Planning:** a step on the `mtp` queue expands folders into a flat file list, creating the folders locally or on the device, and skipping hidden files on upload. Files then copy one by one.
  - **Progress and cancel:** progress arrives through libmtp's C callback, and returning 1 from it cancels.
  - **Partial files:** downloads write `.name.mtpdownload` next to the destination and rename it after a size check. Failed uploads delete the partial object, and report it only if it still exists.
- `App/FileOps.swift`: create folder, rename, and delete. Rename uses `LIBMTP_Set_Object_Filename`, which works for files and folders. Delete recurses depth-first, because not every device deletes non-empty folders. These run async on the `mtp` queue, with completion on main.
- `App/CLI.swift`: headless commands. All use the first device's first storage.
  - `--probe [/folder]`
  - `--get /dev/path <dir>`
  - `--put <path> /dev/folder`
  - `--cancel-after <s>`
  - `--mkdir`
  - `--rename /dev/path newname`
  - `--rm`
- `App/ContentView.swift`: device picker (shown only for >1 device), error + Retry, `BrowserView`, `TransferBar`, and `NameSheet`.
  - **`BrowserView`:** storage picker, breadcrumb, sortable `Table`, drop-in to upload, and drag-out via a temp download. ⌘ held at drag start makes it a move.
  - **macOS 12 workaround:** double-click and the context menu are per-cell (`rowActions`), because row-level actions need macOS 13.

## What this is

A free, native macOS app (Apple Silicon only, macOS 12+) for transferring files between a Mac and MTP Android devices, validated against the Activo CT10 DAP.
- USB only: no network calls, telemetry, or Full Disk Access.
- Distributed as an ad-hoc-signed DMG from the user's website, with no Developer ID or notarization. On macOS 15+ first launch needs Privacy & Security → Open Anyway; right-click → Open no longer works.

## Out of scope for v1

- Finder/FSKit mount
- Developer ID signing
- Sparkle auto-update
- Wi-Fi MTP
- PTP-only devices
- Windows/Linux
- App Store (sandboxing)
- Localization
- Intel support (open question)
