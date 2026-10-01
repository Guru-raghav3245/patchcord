# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Status

v1.0 is built, and all six phases in `PLAN.md` are done and verified on an Activo CT10. The spec is `Patchcord — v1 Spec.md`; `PLAN.md` has per-phase detail and measurements.

- **Repo:** https://github.com/Guru-raghav3245/patchcord (private, branch `main`). Local chat exports live in `conversations/` (untracked); keep them out of git. `graphify-out/` is a committed graphify knowledge graph of the repo (2026-09-29); rerun `/graphify` to refresh it after big changes.
- **Release:** 1.0.6 (2026-10-01: icon's cable drawn 1.15× larger so it fills the squircle like system icons). 1.0.5 (2026-09-29: cancel no longer wedges the Redmi A5, folders list ~19× faster, connect/disconnect snackbar). 1.0.4 (2026-09-28): internal names and bundle id → Patchcord. 1.0.3 (2026-09-28): renamed to Patchcord; light-mode link contrast. 1.0.2 (2026-09-27) brought the faceplate redesign, two progress bars + ✕ cancel, cancel undoes the batch, no USB reset on close for Android. `site/downloads/` holds `Patchcord-1.0.6.dmg` (1.4 MB with bundled fonts), the two LGPL source archives, and `SHA256SUMS.txt`.
- **Website:** https://patchcord.vercel.app — `site/` is a static page on Vercel (`index.html`, `404.html`, shared `style.css`, self-hosted OFL fonts in `site/fonts/`, the hero's app window drawn in HTML/CSS with generic names only, per DESIGN.md; the nav glide is a small inline script; sections in order: hero, Compared (`#compare`: a plain-language table of AFT / MacDroid / Patchcord for non-technical readers, built from the Competitors section below, then the "How Patchcord fixes it" steps; on ≤860 px each row becomes a block), Install, Verify & source; the nav links Install / Compare / Source) (Hobby, project `patchcord`), linked to this GitHub repo; a push that changes `site/` or `vercel.json` deploys it (root `vercel.json` serves only `site/`). `site/404.html` is Vercel's custom 404 (old DMG links land there, with a button to the current DMG). Don't add `headers` rules matching `*.dmg` in `vercel.json`: they also apply to missing paths, and Chrome then rejects the 404 with `ERR_INVALID_RESPONSE`. Vercel already serves `.dmg` as `application/x-apple-diskimage`, which browsers download. To release: bump `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` in `project.yml` and the first line of `scripts/dmg-readme.txt`, run `make-dmg.sh` (writes straight into `site/downloads/`, replacing the old DMG), update the version/size/filenames in `site/index.html` (and update the HTML app window in the hero, `.appwin`, if the app UI changed) and the download link in `site/404.html` (Vercel's custom 404, which also catches links to old DMGs), then commit and push.
- **Install flow:** verified with a real Safari download: warning → Privacy & Security → Open Anyway → launch. Later launches have no prompts.
- **Untested:**
  - microSD / second storage (no card available)
  - Real DSD files
  - Mac sleep/wake with the device connected
  - Switching USB port
  - CT10 screen turning off mid-transfer
  - Replug faster than the 1 s debounce
  - A second Mac
  - Any Android 4.4–7.1 device besides the CT10 (would show whether the reset wedge is widespread)
- **Listing speed:** a folder's metadata comes in six `GetObjPropList` requests (one per property, depth 1) instead of per-file queries: the CT10's 920-file folder went from 7.3 s to 0.39 s, and the output is identical to the per-file path on both devices.
- **Possible next steps:** send the libmtp patch upstream; make the repo public (it would host the LGPL source).
- **Name:** the app is **Patchcord** (renamed from its working title in 1.0.3; the user disliked the word "tool"). Everything carries the name: Xcode project/target/scheme `Patchcord`, `PatchcordApp`, bundle id `com.gururaghav.patchcord` (since 1.0.4), the `PATCHCORD_*` debug env vars, the GitHub repo and the Vercel project. "MTP" in code (`mtp` queue, `MTPError`) is the protocol, not the product.
- **SwiftUI review (2026-09-27, `swiftui-pro` skill, not yet applied)**, all in `App/ContentView.swift`:
  1. `Table(entries.sorted(using:))` re-sorts in `body` on every transfer-progress tick; sort in `load()` and `.onChange(of: sortOrder)` instead.
  2. `load()` uses `Task.detached` + blocking `mtp.sync`, which ties up a cooperative-pool thread per listing (up to ~18 s); resume a continuation from `mtp.async` instead. The CLI keeps the sync `list`.
  3. Back / New Folder / Delete are icon-only with no VoiceOver label: use `Label(...)` + `.labelStyle(.iconOnly)`.
  4. Low: `foregroundColor` → `foregroundStyle`; `background(_:alignment:)` → `background(_:in:)`; inflected plurals in `TransferBar.summary`; the `original!` force unwrap in `NameSheet`.
  - Skill rules that need macOS 13/14 (`@Observable`, `ContentUnavailableView`, the two-parameter `onChange`, `URL.downloadsDirectory`) don't apply at the macOS 12 target.

## Build

```
./scripts/build-libs.sh   # one-time: downloads + builds arm64 libusb 1.0.30 and patched libmtp 1.1.23 into vendor/prefix
xcodegen generate         # project.yml -> Patchcord.xcodeproj (gitignored; edit project.yml, never the xcodeproj)
xcodebuild -project Patchcord.xcodeproj -scheme Patchcord -configuration Debug -derivedDataPath build build
./scripts/make-dmg.sh     # Release build -> site/downloads/Patchcord-<ver>.dmg + LGPL source archives + SHA256SUMS
```

There are no unit tests. The app has headless commands for testing against a real device (see `App/CLI.swift` below); e.g. `build/Build/Products/Debug/Patchcord.app/Contents/MacOS/Patchcord --probe /`.

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
- **Gatekeeper testing:** only a real browser download reproduces the first-launch warning (e.g. `python3 -m http.server` in `site/`, then Safari). Hand-set `com.apple.quarantine` doesn't propagate into the DMG, and locally built files have no quarantine at all.

## CT10 / device gotchas

- **`vendor/patches/libmtp-ct10.patch` is essential; don't drop it.** It fixes these (files: `device-flags.h`, `music-players.h`, `libmtp.c`, `libusb1-glue.c`, `libusb-glue.h`, `ptp.c`):
  - **Reset on close:** libmtp USB-resets Android devices on close by default, and the CT10 then times out on every later session until replugged. The CT10 table entry adds the patch's own `DEVICE_FLAG_NO_USB_RESET` (0x1000) to `DEVICE_FLAGS_ANDROID_BUGS`. Verified 2026-09-28: one `libusb_reset_device` on a healthy CT10 leaves every later OpenSession failing (65 s each), and a second reset doesn't help; only a replug does. Why (investigated 2026-09-29, see "Why the CT10 can't survive a reset" below): the reset kills the CT10's MTP server and its Android 5.x framework never starts a new one. Android defaults are still ORed onto every Android device, as upstream does: an earlier patch skipped that for devices with their own entry, which silently changed Samsung Galaxy (`04e8:6860`) and Pixel (`18d1:4ee1`) behaviour, so don't bring it back.
  - **Upload cancel:** libmtp didn't wait for the device after a cancelled send, so Android's f_mtp swallowed the next command as object data (a 60 s stall). The patch waits 1 s after the cancel request, then sends a zero-length packet. Android deletes the partial object itself. Don't poll `GET_DEVICE_STATUS` there (an earlier version did): the Redmi A5 never answers it and then stops responding to everything, which shipped in every release from 1.0 to 1.0.4. Without the 1 s wait the Redmi takes the next command as object data (60 s stall). Verified on both devices with `--put … --cancel-after 2` (3.3 s, next command immediate).
  - **Download cancel:** `ptp_read_cancel_func` polled `GET_DEVICE_STATUS` too, so a cancelled download on the Redmi A5 stalled 63 s and left it wedged until the next open reset it. The patch drops that poll (draining the bulk-in endpoint at 300 ms is enough) and stops `ptp_transaction_new` sending a second cancel request for reads. Verified on both devices with `--get … --cancel-after 2` (2.6–3.4 s, next command immediate).
  - **Rename leaks:** two small leaks in `LIBMTP_Set_Object_Filename`.
  - **No reset on close for Android:** `DEVICE_FLAGS_ANDROID_BUGS` no longer includes `FORCE_RESET_ON_CLOSE`. The reset made the Redmi A5 fall back to "No data transfer" (USB id `18d1:4ee7`) whenever a session closed (app quit, CLI exit), so File transfer had to be re-selected on the phone. That fallback didn't reproduce on 2026-09-29: four raw `libusb_reset_device` runs (MTP only and MTP+adb, screen locked and unlocked) all left the Redmi in File transfer with a working session within a second, so its cause is unknown. Keep the flag off anyway: the reset breaks Android ≤7.1 devices (see below) and gains nothing on newer ones.
  - **No reset on open retry:** when `ptp_opensession` fails with an I/O error, libmtp retried after `libusb_reset_device`; the patch keeps that reset except for `NO_USB_RESET` devices (the CT10). The reset is what recovers a wedged Redmi A5, which stays in File transfer mode (`2717:ff48`).
  - **Fast listing:** `ptp_object_want_children` (called from `LIBMTP_Get_Files_And_Folders`) loads all children into libmtp's object cache before the per-file loop, which then does no I/O. It asks for single properties because with "all properties" the CT10's older Android stack swaps format 0 for the parent's format (Association) and returns only subfolders. It runs despite Android's `DEVICE_FLAG_BROKEN_MTPGETOBJPROPLIST`; objects without a filename and format are dropped from the cache, and any failed request leaves the old per-file path.
  - **Failed-open leak:** when `init_ptp_usb` failed after `libusb_open` (e.g. the claim was refused), the handle was never closed, so every Retry left the app holding the device.
- **Busy device:** MacDroid and Android File Transfer take `UsbExclusiveOwner` of the device, and the claim then fails with -3. Check with `ioreg -p IOUSB -w0 -l | grep UsbExclusiveOwner`.
- **ptpcamerad:** some phones (e.g. Redmi A5, Unisoc, `2717:ff48`) report their MTP interface as class 6 (Still Image), so macOS's `ptpcamerad` (behind Photos/Image Capture) claims the *interface* on plug-in. launchd relaunches it within a second, so `DeviceManager.open` SIGKILLs it and reopens as soon as the claim is released; once we hold the interface it can't take it back. Photos/Image Capture can't import from that phone until it's unplugged or the app quits. Check with `ioreg -p IOService -w0 -rc IOUSBHostInterface -l | grep UsbExclusiveOwner`. Such phones show libmtp's table name ("Xiaomi Mi-2s") until opened.
- **Device clock:** the CT10's clock reads 2018-01-01, so files created on it get that date. That's the device, not the app.
- **Why the CT10 can't survive a reset** (investigated 2026-09-29 with a raw libusb reset test, the macOS kernel log, and adb logcat on the Redmi; the CT10 has no Developer options, so its own log wasn't available):
  - **What the CT10 does after a reset:** it re-enumerates normally, answers EP0 and the MTP class request `GET_DEVICE_STATUS` (`0x2001`), rejects PTP reset `0x66` (the pre-8.0 kernel `f_mtp` driver), and never takes another bulk OUT packet (kernel log: `endpoint 0x01: timeout, 0 bytes transferred`). So its USB stack is fine and nothing on the device is reading MTP commands. It never drops off the bus by itself.
  - **What a phone does:** the Redmi's MTP server dies on the reset too (`request read returned -1, errno: 108`), but the phone then drops off the bus and reconnects, and Android starts a new server within ~450 ms.
  - **The cause in stock Android 4.4–7.1** (AOSP source at 4.4.4, 5.1.1, 6.0.1, 7.0.0 and 7.1.2):
    - `UsbDeviceManager` holds `DISCONNECTED` for 1000 ms, so a reset (the CT10 re-enumerates in ~50 ms) never reaches apps.
    - `MtpService` starts a server only `if (mServer == null)`, and nothing clears `mServer` when the server thread exits, so the dead server is never replaced.
    - Only a disconnect longer than 1 s (a replug) destroys the service and clears the dead server.
    - The fix, AOSP `360e401378` (2016, `OnServerTerminated`), first shipped in Android 8.0.
  - **The CT10:** it runs Android 5.x, 32-bit. Evidence: its MTP operations include Get/Set Object References but not Move/Copy Object, and its license list has only `app_process32`. Firmware 1.33, FCC ID `2AOLDAPP11`. The SoC is unknown: no public teardown, firmware or GPL source; the FCC internal photos would show it.
  - **Who else is affected:** not every Android ≤7.1 device wedges, since upstream libmtp reset all Android devices on close from 2014 (`729f5d3`, "Several reporters claim...") with few complaints. Likely factors are re-enumeration speed, how the USB driver reports a reset, and phone makers' framework patches. Other reported victims of the reset: the Kyocera Event (Android 4.x, exempted upstream in 2016) and Kindle Paperwhite 2024 (libmtp issue #436).
  - **Patch scope:** no reset on close for all Android devices; `NO_USB_RESET` (also no reset when opening fails) only for known devices like the CT10. Android's MTP always reports device version "1.0", so the Mac can't detect Android ≤7.1. The open-failure reset is what un-wedges a Redmi.
