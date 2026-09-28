# Graph Report - patchcord  (2026-09-29)

## Corpus Check
- 78 files · ~102,938 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 14 file(s) not represented in the graph (top: .ttf 4, .woff2 4, (none) 1)

## Summary
- 451 nodes · 822 edges · 22 communities (18 shown, 4 thin omitted)
- Extraction: 88% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 102 edges (avg confidence: 0.86)
- Token cost: 502,946 input · 0 output

## Community Hubs (Navigation)
- CLI Headless Commands
- ContentView UI Components
- SwiftUI Pro Review Rules
- libmtp Patch & Device Fixes
- Browser View
- Site Downloads & Licenses
- App Entry & Theme
- v1 Build History
- Faceplate Design & Redesign
- App Icon
- Transfers Engine
- USB Hotplug Watcher
- Redmi A5 Connection Fixes
- Vercel Config
- libmtp Bridge & Reopen Test
- Spec & Plan
- SwiftUI Pro Skill Icon
- DMG Versioning & 404
- Library Build Script
- Dylib Bundling Script
- Pending SwiftUI Review
- Nav Glide Motion

## God Nodes (most connected - your core abstractions)
1. `DeviceManager` - 67 edges
2. `BrowserView` - 30 edges
3. `Entry` - 24 edges
4. `.body` - 21 edges
5. `SwiftUI Pro skill (v1.1)` - 14 edges
6. `NameSheet` - 13 edges
7. `SwiftUI Pro skill (v1.0, Claude plugin copy)` - 13 edges
8. `Patchcord App Icon Design` - 13 edges
9. `TransferBar` - 12 edges
10. `EngravedLabel` - 10 edges

## Surprising Connections (you probably didn't know these)
- `DeviceManager.open` --calls--> `usbExclusiveOwner()`  [EXTRACTED]
  conversation2.md → App/DeviceManager.swift
- `DeviceManager.openError` --calls--> `usbExclusiveOwner()`  [EXTRACTED]
  conversation2.md → App/DeviceManager.swift
- `Geist Mono OFL license (app)` --semantically_similar_to--> `Geist Mono OFL license (site)`  [INFERRED] [semantically similar]
  App/Fonts/OFL-geistmono.txt → site/fonts/OFL-geistmono.txt
- `Instrument Sans OFL license (app)` --semantically_similar_to--> `Instrument Sans OFL license (site)`  [INFERRED] [semantically similar]
  App/Fonts/OFL-instrumentsans.txt → site/fonts/OFL-instrumentsans.txt
