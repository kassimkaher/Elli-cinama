# ABK — Adaptive Behaviour

Width classes resolve from available width; a D-pad primary input forces the TV
class at any width (Design §02). `AbkBreakpoints.resolve(width, {tv})`.

| Class | Width | Navigation | Content |
|---|---|---|---|
| Compact | < 600 | bottom bar (Home/Live/Movies/Series/More), app-bar search | single column, 3-up posters, sheets for filters |
| Medium | 600–904 | bottom bar / rail | 5-up posters |
| Expanded | 905–1279 | icon rail sidebar + category column | 6-up grid; Live 3-pane where width allows |
| Desktop | 1280–1727 | labelled sidebar (Settings pinned), title-bar search `/` | 7-up grid, Live three-pane with preview, hover + keyboard |
| WideDesktop | ≥ 1728 | sidebar, content capped 1680 & centred | grid stops growing, gutters absorb |
| TV (override) | any + D-pad | expanding side rail, no bottom bar | 10-foot type, focus-driven, safe margins |

## Per-class metrics (implemented)

contentMargin 16/24/32/40/40/64 · gridGap 8/12/16/20/20/24 · sectionGap
32/36/40/48/48/56 · posterWidth 108/132/150/164/164/228 · posterColumns
3/5/6/7/8/7 · minHitTarget 48/48/48/32/32/64.

## Desktop window (macOS-first)

- Resizable; grids reflow by **column count**, never by scaling cards (poster
  width fixed per class, gutter absorbs remainder). Content caps at 1680 and
  centres above 1728.
- The shell uses an `IndexedStack` of the six destinations, so switching classes
  (resize) **preserves** the active destination, per-screen scroll position and
  in-screen selection (category/channel) — never resets to the top of 20k titles.
- Sidebar: labelled ≥1280 → icon rail <1280 → bottom bar <905. Keyboard: 1–6
  jump to destination, `/` focuses search; player Space/F/Esc/←→.
- Fullscreen is a window state (immersive), not a layout class.

## Input models

Touch (48dp targets, long-press quick actions), Mouse (hover raises card +
reveals inline play; right-click quick actions), Keyboard (full tab order,
visible focus ring, arrows in grids, shortcuts), D-pad (something always focused,
horizontal index remembered, focus ring + scale). All via one `AbkFocusable`
contract so nothing is reachable by a single input only.

## RTL / LTR (Design §80/§81)

Arabic RTL is primary; English LTR supported. Direction follows the app locale
through `flutter_localizations`. Layout, navigation and alignment mirror;
artwork and play/pause are never mirrored; progress bars stay semantically
correct. `MetadataRow` keeps numerals LTR while reversing order in Arabic.
Language switches live without restart. Type bumps +2dp / +0.35 line-height for
Arabic.

## Reduced motion & accessibility

`MediaQuery.disableAnimationsOf` drops scale/translate (opacity only), turns
shimmer static, and shows focus by ring alone. Focus rings are visible on
keyboard/TV. Badges carry text equivalents (never colour-only). Contrast targets
per Design §03.
