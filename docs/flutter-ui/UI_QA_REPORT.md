# ABK Flutter — Phase 3 UI QA Report (macOS)

Date: 2026-08-25. macOS 26.5.1 · arm64 · Flutter 3.44.4 · Dart 3.12.2.
Credentials via `--dart-define` only; redacted from all output.

## Summary

| Gate | Result |
|---|---|
| Design MCP import & full read | PASS |
| Design/foundation reconciliation | PASS |
| Token system + dark/light/system themes | PASS |
| Adaptive shell + component library | PASS |
| All screens implemented & wired | PASS |
| `flutter analyze` | PASS — No issues found |
| Unit + widget tests | PASS — 65 |
| `flutter build macos` | PASS |
| macOS UI integration | PASS — 1 |
| macOS data-layer integration | PASS — 8 |
| Secret scan | PASS |

## Tests

- **Unit (54)** — foundation (codec, client, config, auth, parsing, resolvers,
  quality, EPG, local repos), unchanged and green.
- **Widget (11)** — dev shell resize/input (1); **design system (10)**: token
  palettes, breakpoint resolution, theme extension, `AbkButton`, `MetadataRow`
  collapse, `RatingBadge` null/0 hide, `PosterCard` render, Arabic RTL + English
  LTR direction.
- **macOS UI integration (1, `integration_test/macos_ui_test.dart`, `-d macos`)**
  — real product shell rendered natively; navigated Home → Movies → Series →
  Live → Settings; opened global Search. Deterministic (fixture catalogue, no
  network/live video).
- **macOS data-layer integration (8, `macos_qa_test.dart`, `-d macos`)** — live
  chain green: login `status=100`; live 124/8,604; movies 30/20,484 (quality
  object); series 36/7,455; EPG empty-Ok; local repos; player abstraction
  (native MPEG-TS → documented desktop-adapter limitation). Timings: login
  346ms, live 1.4s, movies 6.6s, series 3.3s — off-isolate decode, no UI block.

## Visual / design checks (against the MCP master)

- Tokens/theme/type/motion implemented exactly from §03–06; dark = cinema,
  light = designed warm-paper (card borders, darkened accent); players/launch/
  login always dark (`AlwaysDark`).
- Component variants and states (hover/focus/pressed/selected/disabled/locked/
  loading/light) via one `AbkFocusable` contract (§06/§07).
- Shell/navigation per §08 (bottom bar / labelled sidebar / icon rail; More
  menu; `/` search; 1–6 jump).
- Exemplar screens (Launch/Login/Home/Live/Live Player) follow the master
  layouts; feature screens extrapolate the same system (see DESIGN_MCP_MAPPING).

## Adaptive checks

- Width classes Compact/Medium/Expanded/Desktop/WideDesktop + TV override
  resolve and drive metrics (unit-tested). Shell `IndexedStack` preserves active
  destination/scroll/selection across resize. Content caps at 1680.
- Desktop resize/keyboard/mouse verified via the macOS build + UI test; the dev
  shell resize/input test (narrow 240 → wide 1600) passes without exceptions.

## RTL / LTR · Dark / Light

- Arabic RTL and English LTR both render with correct direction (widget-tested).
  Language + theme switch live via persisted controllers. Dark/Light both build
  and are exercised in tests/build.

## Large catalogue

- Live 8,604 / Movies 20,484 / Series 7,455 rendered via virtualized lazy
  grids/rails (`AdaptivePosterGrid`, `PosterRail`); local search/filter over
  cached lists; XOR+JSON decode off the UI isolate. No server pagination, no
  eager rendering. Responsive on macOS with real data (data-suite timings above).

## Playback

- Unified `PlayerScreen` (live + VOD) on the existing `PlaybackService`: overlay
  auto-hide, play/pause, VOD seek/timeline, fullscreen, buffering/error/retry,
  live identity, keyboard (Space/F/Esc/←→). Native MPEG-TS decode on macOS
  AVFoundation returns `adapter-needed` (Phase 1B platform-adapter note,
  unchanged); the player UI and all states function.

## Defects fixed during Phase 3

1. Missing provider imports in several UI files → added.
2. Settings ListTiles inside coloured Containers threw a debug "ink invisible"
   assertion → wrapped groups in a transparent `Material`.
3. macOS UI test needed `sharedPreferencesProvider`/`deviceModel` overrides for
   the settings/session graph → added.
4. Data-suite auth test made robust to a leftover Keychain session (logout
   first) — test isolation, not a product defect.

## Secret scan

**PASS** — no credentials in `lib/`, `test/`, `integration_test/`, or `docs/`;
build artifacts (with `--dart-define` creds) removed; ephemeral `.env` files
carry no secrets and are gitignored; no `.env` tracked.

## Remaining (non-blocking)

- Native MPEG-TS live playback on Apple/desktop needs a `media_kit`/libmpv
  adapter behind `PlaybackService` (later platform-QA phase; Android ExoPlayer
  already decodes TS).
- Google fonts fall back to the platform stack unless bundled (scale/weights are
  exact).
- Phone/tablet/TV variants are implemented in the architecture; their full
  runtime QA is a later platform phase (this phase is macOS-first).