- `Instrument Serif OFL license (app)` --semantically_similar_to--> `Instrument Serif OFL license (site)`  [INFERRED] [semantically similar]
  App/Fonts/OFL-instrumentserif.txt → site/fonts/OFL-instrumentserif.txt

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **libmtp patch fixes for CT10 / Redmi A5** — claude_libmtp_ct10_patch, claude_no_usb_reset_flag, claude_no_reset_on_close, claude_upload_cancel_fix, claude_download_cancel_fix, claude_fast_listing [EXTRACTED 1.00]
- **Competitors that USB-reset the CT10** — comp_comparison_android_file_transfer, comp_comparison_macdroid, comp_comparison_openmtp, comp_comparison_android_flags_0x18008106, claude_activo_ct10 [EXTRACTED 1.00]
- **LGPL compliance chain** — claude_lgpl_dynamic_linking, project_bundle_dylibs_phase, vendor_licenses_notice_notice, app_credits_credits, scripts_dmg_readme_install_instructions [INFERRED 0.85]
- **CT10 wedge-after-close debugging** — conversation_usb_reset_on_close, conversation_android_bugs_flags_override, conversation_clear_halt_guess, conversation_reopen_test, conversation_libmtp_ct10_patch [EXTRACTED 1.00]
- **v1 release pipeline** — conversation_dmg_release, conversation_bundle_libs, conversation_lgpl_compliance, conversation_gatekeeper_open_anyway, conversation_get_task_allow [EXTRACTED 1.00]
- **Release 1.0.2 feature set** — conversation2_release_1_0_2, conversation2_app_faceplate_rewrite, conversation2_two_progress_bars, conversation2_finder_cancel_x, conversation2_cancel_undo_batch, conversation2_device_name_switcher [EXTRACTED 1.00]
- **Redmi A5 connection fixes** — conversation2_redmi_a5, conversation2_ptpcamerad_takeover, conversation2_failed_open_handle_leak, conversation2_reset_on_close_removal, app_devicemanager_open [INFERRED 0.85]
- **Faceplate design system** — conversation2_faceplate_design, conversation2_amber_accent, conversation2_typography_system, conversation2_new_app_icon, conversation2_design_md [EXTRACTED 1.00]
- **LGPL source distribution for bundled libraries** — site_index_source_section, site_downloads_sha256sums_libusb_tarball, site_downloads_sha256sums_libmtp_tarball, vendor_licenses_libmtp_copying_lgpl_2_1, vendor_licenses_libmtp_copying, vendor_licenses_libusb_copying [INFERRED 0.85]
- **OFL-licensed fonts bundled in app and site** — site_fonts_ofl_geistmono, site_fonts_ofl_instrumentsans, site_fonts_ofl_instrumentserif, app_fonts_ofl_geistmono, app_fonts_ofl_instrumentsans, app_fonts_ofl_instrumentserif, site_fonts_ofl_geistmono_sil_open_font_license [EXTRACTED 1.00]
- **Release download and verification flow** — site_index_download_cta, site_404, site_downloads_sha256sums, site_downloads_sha256sums_patchcord_dmg, site_index_install_steps [INFERRED 0.85]
- **SwiftUI Pro review reference files** — _agents_skills_swiftui_pro_references_accessibility, _agents_skills_swiftui_pro_references_api, _agents_skills_swiftui_pro_references_data, _agents_skills_swiftui_pro_references_design, _agents_skills_swiftui_pro_references_hygiene, _agents_skills_swiftui_pro_references_navigation, _agents_skills_swiftui_pro_references_performance, _agents_skills_swiftui_pro_references_swift, _agents_skills_swiftui_pro_references_views [EXTRACTED 1.00]
- **Rules behind the 2026-09-27 Patchcord ContentView review** — _agents_skills_swiftui_pro_references_performance_avoid_work_in_body, _agents_skills_swiftui_pro_references_swift_task_detached_caution, _agents_skills_swiftui_pro_references_accessibility_icon_only_button_label, _agents_skills_swiftui_pro_references_api_foregroundstyle_over_foregroundcolor, _agents_skills_swiftui_pro_references_api_inflect_grammar_agreement, _agents_skills_swiftui_pro_references_swift_avoid_force_unwrap [INFERRED 0.85]
- **Website reuses app icon renders** — site_icon, site_favicon, app_assets_xcassets_appicon_appiconset_icon_512x512, app_assets_xcassets_appicon_appiconset_icon_32x32_2x [INFERRED 0.95]

## Communities (22 total, 4 thin omitted)

### Community 0 - "CLI Headless Commands"
Cohesion: 0.07
Nodes (35): CLI, String, UInt32, Void, .storage, Device, DeviceManager, .active (+27 more)

### Community 1 - "ContentView UI Components"
Cohesion: 0.08
Nodes (42): BrushedMetal, .body, CancelX, .body, ContentView, .body, DeviceErrorView, .body (+34 more)

### Community 2 - "SwiftUI Pro Review Rules"
Cohesion: 0.06
Nodes (45): SwiftUI Pro OpenAI agent config, SwiftUI Pro reference: accessibility, Use Button instead of onTapGesture, Prefer Dynamic Type / ScaledMetric over fixed font sizes, Icon-only buttons need a text label (labelStyle iconOnly), SwiftUI Pro reference: api, Use foregroundStyle() instead of foregroundColor(), Automatic grammar agreement via inflect: true (+37 more)

### Community 3 - "libmtp Patch & Device Fixes"
Cohesion: 0.07
Nodes (47): About-box Credits (LGPL attribution), Activo CT10 DAP, DeviceManager (device layer), Download cancel fix (no GET_DEVICE_STATUS poll), Fast listing via GetObjPropList (ptp_object_want_children), LGPL dynamic linking of libmtp/libusb, libmtp-ct10.patch, Serial mtp queue threading model (+39 more)

### Community 4 - "Browser View"
Cohesion: 0.10
Nodes (23): BrowserView, .body, .busy, .deleteTitle, .folder, .selected, LoadKey, RowMenu (+15 more)

### Community 5 - "Site Downloads & Licenses"
Cohesion: 0.09
Nodes (30): Geist Mono OFL license (app), Instrument Sans OFL license (app), Instrument Serif OFL license (app), Custom 404 page, libmtp-1.1.23-patchcord.tar.gz source archive, libusb-1.0.30.tar.bz2 source archive, Patchcord-1.0.5.dmg, Geist Mono OFL license (site) (+22 more)

