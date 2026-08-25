# Android TV / Google TV — QA Report

## Environment
- **Emulator:** `abk_google_tv` AVD, **Google TV**, `system-images;android-34;google-tv;arm64-v8a` (API 34), device profile `tv_1080p`.
- **Resolution:** 1920×1080 (1080p baseline).
- **Detection:** device reports `android.hardware.type.television` + `android.software.leanback` → `AbkBreakpoints.isTv = true` (verified on the emulator).
- Host: Apple Silicon (arm64).

## Automated
- **`integration_test/tv_emulator_test.dart`** (on the Google TV emulator): app **detected as TV**, renders the **sidebar** (not the phone bottom bar), D-pad traversal retains focus.
- **`test/widget/tv_navigation_test.dart`** (deterministic): `AbkFocusable` activates on **SELECT (D-pad centre)** and **ENTER** and shows a **focus ring**; TV shell uses the sidebar and keeps focus during D-pad traversal; phone shell keeps its bottom bar (TV nav does not pollute phone).
- `flutter analyze` clean · `flutter test` **88 passed**.

## Feature checklist (TV presentation)
| Area | Result |
|---|---|
| TV launcher entry (LEANBACK_LAUNCHER) | present in manifest; APK also installs on phones |
| Touchscreen not required | `required="false"` |
| TV banner | `res/drawable/tv_banner.png` (320×180), ABK identity |
| TV detection → 10-foot mode | ✅ (system features) |
| Sidebar navigation (Home/Live/Movies/Series/Favorites/Settings + Search) | ✅ |
| Focus visible (ring + scale) | ✅ (`AbkFocusable`) |
| Focus retained / not lost | ✅ (directional mode) |
| D-pad Up/Down/Left/Right/Select/Back | ✅ mapped |
| Home rails browsable by D-pad | ✅ (rails/grids are focusable) |
| Live categories/channels/switch, EPG | ✅ shared Live UI (three-pane at TV width) |
| Movies grid/detail/play | ✅ shared, desktop-class grid at TV |
| Series/seasons/episodes/next episode | ✅ shared |
| Continue Watching / resume | ✅ shared |
| Search (remote-focusable field + results) | ✅ shared |
| Settings + dialogs (parental PIN, logout, theme/lang) | ✅ shared, focusable |
| Player remote (see remote spec) | ✅ OK/seek/switch/back mapped, `PopScope` back |

## Layout fixes made for TV
- TV sidebar widened to 320 dp and labels ellipsis-flex → **no clipping/overflow** with the
  larger 10-foot type (the only overflow found at 1080p, now fixed and asserted by the test).
- `minHitTarget` returns **64** on TV (large remote focus targets).

## Focus stress (observational + automated)
- Rapid D-pad traversal, long rows/grids, dialog open/close, screen back-and-forth: focus is
  retained (directional mode, `IndexedStack` preserves section state). No focus trap, no
  invisible focus (ring always drawn), no focus behind overlays (controls layer is topmost).

## Performance
- Posters use the shared cached `AbkImage` with lazy rails/virtualised grids; no eager
  full-catalogue image loads; animations limited to focus scale/ring (cheap). Suitable for
  mid-range Android TV hardware. Large catalogues (8,604 channels / 20k movies) stay in
  lazy lists.

## Regression
- Android phone: player + navigation unchanged (bottom bar retained on phone; verified by
  `tv_navigation_test`); `android_playback` + `player_ui` remained green in the prior phase.
- macOS/iOS: builds + player unaffected (TV changes are Android-manifest + shared adaptive
  layout gated on `isTv`, which is false off Android TV).

## Status
**ANDROID TV / GOOGLE TV: EMULATOR CLOSED** · Remote navigation, TV player UX closed on the
Google TV emulator. **REAL GOOGLE TV / PROJECTOR: READY FOR OWNER QA** (no physical TV
attached to the agent) — see `REAL_TV_PROJECTOR_QA_CHECKLIST.md`.
