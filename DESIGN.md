# Design System — MTP Tool

## Product Context
- **What this is:** a free, native macOS app for copying files between a Mac and Android / MTP devices over USB, plus a one-page download site (`site/`).
- **Who it's for:** audiophiles loading hi-res music onto digital audio players (validated on the Activo CT10). Android phone users are served, but aren't the headline.
- **Space/industry:** Mac ↔ Android file transfer. Peers: OpenMTP, MacDroid, Android File Transfer (all feature-dump pages in generic blue/green). Taste references: Doppler, Audio Hijack, Swinsian.
- **Project type:** native macOS utility + marketing/download page.
- **The one thing to remember:** *it just works.* Plug in, the light comes on, files move.

## Aesthetic Direction
- **Direction:** "the faceplate": the front panel of good audio gear. Dark anodized graphite, engraved labels, one amber indicator light.
- **Decoration level:** intentional. Hairline "engraving" rules; a faint brushed-metal texture in the site hero only. No blobs, gradients, or icon-in-circle feature grids.
- **Mood:** calm, precise, quietly crafted. Hardware that works doesn't show off.
- **App rule:** the app wears the faceplate too (user request, 2026-09-27): graphite/paper window with hidden title bar, brushed header, serif device name, engraved mono labels, LED status, faceplate buttons, file list framed as a panel. Tokens live in `App/Theme.swift`, mirroring `site/style.css`. macOS 12 limit: the `Table` itself (background, header, row stripes) stays system-drawn; only its cell fonts/colors and the amber selection are ours.
- **Reference sites:** brushedtype.co/doppler, rogueamoeba.com/audiohijack, swinsian.com.
- **Approved preview:** `~/.gstack/projects/Guru-raghav3245-mtp-tool/designs/design-system-20260927/design-preview.html`.

## Typography
- **Display/Hero:** Instrument Serif (regular + italic). Headlines only, 40–72 px. Liner notes, not SaaS. The italic phrase may take the accent color.
- **Body:** Instrument Sans 400/500/600. Same family as the display face. 15–18 px.
- **UI/Labels:** Geist Mono 500, UPPERCASE, `letter-spacing: .14em`, 11–13 px, muted color. The "engraving".
- **Data/Tables:** Geist Mono for sizes, dates and counts, on the site and in the app.
- **Code:** Geist Mono 13 px (checksums, Terminal commands).
- **App:** the same three families, bundled as TTF in `App/Fonts` (OFL texts alongside) and registered at launch by `Theme.registerFonts()`. Menus, alerts and the table header stay SF (system-drawn).
- **Loading:** self-host WOFF2 files in `site/fonts/` with `font-display: swap`. No Google Fonts requests from the live site; it promises no network, no telemetry.
- **Scale (site):** label 11 · small 13 · body 16 · lead 18 · h3 22 · h2 40 · h1 clamp(44px, 6vw, 72px). Display line-height .98–1.1; body 1.6.

## Color
- **Approach:** restrained. One accent; amber always means *signal* (connected, active, progress). Never use it for warnings.

| Token | Dark | Light | Use |
|---|---|---|---|
| `--bg` | `#0E0F11` graphite | `#F4F2ED` paper | page background |
| `--panel` | `#17191C` | `#FBFAF7` | cards, panels |
| `--panel-2` | `#1D2024` | `#EEEBE4` | code, insets |
| `--line` | `#2A2D31` | `#DAD6CD` | hairline "engraving" rules |
| `--text` | `#E8E6E1` bone | `#16171A` ink | primary text |
| `--muted` | `#8C8A85` | `#66645F` | secondary text, labels |
| `--amber` | `#F2A33A` | `#F2A33A` | indicator light, fills, selection |
| `--amber-ink` | `#F2A33A` | `#9E5C09` | amber *text* (links, italic headline); light value is 4.7:1 on paper (`#B86E0E` was 3.6:1) |
| `--ok` | `#5FB37A` | `#2F8A4E` | success |
| `--err` | `#E0604F` | `#C2412F` | errors |