- **Stable id:** the CT10 keeps the same libusb id (`bus-devnum`, e.g. `1-1`) across a replug, so `DeviceManager` re-validates held sessions on every rescan instead of trusting the id.
- **Debugging:** the GUI app logs `[devices] ...` lines to stdout on every change (run the binary directly to see them). `scripts/reopen-test.c` checks open → close → reopen in one process.

## Competitors

Patchcord's two goals: (1) older Android devices (Android 7.1 and earlier, like the CT10) keep working across sessions, (2) keeps running on current and future macOS. From macOS 28 Apple largely removes Rosetta 2 (announced at WWDC25: Rosetta stays through macOS 27; macOS 26 is the last release for Intel Macs), so goal 2 means native Apple Silicon code.

Sources: on 2026-09-28 their binaries and source were read (AFT and MacDroid disassembled, OpenMTP's go-mtpfs/go-mtpx at the commits it pins; `conversations/comp-comparison.md`, untracked); on 2026-10-01 the bundles were checked (`lipo`, `LSMinimumSystemVersion`, `spctl`), with OpenMTP 3.3.0's source and the vendors' published requirements. **None of the CT10 failures was confirmed on the device.** libmtp line numbers are upstream 1.1.23.

| | Android ≤7.1 (CT10) | macOS 28+ (native Apple Silicon) | Why it doesn't work (technical) | Intel Macs | Signing |
|---|---|---|---|---|---|
| **Android File Transfer 1.0.12** | ✗ | ✗ | **Engine:** its own old `libmtp.dylib` + `libusb.dylib` in `Contents/Frameworks`, all x86_64 only. **Reset on close:** at disassembly offset `0x9cfe` it ORs `0x18008106` onto every device that reports Android's MTP extension. That is `BROKEN_MTPGETOBJPROPLIST` 0x4 · `UNLOAD_DRIVER` 0x2 · `BROKEN_SET_OBJECT_PROPLIST` 0x100 · `BROKEN_SEND_OBJECT_PROPLIST` 0x8000 · `LONG_TIMEOUT` 0x08000000 · `FORCE_RESET_ON_CLOSE` 0x10000000. The last one makes `close_usb()` (`libusb1-glue.c` ~2111) call `libusb_reset_device()` before `libusb_close()`, so every session close ends the CT10's MTP server. **Reset on open retry:** when `ptp_opensession()` returns `PTP_ERROR_IO`, `configure_usb_device()` (~2312) resets and retries; on a wedged CT10 the retry fails too. **Cancel:** an aborted `SendObject` stops writing without waiting for the device, so Android's `f_mtp` reads the next command container as object data and the host waits out `LONG_TIMEOUT` (60 s). **macOS:** x86_64 only (min 10.7), so it runs only under Rosetta and stops launching when Rosetta goes in macOS 28; Google withdrew it in 2024, so no fix is coming. Its "Android File Transfer Agent" login item (its own copy of the libmtp dylib) survives deleting the app and grabs the device on plug-in. | ✓ | Notarized Developer ID (Google) |
| **MacDroid 2.10** | ✗ | ✓ | **Engine:** bundles unpatched `libmtp.dylib` 1.1.23 and `libusb-1.0.dylib` (universal). **Reset on close:** the same `0x18008106` OR in `LIBMTP_Open_Raw_Device_Uncached` (arm64 offsets `0x3040`–`0x3048`), so `FORCE_RESET_ON_CLOSE` resets the CT10 on every session close (app quit at the latest). **Reset on open retry:** the same `PTP_ERROR_IO` → `libusb_reset_device()` → retry path. **Opt-out:** stock 1.1.23 has no CT10 entry (`4102:1182`) and no `NO_USB_RESET` flag, so there's no way to exempt it. **Cancel:** the same 60 s `SendObject` cancel stall. **Busy device:** holds `UsbExclusiveOwner` while running, so other apps' claims fail with -3. Moving files to the device needs the paid tier. | ✓ universal (min 11.5) | Notarized Developer ID (Electronic Team) |
| **OpenMTP 3.x** | ✗ | ✓ (Legacy mode ✗) | **Engine:** default "Kalam" mode is a pure-Go MTP stack (go-mtpfs + go-mtpx) over libusb, with no libmtp and no per-device quirk table. **Reset on open:** `Configure()` (`go-mtpfs/mtp/mtp.go:661`) calls `d.h.Reset()` when `OpenSession` fails, then `Close()` and reopens; on the CT10 the reset kills the MTP server, so the second attempt can't succeed either. **Reset on close:** `Close()` (`mtp.go:95`) runs a `CloseSession` transaction and calls `d.h.Reset()` if it errors, so one failed close leaves the CT10 dead until replugged. **Cancel:** cancelling an upload just stops the bulk-OUT writes, without a PTP `CancelTransaction` class request or a zero-length packet, so `f_mtp` keeps waiting for the declared object size and takes the next command as data. **Claim:** `Open()` ignores the `ClaimInterface` result, so a device held by another app gives a generic I/O error, not who holds it. Refuses to run with more than one MTP device connected. **macOS:** Electron with native arm64 builds since 3.2.0 (min 10.11–10.12); its "Legacy" mode is a separate x86_64-only libmtp CLI that needs Rosetta. | ✓ separate x64 build | Notarized (Electron) |
| **Patchcord 1.0.6** | ✓ | ✓ | **Engine:** libmtp 1.1.23 with `vendor/patches/libmtp-ct10.patch`. **No reset on close:** `DEVICE_FLAGS_ANDROID_BUGS` drops `FORCE_RESET_ON_CLOSE`, so every Android device gets `0x08008106`; close is a plain `CloseSession` + release. **No reset on open retry:** skipped for `DEVICE_FLAG_NO_USB_RESET` (0x1000) devices like the CT10; kept for others, since it un-wedges a Redmi A5. **Cancel:** upload waits 1 s after the cancel request, then sends a zero-length packet; download drops the `GET_DEVICE_STATUS` poll that wedged the Redmi. **Fewer closes:** `DeviceManager` holds one session per device until unplug or quit. **Busy device:** names the app holding `UsbExclusiveOwner`, and takes the interface back from `ptpcamerad`. **macOS:** the app and both bundled dylibs are arm64 only, with no Rosetta anywhere. | ✗ Apple Silicon only | ✗ ad-hoc; first launch needs Privacy & Security → Open Anyway |

- **The shared root cause:** all three reset the device, and Android 4.4–7.1 can't recover from a reset. `UsbDeviceManager` debounces disconnects for 1000 ms while the CT10 re-enumerates in ~50 ms, and `MtpService` only starts a server `if (mServer == null)` and never clears the dead one. AOSP fixed this in 8.0 (`360e401378`). Details in "Why the CT10 can't survive a reset" above. Upload cancel is the second shared bug.
- **The gap each competitor leaves:** AFT fails both goals. MacDroid and OpenMTP meet goal 2 but fail goal 1. Patchcord is the only one meeting both.
- **Where Patchcord is behind:** no Intel support (Intel Macs get no macOS after 26, so this shrinks over time), and no Developer ID/notarization, so first launch is harder than any competitor's. Patchcord has been run on macOS 26 only; macOS 27 is untested.
- **Same engine elsewhere:** GNOME's and KDE's file managers (gvfs, kio-mtp) and Calibre use libmtp with its default flags, so they reset older players too (as the site's Older Android card says).

## Architecture

Swift + SwiftUI over libmtp/libusb through a bridging header (`App/Bridging-Header.h`), with no shim. Both libraries are LGPL, so they stay **dynamic** `.dylib`s in `Contents/Frameworks`. Never link them statically.

- `App/DeviceManager.swift`: the device layer.
  - **Hotplug:** `USBWatcher` (IOKit USB add/remove notifications) triggers a debounced (1 s) libmtp rescan.
  - **Sessions:** every detected device stays open (one session each) until unplugged or the app quits; sessions are closed on `willTerminate`.
  - **Threading:** all libmtp calls run on one serial `mtp` queue, and results are published on main.
  - **Busy device:** if an open fails, `usbExclusiveOwner` reads the `UsbExclusiveOwner` IORegistry property of the device and its interfaces to name the blocking app. If it's `ptpcamerad`, `open` takes the device from it (see above).
  - **Listing:** `list(device:storage:folder:)` blocks on the `mtp` queue, so the UI calls it from `Task.detached`. The root folder is `DeviceManager.rootFolder` (0xFFFFFFFF). libmtp returns NULL for both empty and failed listings; the error stack tells them apart.
- `App/Transfers.swift`: download/upload batches, one at a time.
  - **Planning:** a step on the `mtp` queue expands folders into a flat file list, creating the folders locally or on the device, and skipping hidden files on upload. Files then copy one by one.
  - **Progress and cancel:** progress arrives through libmtp's C callback, and returning 1 from it cancels.
  - **Two bars:** the current file, plus (for multi-file batches) the batch total by bytes: `TransferStatus.overall` = (finished files' bytes + current fraction × current size) / total. Sizes come from the planning step.
  - **Partial files:** downloads write `.name.mtpdownload` next to the destination and rename it after a size check. Failed uploads delete the partial object, and report it only if it still exists.
  - **Cancel undoes the batch:** `runBatch`'s `undo` runs only on cancel. Downloads delete the top-level files/folders the batch wrote; uploads delete (via `deleteTree`) the top-level names the batch added. Names that already existed are refused at planning, so nothing pre-existing is touched. Verified on the CT10 with `--get/--put … --cancel-after`.
- `App/FileOps.swift`: create folder, rename, and delete. Rename uses `LIBMTP_Set_Object_Filename`, which works for files and folders. Delete recurses depth-first, because not every device deletes non-empty folders. These run async on the `mtp` queue, with completion on main.
- `App/CLI.swift`: headless commands. All use the first device's first storage.
  - `--probe [/folder]`
  - `--get /dev/path <dir>`
  - `--put <path> /dev/folder`
  - `--cancel-after <s>`
  - `--mkdir`
  - `--rename /dev/path newname`
  - `--rm`
- `App/ContentView.swift`: device switcher (the serif device name becomes a menu when >1 device is connected), a 3 s "connected"/"disconnected" snackbar (`DeviceManager.notice`, set by `publish` from the device-list diff, skipped for the scan at launch, also announced to VoiceOver), error + Retry, `BrowserView`, `TransferBar` (two bars + Finder-style ✕), and `NameSheet`.
  - **Look:** DESIGN.md's faceplate; tokens, fonts, `LED`, `EngravedLabel` and `.faceplate` button styles are in `App/Theme.swift`. Window uses `.hiddenTitleBar`.
  - **UI snapshot (Debug only):** `PATCHCORD_SNAPSHOT=/tmp/ui.png PATCHCORD_APPEARANCE=dark PATCHCORD_SNAPSHOT_DELAY=6 <app>/Contents/MacOS/Patchcord` (add `-ApplePersistenceIgnoreState YES` if it reports "no window": restored window state can leave the app windowless for the hook) saves the window's own rendering, so no Screen Recording permission is needed. Add `PATCHCORD_FAKE_TRANSFER=1` to show a mid-upload transfer bar (file 3 of 12, 24% total). Add `PATCHCORD_FAKE_NOTICE=1` to show the device snackbar.
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

## Design System
Always read DESIGN.md before making any visual or UI decisions.
All font choices, colors, spacing, and aesthetic direction are defined there.
Do not deviate without explicit user approval.
In QA mode, flag any code that doesn't match DESIGN.md.
