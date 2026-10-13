# Changelog

Release notes for Patchcord, taken from the git history. Dates are commit dates.

Tags: **Added** (new functionality), **Fixed** (bug fix), **Improved** (better behavior or speed), **Cosmetic** (looks only), **Internal** (names, build, no user-visible change).

## 1.0.8 — 2026-10-01
- **Fixed:** Quit no longer hangs. It cancels a running transfer and waits at most 3 s for sessions to close.

## 1.0.7 — 2026-10-01
- **Fixed:** a device that is still opening shows as "Connecting" instead of "No device connected".

## 1.0.6 — 2026-10-01
- **Cosmetic:** app icon cable drawn 1.15× larger so it fills the squircle like system icons.

## 1.0.5 — 2026-09-29
- **Fixed:** cancelling a transfer no longer wedges some phones (libmtp patch).
- **Improved:** folders list far faster, in six requests instead of two per file (libmtp patch).
- **Added:** a snackbar shows when a device connects or disconnects.

## 1.0.4 — 2026-09-28
- **Internal:** Xcode project/target/scheme, `PatchcordApp` and `PATCHCORD_*` debug env vars renamed to Patchcord.
- **Internal:** bundle id is now `com.gururaghav.patchcord`.

## 1.0.3 — 2026-09-28
- **Changed:** the app is renamed Patchcord (app name, menu bar, About, DMG, LGPL source archive).
- **Cosmetic:** light-mode amber links are darker (`#9E5C09`, 4.7:1 contrast).

## 1.0.2 — 2026-09-27
- **Added:** two progress bars (current file and batch total) and a Finder-style cancel button.
- **Changed:** cancelling a transfer now removes everything the batch created, on the Mac or the device.
- **Fixed:** row selection, double-click and context menu are more reliable.
- **Fixed:** phones no longer drop out of File transfer on quit; Android devices get no USB reset on close (libmtp patch).
- **Fixed:** a failed open no longer leaks the USB handle (libmtp patch).
- **Cosmetic:** faceplate redesign (graphite/paper, engraved mono labels, one amber indicator light) and a new app icon.

## 1.0.1 — 2026-09-27
- **Added:** opens phones whose MTP interface is held by macOS's `ptpcamerad`.
- **Improved:** error messages name apps holding the device at the interface level.
- **Fixed:** the USB handle is closed when an open fails (libmtp patch).

## 1.0 — 2026-09-27
First release: native macOS MTP file transfer for Apple Silicon, built on bundled libmtp/libusb (dynamic, LGPL 2.1) and validated on a DAP.
- **Added:** hotplug detection, device picker, and a message naming the app that holds a busy device.
- **Added:** browsing with a sortable file list and breadcrumbs.
- **Added:** transfers both ways with progress and cancel, folder copy, drag and drop (⌘-drag to move), and no partial files on failure.
- **Added:** create folder, rename, recursive delete.
- **Fixed:** libmtp patch for DAPs: no reset on close, upload-cancel stall, rename leak.

## Website only (no app release)
- 2026-10-13 **Added:** Changelog section with colour-coded classifiers. **Changed:** hero headline and copy now lead with older Androids ("Older Androids, working on your Mac."), "music player" became "DAP" throughout, and the hero app window shows FLAC, MP3 and WAV files.
- 2026-10-13 **Added:** Privacy and Terms pages, footer with contact and source links. **Changed:** removed the Verify & source section.
- 2026-10-01 **Changed:** Compared section replaced the Older Android card (OpenMTP later dropped from the table); removed Specs; added a "How to install" button. **Cosmetic:** graphite scroll bar.
- 2026-09-29 **Added:** explanation of the Android ≤7.1 USB-reset problem and the fix.
- 2026-09-27 **Added:** first site, custom 404 page. **Cosmetic:** HTML/CSS hero window, design review fixes (gutters, tap targets, link contrast).