### Community 6 - "App Entry & Theme"
Cohesion: 0.10
Nodes (20): App, PatchcordApp, .body, ButtonStyle, .faceplate, .faceplatePrimary, Color, EngravedLabel (+12 more)

### Community 7 - "v1 Build History"
Cohesion: 0.09
Nodes (28): Activo CT10 DAP, DEVICE_FLAGS_ANDROID_BUGS runtime OR override, BrowserView (SwiftUI Table browser), scripts/bundle-libs.sh dylib bundling, CLEAR_HALT data-toggle fix (reverted), CLI.swift headless commands (--probe/--get/--put/--cancel-after), Cmd-drag to move, DeviceManager (+20 more)

### Community 8 - "Faceplate Design & Redesign"
Cohesion: 0.09
Nodes (26): Amber accent (#F2A33A site, #A8620A app), App UI rebuilt in website faceplate style, Rename away from 'MTP Tool', Cancel undoes the whole batch, Competitor research (OpenMTP, MacDroid, Doppler, Audio Hijack, Swinsian), Debug-only window snapshot hook (PATCHCORD_SNAPSHOT), design-consultation skill run, design-html skill (skip design-shotgun) (+18 more)

### Community 9 - "App Icon"
Cohesion: 0.18
Nodes (5): json, Patchcord App Icon Design, pil, p(), stroke()

### Community 10 - "Transfers Engine"
Cohesion: 0.19
Nodes (12): Job, Bool, Double, Handle, String, UInt32, UInt64, Void (+4 more)

### Community 11 - "USB Hotplug Watcher"
Cohesion: 0.19
Nodes (10): DeviceManager.Device, .summary, Void, USBWatcher, AppKit, DispatchQueue, io_iterator_t, IOKit (+2 more)

### Community 12 - "Redmi A5 Connection Fixes"
Cohesion: 0.17
Nodes (12): DeviceManager.open, Activo CT10 DAP, libmtp failed-open USB handle leak fix, vendor/patches/libmtp-ct10.patch, Moto G86, Android 'No data transfer' USB mode (18d1:4ee7), ptpcamerad (macOS Photos/Image Capture daemon), ptpcamerad takeover: SIGKILL then reopen within 0.5 s (+4 more)

### Community 13 - "Vercel Config"
Cohesion: 0.29
Nodes (6): buildCommand, framework, ignoreCommand, installCommand, outputDirectory, $schema

### Community 14 - "libmtp Bridge & Reopen Test"
Cohesion: 0.33
Nodes (3): libmtp, stdio, unistd

### Community 15 - "Spec & Plan"
Cohesion: 0.50
Nodes (5): macOS 12 deployment target, No-network / leak verification, PLAN.md phased production plan, Conversation: MTP Tool v1 build session, Activo MTP Tool v1 Spec

### Community 16 - "SwiftUI Pro Skill Icon"
Cohesion: 1.00
Nodes (3): SwiftUI Pro Skill Icon (PNG), Swift bird mark in cyan-to-blue gradient circle, SwiftUI Pro Skill Icon (SVG)

### Community 17 - "DMG Versioning & 404"
Cohesion: 0.67
Nodes (3): site/404.html custom 404 with download-latest button, vercel.json .dmg content-disposition header breaks 404s, Versioned DMG filenames

## Knowledge Gaps
- **64 isolated node(s):** `.body`, `.folder`, `.busy`, `.deleteTitle`, `.copied` (+59 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 127 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `DeviceManager` connect `CLI Headless Commands` to `ContentView UI Components`, `Browser View`, `App Entry & Theme`, `Transfers Engine`, `USB Hotplug Watcher`?**
  _High betweenness centrality (0.164) - this node is a cross-community bridge._
- **Why does `.body` connect `Browser View` to `CLI Headless Commands`, `ContentView UI Components`, `App Entry & Theme`?**
  _High betweenness centrality (0.087) - this node is a cross-community bridge._
- **Why does `App UI rebuilt in website faceplate style` connect `Faceplate Design & Redesign` to `App Entry & Theme`?**
  _High betweenness centrality (0.070) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `DeviceManager` (e.g. with `.body` and `.storage`) actually correct?**
  _`DeviceManager` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `Entry` (e.g. with `.body` and `.menu()`) actually correct?**
  _`Entry` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 6 inferred relationships involving `.body` (e.g. with `DeviceManager` and `Entry`) actually correct?**
  _`.body` has 6 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.body`, `.folder`, `.busy` to the rest of the system?**
  _64 weakly-connected nodes found - possible documentation gaps or missing edges._