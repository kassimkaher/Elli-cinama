# Android TV / Google TV — Implementation

One shared Flutter app + one backend. TV work is **presentation, navigation, remote input,
and launcher config only** — auth, repositories, models, playback state, favorites, search,
continue-watching, and Live/Movie/Series logic are unchanged and shared.

## Manifest changes (`android/app/src/main/AndroidManifest.xml`)
- `LEANBACK_LAUNCHER` category added to the main activity's intent-filter (alongside the
  normal `LAUNCHER`) → the app appears in the Android TV / Google TV launcher **and** on
  phones/tablets from the same APK.
- `uses-feature android.software.leanback` — `required="false"` (does not exclude phones).
- `uses-feature android.hardware.touchscreen` — `required="false"` (TV has no touchscreen).
- `android:banner="@drawable/tv_banner"` on `<application>` (required for TV launcher).

## TV detection (`app/bootstrap.dart`)
`AbkBreakpoints.isTv` is set once at bootstrap from the device's declared system features
(`android.software.leanback` / `android.hardware.type.television`). Overridable for
emulator/dev via `--dart-define=ABK_FORCE_TV=true`. When true, the whole app renders in the
`WidthClass.tv` 10-foot presentation regardless of the (1080p/4K) window width.

## Adaptive presentation (`core/design/breakpoints.dart`)
- Width classes: `compact · medium · expanded · desktop · wideDesktop · tv`.
- `AbkBreakpoints.of(context)` forces `tv` when `isTv`.
- `isDesktopClass(tv)` and `usesSidebar(tv)` are **true** → TV gets the large desktop-class
  layouts (sidebar nav, poster grids, three-pane Live, two-column details).
- TV-tuned tokens already exist (content margin 64, poster width 228, section gap 56,
  `minHitTarget` **64**, larger type). Not a fixed multiplier — per-token 10-foot values.

## Focus / D-pad (`core/design` + `shared/widgets/focusable.dart`)
- On TV the app runs in `NavigationMode.directional` (set app-wide in `ui/app_root.dart`)
  so a focused element activates with SELECT and focus is never lost.
- `AbkFocusable` (used by cards, posters, sidebar items, etc.) uses `FocusableActionDetector`
  with a strong **focus ring + scale** and activates on **Enter / Space / SELECT (D-pad
  centre) / gameButtonA**.
- Sidebar items converted to `AbkFocusable` for an obvious TV focus treatment; the TV rail
  is widened to 320 dp and labels ellipsis-flex so 10-foot type never clips.

## Navigation model
- TV uses the **labelled sidebar rail** (`_DesktopScaffold`), never the phone bottom bar.
  Destinations are the existing ones: Home, Live, Movies, Series, Favorites, Settings +
  Search. `IndexedStack` preserves each section's state across nav.

## Player remote (see `ANDROID_TV_REMOTE_SPEC.md`)
- Direct D-pad mapping (the standard TV video-player model): OK reveals controls / toggles
  play; ←/→ seek ∓10 s (VOD); ↑/↓ prev/next channel or episode; media Play/Pause & Track
  keys; BACK exits fullscreen → hides controls → leaves (via `PopScope`). Mobile double-tap
  seek and desktop mouse/keyboard behaviour are preserved (additive, not destructive).

## Branding
- The existing ABK mark is reused. `res/drawable/tv_banner.png` (320×180) shows the gold
  mark + "ABK" wordmark + "LIVE · MOVIES · SERIES" on the dark brand tile. No separate TV
  brand. App icon is the shared adaptive launcher icon.

## Shared vs TV-specific
| Shared (unchanged) | TV-specific (added) |
|---|---|
| API, repositories, auth, models | manifest leanback + banner |
| playback state, favorites, search | `isTv` detection + `WidthClass.tv` routing |
| continue-watching, series/movie/live logic | directional navigation mode |
| the one adaptive design system | sidebar focus treatment + rail width |
| the shared `PlayerScreen` | player D-pad/remote key mappings |

No parallel business logic was created.
