# Patchcord — v1 Spec

Sep 26, 2026 · @Guru Raghav

## Overview

A macOS app that moves files between a Mac and MTP-based Android devices (Astell&Kern/Activo, Samsung, and others), starting with the Activo CT10 hi-res DAP. macOS has no native MTP support, and the existing fixes are either paywalled (MacDroid) or unreliable/incomplete on Apple Silicon (Android File Transfer, OpenMTP). This app replaces both: free, native Apple Silicon, and self-contained — nothing else to install.

## Goals and non-goals

**Goals for v1**

- Free, self-contained macOS app — no subscription
- Native Apple Silicon (arm64) support
- Works with any standard MTP device, validated against the Activo CT10
- Zero external downloads — nothing to install beyond the app itself
- Distributed as a DMG from Guru's own website (unsigned for now)

**Non-goals for v1**

- Windows or Linux support
- Wireless/Wi-Fi transfer (USB only)
- PTP-only devices (cameras)
- Mac App Store distribution
- Cloud sync or backup features
- Localization beyond English

## MTP device support and file transfer

- Auto-detect device connect/disconnect over USB (hotplug) — no manual "refresh" step
- Enumerate all exposed storage (internal memory and microSD, relevant to the CT10)
- Browse folders; list files with name, size, type, and modified date
- Copy files in both directions (device → Mac, Mac → device), including drag-and-drop
- Handle large files without choking — DSD/hi-res audio files can run into the hundreds of MB
- Create folders, rename, and delete files/folders on the device
- Show transfer progress with a cancel option
- Recover cleanly from a dropped connection mid-transfer — flag the failure, don't silently leave a corrupt partial file
- If multiple MTP devices are connected at once, let the user pick which one is active

## Distribution and packaging

- Single .app inside a DMG, drag-to-Applications install
- Distributed from Guru's own website — no App Store, no Homebrew, no third-party package manager
- MTP layer (libmtp/libusb or equivalent) statically linked or bundled inside the app — no separate runtime install
- Signing and notarization skipped for v1 to keep costs at zero — first launch shows a one-time Gatekeeper "unidentified developer" prompt (right-click → Open)

## Technical architecture

- MTP/USB layer: libmtp + libusb, bundled as dynamically-linked .dylibs in Contents/Frameworks (rpath-adjusted via install\_name\_tool) rather than statically linked — both libraries are LGPL, and dynamic linking keeps the app license-compliant without requiring users to install anything separately. Standard non-exclusive USB claim — no special entitlement expected for MTP-class devices like the CT10
- App shell: Swift + SwiftUI, bridged to libmtp/libusb through a thin C interop layer (bridging header or a small Objective-C++ shim) — smallest footprint and best Apple Silicon performance; no need for something like Electron for a file browser
- Build tooling: Xcode for building and archiving
- Packaging: create-dmg (or a plain hdiutil script) to assemble the drag-to-Applications DMG
- Signing: ad-hoc/self-signed build for v1, matching the no-Developer-ID decision — Xcode does this by default, no paid account needed
- Target architecture: Apple Silicon (arm64) only for v1 — Intel support is an open question, not committed

## Compatibility and system requirements

- macOS 11 (Big Sur) or later — no FSKit-specific version floor since Finder mount is deferred
- Apple Silicon Mac (M1 or later)
- USB-C data cable — charge-only cables won't expose file transfer, same limitation every MTP tool has
- Any device that speaks standard MTP; the Activo CT10 is the primary validation target, other Android phones/DAPs as a secondary check

## Security, privacy, and permissions

- All transfers are local over USB — no network calls, no cloud component, nothing leaves the Mac
- No Full Disk Access or other broad macOS permission requests beyond USB device access
- No telemetry or analytics in v1 (open question: whether to add crash reporting later)

## Out of scope for v1 / future considerations

- Finder mount via FSKit — revisit once the $99/year Developer ID cost is worth it
- Developer ID signing and notarization — add once ready, removes the Gatekeeper warning
- Windows and Linux ports
- Wireless (Wi-Fi) MTP transfer
- Mac App Store release (would require sandboxing — revisit separately)
- Wider device compatibility testing beyond the CT10 and generic Android phones
- Auto-update mechanism (e.g. Sparkle)
- Localization
