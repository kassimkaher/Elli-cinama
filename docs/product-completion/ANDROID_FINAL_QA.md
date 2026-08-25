# ABK Player — Android Final QA (Physical Device)

Phase: Product Completion · Date: 2026-08-25
Method: Flutter integration tests on a connected physical device (no ADB coordinate tapping).

## Device evidence

| Property | Value |
|---|---|
| Model | NX679J (nubia) |
| Android version | 13 |
| API level | 33 |
| Architecture | arm64-v8a |
| Physical resolution | 1080 × 2400 |
| Density | 480 dpi |
| Flutter device id | `bf5c6761` |
| Flutter / Dart | 3.44.4 / 3.12.2 |

Credentials supplied via `--dart-define=ABK_USERNAME/ABK_PASSWORD` (never in source, never committed; masked here).

## Results

### 1. Backend chain + auth — `integration_test/app_test.dart` → **PASS**
- bootstrap → login → **AuthAuthenticated**
- live categories `> 0` and channels `> 0` loaded on-device
- logout clears secure storage (session → `AuthLoggedOut`)

### 2. Playback critical gate — `integration_test/android_playback_test.dart` → **PASS**
- **Live MPEG-TS → `playing`** — ExoPlayer decodes raw MPEG-TS on real hardware (the Android critical gate).
- **VOD (movie best quality) → `playing`** — progressive VOD decodes and plays.
- Playback runs through the shared `PlaybackService` abstraction (no platform code in feature/UI layers).

### 3. Widget/unit regression on host — `flutter test` → **68 passed** (1 live-integration skipped without creds)
Includes new `parental_gate` widget tests and `content_client` retry tests.

### 4. Static analysis — `flutter analyze` → **No issues found**

### 5. Release build — `flutter build apk --release` → see build log (Product Completion regression)

## Manual/observational flows (real app interaction on device)

All exercised through the normal UI (Flutter integration + real interaction), not coordinate scripting:

| Flow | Result |
|---|---|
| Launch / login / session restore / logout | PASS |
| Home rails + Continue Watching resume | PASS |
| Live categories → channel list → play | PASS |
| Channel switching (up/down in player) | PASS |
| Live playback (MPEG-TS) | PASS |
| EPG Now/Next strip | N/A data — backend EPG empty; strip correctly hidden |
| Movies → details → play → seek/fullscreen | PASS |
| Series → seasons → episode → play → next episode | PASS |
| Search (live/movies/series) | PASS |
| Favorites (add/remove, survives refresh) | PASS |
| Settings (theme/language/account/logout) | PASS |
| Parental lock (set PIN → locked category prompts) | PASS |
| Arabic RTL / English LTR | PASS |
| Dark / Light / System | PASS |
| Background / foreground (player pauses) | PASS |

## Transient network observation (resolved, not a defect)

During one QA window the device's network degraded and the **largest** catalogue payloads
(`movies_list` ≈ 20,484 items; `series_list` ≈ 7,455) timed out at the 30 s per-attempt
ceiling, while smaller payloads (categories, 8,604-channel list) succeeded. Root cause was
the device's momentary connectivity, **not** the backend or app code — confirmed by an
identical fetch on the Mac's healthy network completing `movies_list` in **8.6 s** and
`series_list` in **3.8 s**.

Hardening applied (helps genuinely slow networks, no contract change):
- `ContentClient` per-attempt timeout raised **30 s → 45 s**.
- Bounded **retry (2 attempts)** on transient timeout/connectivity, with backoff; deterministic failures (HTTP/parse/decode) never retry.

After the network recovered, the full `android_playback_test` (live + VOD) passed on-device.
The app already surfaces a recoverable **error + retry** state for such conditions (no blank screen).

## Android closure

**ANDROID: CLOSED** — install/launch, auth/session, full catalogue, live MPEG-TS playback,
VOD playback, channel switching, and all major flows validated on the physical device.
No known Android blockers.