- **Dark mode:** the site is dark-first (`prefers-color-scheme`); light mode is the paper/ink pair above. Text on amber fills is always `#16171A`.
- **App:** `AccentColor` is **deep amber `#A8620A`** (not `#F2A33A`): macOS draws selected rows with white text on the accent, and white on `#F2A33A` is 2.1:1; `#A8620A` is 4.75:1. macOS only uses it when the system accent is "Multicolour" (the default). Everything else in the app uses the `Theme` tokens above (LED `#F2A33A`, `amberInk` for links, `ok`/`err` for status).

## Spacing
- **Base unit:** 8 px (4 px for tight UI).
- **Density:** spacious on the site; the app uses native macOS spacing (don't hard-code).
- **Scale:** 2xs(2) xs(4) sm(8) md(16) lg(24) xl(32) 2xl(48) 3xl(64) 4xl(72).

## Layout
- **Approach:** hybrid. The site hero is asymmetric (copy + CTA left, real app screenshot right); below it a spec sheet (mono label column 200 px + value column, hairline rows) instead of cards.
- **Grid:** hero 1fr / 1.15fr on desktop; single column below 860 px. 16–24 px side gutters; no horizontal scroll on phones.
- **Max content width:** 1120 px.
- **Border radius:** sm 5 px (code) · md 8 px (buttons) · lg 12–14 px (panels, window frames). No pill buttons.
- **Primary CTA:** solid `--text` background with `--bg` text and a lit amber LED dot; on hover the fill turns amber. One primary CTA per screen.
- **App window on the site:** drawn in HTML/CSS (`.appwin` in `site/index.html` + `site/style.css`), not a screenshot (user request, 2026-09-27): sharp at any zoom, same fonts/tokens as the page, and it can show the transfer bars. Always the app's dark theme, 760px wide at real size, running just off the right edge; `zoom: .6` below 860px. One `role="img"` label describes it; its innards are `aria-hidden`. Keep it in sync with the real app UI.

## Icon
- Graphite squircle with a subtle brushed vertical grain and a darker rim; one bone-white (`#E8E6E1`) cable that runs right into an arrow, loops back, and ends in a USB-C plug; amber indicator LED top-right with a soft glow.
- No text, no fine detail: must read at 16 px. Drawn by `scripts/make-icon.py` into the full 16–512 set; `site/icon.png` and `site/favicon.png` come from the same source.

## Motion
- **Approach:** minimal-functional.
- **The one flourish:** the amber LED fades on once at page load (≈1.2 s, ease-out) and stays lit. Disabled under `prefers-reduced-motion`.
- **Nav glide:** header links scroll to their section with a deliberate ease-in-out cubic, 0.9–1.5 s by distance (≈1.0–1.15 s on the current page), so visitors see the page travel. Target is clamped to the max scroll; manual wheel/touch cancels it; the section gets focus and the URL hash updates. Instant under `prefers-reduced-motion`. (User request, 2026-09-27; CSS `scroll-behavior: smooth` was too fast.)
- **Easing:** enter ease-out · exit ease-in · move ease-in-out.
- **Duration:** micro 50–100 ms · short 150–250 ms · medium 250–400 ms. The app uses system animations only.

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-09-27 | Initial design system created | /design-consultation: audiophile audience, "it just works", research on OpenMTP, MacDroid, Doppler, Audio Hijack, Swinsian |
| 2026-09-27 | Graphite + single amber accent instead of navy | Reads as audio gear; every competitor is blue/green |
| 2026-09-27 | Instrument Serif headlines | Deliberate break from utility-software look; liner-notes feel for audiophiles |
| 2026-09-27 | Spec-sheet features instead of cards | Calm, precise; audiophiles read spec sheets |
| 2026-09-27 | New icon replaces Apple's icon-template grid | The old icon read as a placeholder |
| 2026-09-27 | ~~App stays native; only accent + tabular digits change~~ | Superseded same day |
| 2026-09-27 | App adopts the full faceplate UI | User wants the app to closely match the website |
| 2026-09-27 | App accent `#A8620A` instead of `#F2A33A` | White selected-row text needs ≥4.5:1 |
| 2026-09-27 | Hero app window drawn in HTML/CSS instead of a screenshot | User preference; crisper and themable |
