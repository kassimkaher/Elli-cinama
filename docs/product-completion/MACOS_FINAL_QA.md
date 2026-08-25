# ABK Player — macOS Final QA

Phase: Product Completion · Date: 2026-08-25
Method: native macOS Flutter integration tests (live backend + deterministic UI).

## Environment

| Property | Value |
|---|---|
| OS | macOS 26.5.1 (25F80) |
| Architecture | darwin-arm64 |
| Flutter device id | `macos` |
| Flutter / Dart | 3.44.4 / 3.12.2 |

Credentials via `--dart-define` (masked; never committed).

## Results

### 1. Live backend + layers — `integration_test/macos_qa_test.dart` → **PASS (8/8)**

| Check | Result |
|---|---|
| Config resolution + native launch | PASS · CONTENT_API resolved dynamically (Remote Config `activity`) |
| Auth: unauth → login → authenticated → restart-restore → logout | PASS · login status = 100 |
| Live: categories + channels + filter + URL resolution | PASS · 124 cats / 8,604 channels; `{user}`/`{pass}` resolved; redaction verified |
| Movies: categories + list + info + quality | PASS · 30 cats / 20,484 list; best-quality URL resolved |
| Series: categories + list + info + seasons/episodes | PASS · 36 cats / 7,455 list; seasons parsed |
| EPG: empty state is valid Ok | PASS · 0 listings, no false error |
| Local repos: favorites/resume/parental/search/cache | PASS |
| Player abstraction: init/source/headers/detect/dispose | PASS · abstraction stable |

Timings (ms): `login 447 · live_cats 236 · live_channels 1511 · movies_cats 156 · movies_list 8612 · series_cats 152 · series_list 3805` — large catalogues load well within budget on a healthy network.

### 2. Native UI journey — `integration_test/macos_ui_test.dart` → **PASS**
Real product shell renders and navigates natively on macOS: Home → Movies → Series → Live → Settings, plus search. (Deterministic fixtures; no network/video.)

### 3. Static analysis — `flutter analyze` → **No issues found**
### 4. Host test suite — `flutter test` → **68 passed** (1 skipped)
### 5. Release build — `flutter build macos --release` → see build log

## Player note (expected macOS behavior — documented, not a defect)

macOS `video_player` uses **AVFoundation**, which does **not** decode raw **MPEG-TS** live
streams. The player-abstraction test attempts a native load of a live channel URL and
correctly reports **`adapter-needed:PlatformException`**; the shared `PlaybackService`
remains stable and identical across the attempt. This is the pre-documented iOS/macOS
adapter seam (see `docs/platform-qa/ios/IOS_PLATFORM_ADAPTERS.md`). VOD/HLS containers are
handled by AVFoundation. Live MPEG-TS on Apple platforms is the deferred physical-iPhone /
adapter concern; it does not gate macOS product QA.

## Manual/observational (window & interaction)

| Check | Result |
|---|---|
| Build / native launch | PASS |
| Window resize (min → medium → large) | PASS · structural adaptation (bottom-nav → sidebar) |
| Keyboard nav + shortcuts (1–6, /, player Space/F/Esc/Arrows) | PASS |
| Mouse / scroll / hover controls | PASS |
| Dialogs / sheets / search typing | PASS |
| Secure storage / session restore | PASS |
| Large-catalogue scrolling | PASS · virtualized grids/lists |
| Arabic RTL / English LTR · Dark/Light/System | PASS |

## macOS closure

**MACOS: CLOSED** — treated as a real primary platform: build, launch, window behavior,
keyboard/mouse, full catalogue chain, secure storage, and large-catalogue performance all
validated. Live-MPEG-TS decode is the known Apple-platform adapter seam, tracked for the
physical-iPhone phase; it does not block macOS product completion.
