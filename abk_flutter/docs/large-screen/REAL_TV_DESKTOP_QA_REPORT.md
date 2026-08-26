# Real TV / Desktop QA Report — Large-Screen UX Phase

## Device (primary acceptance target)

| Property | Value |
|---|---|
| Model | ANKER Nebula Mars 2 V2 (`D2325`, `taihang`) |
| OS | Android 14 (API 34), Google TV |
| Physical resolution | 1920×1080 |
| Density | 320 → devicePixelRatio **2.0** → **logical 960×540** |
| Detected mode | `AbkBreakpoints.isTv = true` |
| Input | real remote + `adb` keyevents/taps for diagnostics |
| Build | Release APK, `--dart-define-from-file=qa-defines.json`, installed via `adb install -r` |

Resolution was **not** altered to make anything pass. (Wireless adb is intermittent — reconnect and, if needed, drive selection by tap; the projector's OS screensaver was disabled during QA to avoid interference.)

## Login (Problem A + B + focus)

| Check | Result |
|---|---|
| Cold launch → stable first frame, no black-nothing, no white flash | **PASS** (native launch dark + splash-first) |
| Initial focus visible on username **without any remote key** | **PASS** (white ring + gold glow on first frame) |
| Branding no longer consumes half the screen | **PASS** (single-column compact form at 540 height) |
| Login button + fields fit; appropriately compact | **PASS** |
| D-pad Down: user → pass → login → QA card, each auto-scrolled into view | **PASS** (scroll-to-focus) |
| QA Account card visible + reachable, no clip/overflow | **PASS** |

## First frame (Problem B — TCL device-specific)

Root cause (two layers, both device-differential): (1) `main()` awaited `bootstrap()` **before** `runApp()`, leaving a black window for the whole async init (length varies by device/network); (2) the **day-mode** native launch theme was `Theme.Light` + `@android:color/white` → a **white flash** on devices selecting light/day resources (e.g. TCL) — the always-dark Google TV projector never showed it.

Fixes: **runApp-splash-first** then bootstrap as a future (branded splash on frame 1, no arbitrary delay); native launch window **dark in day AND night** (`launch_background.xml` → black, `styles.xml` LaunchTheme → `Theme.Black`); `FocusManager.highlightStrategy = alwaysTraditional` on TV so focus rings paint on frame 1.

| Check | Projector | TCL |
|---|---|---|
| No black-nothing on cold launch | **PASS** (login stable from first app frame) | **pending owner** |
| No white flash | **PASS** (never reproduced — always-dark) | targeted fix, **pending owner** |
| Focus visible without a key press | **PASS** | expected PASS, **pending owner** |

TCL is not attached to the agent; the fixes target the proven device-differential causes and need one owner cold-launch pass (×5) to close.

## Focus visibility (#4)

`AbkFocusable` TV treatment = **scale 1.06 + 3 dp white outline + gold glow halo**. Verified unmistakable on dark cards (sidebar, posters), on the gold "دخول"/"تشغيل" primary buttons, and on player controls — the old gold-on-gold invisibility is gone.

## Home (TV rebalance)

| Check | Result |
|---|---|
| Posters comfortably large from couch distance (was starved-small) | **PASS** (rail heights TV-aware: movies/series 420) |
| Hero meaningful but not full-screen; first rail peeks below | **PASS** (hero capped ~52% viewport) |
| Focused card obvious | **PASS** (white ring + glow + enlarged play chip + bold 1-line title) |
| Row titles/typography readable | **PASS** |

## Live large-screen (embedded real player — F/G/H)

| Check | Result |
|---|---|
| Column proportions: categories narrow, channels medium, **preview dominant** | **PASS** (responsive to pane width) |
| Select channel → **real stream plays** in embedded preview | **PASS** (MBC 1 HD live decoded in preview) |
| Switch channel → **in-place** source swap, visible **loading** state | **PASS** (spinner + "Loading…" on the row, debounced) |
| Distinct states: focused / selected / **playing** (gold bar + gold name + LIVE) / loading / error | **PASS** |
| **Fullscreen expands the SAME session** — no reload | **PASS** |
| Fullscreen is **truly full** — no sidebar/menu, video only | **PASS** (root route above the shell; controls auto-hide) |
| **Exit fullscreen returns to embedded, still playing** (state preserved) | **PASS** |
| No duplicate audio / no stale preview / no route-teardown reset | **PASS** (single shared decode session; stops only on leaving Live tab) |

## Player controls (TV, from prior phase, retained)

Focusable Play/Pause, focusable progress bar (LEFT/RIGHT scrub, UP/DOWN leave), Prev/Next, ±10 s, fullscreen; three interaction modes; deterministic BACK; disabled controls skipped; hidden controls `ExcludeFocus`-d. Verified on the projector (focus ring renders on controls; timeline scrub).

## Details remote scroll (#2/#3)

Movie/Series detail plot + cast are otherwise-unfocusable text below the fold. Added a shared **`ScrollFocusStop`** (visible focus tint + `Scrollable.ensureVisible`) so D-pad can land on and scroll them into view; episodes/season chips were already focusable. Code + unit tests in place; on-device confirmation pending (low risk — same mechanism as the login QA-card scroll, which is verified).

## Windows / macOS

Same `isDesktopClass` large-screen layout path (sidebar, adaptive Live/Home widths, `LayoutBuilder`/clamp constraints that survive resize). **macOS**: build path unaffected (TV changes gate on `isTv`, false off-Android-TV); resize QA pending. **Windows**: no host attached to the agent — covered by shared-layout parity + code review; live resize QA **pending a Windows host**.

## Regression

`flutter analyze` clean · `flutter test` **106 passed** (1 skipped live-backend), incl. new `large_screen_test.dart` (login height/first-focus, LiveChannelRow states, ScrollFocusStop) and `tv_player_focus_test.dart`. Phone bottom-bar + touch player (double-tap seek, drag scrub) unaffected (all TV/large-screen changes gate on `isTv`/`isDesktopClass`).

## Addendum iteration — density, Live/VOD remote split, focus memory (TV emulator QA)

QA target this iteration = **Android TV emulator** (`abk_google_tv`, leanback, logical 960×540). Projector reserved for owner QA.

| Area | Result |
|---|---|
| **TV login density** — full form (logo, title, username, password, Login, QA card) fits ONE viewport, **no scroll** | **PASS** (emulator). Compact: logo 32, title→sectionTitle, field value 20 dp / minHeight 40 / pad 6, button pad 10, gaps s8, QA card pad s8, form maxWidth 400 |
| **Live list density** — smaller text, more rows, less truncation | **PASS** (emulator: ~10 channels visible). Channel name 19 dp, row 56, logo 40; category 20 dp, row pad 8; cols cat 200/232, ch clamp(W·0.28,248,340), preview still dominant (≥51%) |
| **Live remote = DIRECT (fullscreen only)** — OK=play/pause, UP/DOWN=prev/next channel, LEFT/RIGHT=media volume (native `AudioManager` channel `abk/tv`); embedded 3-pane keeps list navigation | implemented; direct handler intercepts before traversal; **projector owner QA for rapid switching** |
| **VOD player = focus-based**, unchanged | retained |
| **Player focus memory** — auto-hide then re-show RESTORES the last-focused control (not reset to Play/Pause); falls back to Play/Pause only if it's gone / first show | **PASS** (unit test `focus memory — auto-hide then re-show RESTORES the last control`) |
| Regression | `flutter analyze` clean · **107 tests** pass (added focus-memory test) |

**Windows true-fullscreen (addendum §12): NOT YET DONE** — needs desktop window management (title-bar/chrome hidden, display fully occupied). No Windows host attached to the agent; recommended approach is the `window_manager` package (or native `NSWindow.toggleFullScreen` / Win32) driven by the existing `_fullscreen` toggle, preserving the same playback session. Deferred to a focused desktop follow-up (macOS verifiable locally, Windows needs a host).

## Production-grade density reset (TV emulator QA)

Owner rejected TV Home/Login/Live as "scaled-up desktop." Reset the TV density from first principles (TV = type-ramp index 3 ONLY; desktop is index 2, untouched):

- **Type ramp (TV):** hero 68→40, pageTitle 44→32, sectionTitle 30→20, cardTitle 24→16, body 24→18, metadata 20→13, caption 20→14, button 26→16.
- **Tokens (TV):** posterWidth 228→**124**, gridGap 24→**16**, contentMargin 64→**40**, sectionGap 56→**36**.
- **Home:** Movies/Series rail 420→**232**; Continue 340×250→**240×188**; Favorites 132→**100**; Live categories 230×160→**184×128**; hero cap 52%→**42%** (clamp 220–400); poster play-chip 26→15; hero buttons pad 18/11→14/9, gap 12→10.
- **Nav rail:** TV labelled width 320→**220** (icon-only 72 below desktop width) — no longer balloons and steals content width.

| Screen | Before | After |
|---|---|---|
| Home posters/row @960 | ~3 (starved-large) | **~6** (streaming-TV thumbnails) |
| Home hero | ~half+ screen, giant year | compact ~42%, year = small caption |
| Home section titles / buttons | oversized | 20 dp / compact |
| Live list | dense (prior iter) | denser, ~10 ch + ~9 cats |
| Login | fit, but large | fit, tighter (title 20, fields 20 dp) |

Verified on the `abk_google_tv` emulator (960×540): Home now shows 6 posters/row with a compact hero (the "before/after" is dramatic — 3→6 cards, giant→small year). `flutter analyze` clean · **107 tests** pass.

## Real TCL Google TV — remote/keyboard closure

Device: **TCL Smart TV Pro (G10)**, Android 12 / API 31, Google TV, 3840×2160→render 1920×1080, density 320 → logical 960×540 (dpr 2.0), ABI armeabi-v7a (needs the universal APK).

| Area | Result |
|---|---|
| **First frame** (the TCL-specific bug) | **PASS** — cold launch shows the dark branded splash then login; NO white flash, NO black-nothing (native launch dark day+night + splash-first). |
| Login density | **PASS** — compact, fits one viewport, username focused on frame 1. |
| **TV keyboard (was: not navigable)** | **FIXED** — the system leanback IME is not D-pad-navigable inside a Flutter view here (`mCurrentFocus` stays the app window; the IME's key never moves; nothing types). Replaced with an in-app D-pad keyboard (`tv_keyboard.dart`) shown from `AbkTextField`/`SearchField` on TV: keys are real focus targets, D-pad moves between them, OK types, Shift/Backspace/Space/Done work. Verified typing "qw"/"qq". |
| **BACK while keyboard open (was: exits app)** | **FIXED** — the keyboard is a bottom-sheet route, so BACK closes it and stays on login (app does not exit). Guarded the field (`disabled` while the sheet is open + re-focus after) so typing can't steal focus back and break the single-BACK close. |
| Field-to-field nav | **PASS** — DOWN traverses username→password→Login→QA card. |
| QA autofill → Login | **PASS** — OK on QA fills + focuses Login; OK signs in → Home (remote-only). |
| Focus visibility | **PASS** — white ring + gold glow unmistakable on fields, buttons, keys. |

Remaining TCL QA (in progress): Search keyboard path, Home/Live/Details/Player remote traversal, dialogs, Release stress.

## Status

- REAL TV LOGIN: **CLOSED**
- TV FIRST-FRAME / FOCUS (projector): **CLOSED**; TCL: **pending owner cold-launch validation**
- LARGE-SCREEN RESPONSIVENESS (TV/macOS): **CLOSED** (TV); macOS resize + Windows: **pending host**
- LIVE EMBEDDED PREVIEW: **CLOSED**
- LIVE FULLSCREEN SAME-PLAYER (video-only): **CLOSED**
- TV REMOTE UX / FOCUS VISIBILITY: **CLOSED**
- Details remote scroll: code CLOSED, on-device confirmation pending
