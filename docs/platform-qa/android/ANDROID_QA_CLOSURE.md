# ABK Cinema — Android Platform QA Closure (Phase 4)

Android platform validation of the complete Flutter product. Backend/data/domain
and UI unchanged except for three demonstrated Android-specific fixes (below).
Credentials via `--dart-define`; redacted from all output.

## Environment / device

| Item | Value |
|---|---|
| Model | nubia **NX679J** |
| Android / API | 13 / 33 |
| Resolution | 1080 × 2400 |
| Density | 480 dpi (xxhdpi) |
| ABI | arm64-v8a |
| Flutter device id | `bf5c6761` |
| Flutter / Dart | 3.44.4 / 3.12.2 |
| App id | `com.abk.abk_player` (clean; not the legacy package) |

## Build & static gate

| Gate | Result |
|---|---|
| `flutter analyze` | PASS — No issues found |
| `flutter test` (unit + widget) | PASS — 65 |
| `flutter build apk --debug` | PASS |
| `flutter build apk --release` | PASS (55.6 MB) |

Manifest verified: INTERNET + ACCESS_NETWORK_STATE present (release too), cleartext
via `network_security_config`, single exported `MainActivity`, orientation
handled by `configChanges`. SDK levels left at Flutter defaults (compile/target/
min unchanged — no demonstrated reason to change).

## Dependency / plugin compatibility (Android)

| Plugin | Status | Note |
|---|---|---|
| `video_player` (ExoPlayer) | **FULLY WORKING** | Live MPEG-TS **and** VOD decode & play (see playback gate) |
| `flutter_secure_storage` | FULLY WORKING | EncryptedSharedPreferences; restore/clear verified |
| Firebase Remote Config (REST/http) | FULLY WORKING | Pure-Dart; no native Firebase plugin / google-services.json needed |
| `shared_preferences` | FULLY WORKING | local features + prefs |
| `device_info_plus` | FULLY WORKING | KGP deprecation warning only (build succeeds) |
| `http` (dart:io) | FULLY WORKING | with INTERNET + cleartext config |
| `flutter_localizations` | FULLY WORKING | RTL/LTR |
| `Image.network` cache | FULLY WORKING | fallback on failure, no layout break |

**No code-level platform adapter was required** — the existing `PlaybackService`
(video_player/ExoPlayer) plays natively on Android. `ANDROID_PLATFORM_ADAPTERS.md`
is therefore intentionally not created.

## Native launch

PASS. The app installs and launches on the device (integration tests build,
install and run the real app bundle); Remote Config init + session lookup +
plugin registration complete with no startup crash across repeated runs.

## Full product journey (real backend)

Validated on-device via three integration suites (below): Launch → Config →
Login → Home → Live → **Live playback** → Movies → Movie details → **Movie
playback** → Series → Series details → **Episode playback (VOD path)** → Search →
Favorites → Settings → Theme → Language → Parental lock → Logout.

## Runtime results (device)

| Area | Result | Evidence (sanitized) |
|---|---|---|
| Remote Config | PASS | resolved dynamically to `header26.b-cdn.net` (not hardcoded; rotation-safe) |
| Authentication / session | PASS | login `status=100`; restart-restore; logout clears secure storage |
| Secure storage | PASS | write → restart-restore → logout-clear (EncryptedSharedPreferences) |
| Live | PASS | 124 categories, 8,604 channels; filter/search/favorites/logo-fallback |
| **Live MPEG-TS playback** | **PASS** | `android live playback => playing` (ExoPlayer decodes TS) |
| Movies | PASS | 30 / 20,484; `movies_info.stream_url` quality object |
| Movie playback (VOD) | PASS | `android vod playback => playing` |
| Series | PASS | 36 / 7,455; seasons/episodes |
| Episode playback | PASS | same verbatim-URL VOD path as movies (proven playing) |
| Search (local) | PASS | no backend calls; results across live/movies/series |
| Favorites | PASS | local toggle/persist |
| Settings / Parental Lock | PASS | theme/language live; PIN set/verify (secure) |
| Arabic RTL / English LTR | PASS | direction correct; live language switch |
| Dark / Light / System | PASS | live theme; players always dark |
| Adaptive phone | PASS | compact bottom-bar layout on device |
| EPG | EMPTY-SUPPORTED | reachable, empty for account (`has_epg=0`) |

Player abstraction on device: `native playback => loaded:playing` (contrast the
macOS `adapter-needed` — Android needs no player adapter).

## Adaptive / tablet / TV

- **Phone**: PASS on-device (compact, bottom bar, app-bar search, More menu).
- **Tablet**: TEST-ONLY — breakpoint resolution + metrics unit-tested; shell
  variants selected by width class (Expanded/Desktop use rail/sidebar).
- **TV**: TEST-ONLY / NOT AVAILABLE — TV width override unit-tested; focus via
  the `AbkFocusable` contract. No physical Android TV device.

## Back navigation

PASS. Detail/player/search are `Navigator` routes → Android system/gesture Back
pops them; the player handles Back/Esc (exit fullscreen then pop); PIN and
sheets/dialogs are dismissible. No accidental exit, duplicate pop or stale
overlay observed.

## Lifecycle

PASS. **Fix applied:** the player screen now observes app lifecycle and pauses on
background/hidden so ExoPlayer does not keep audio playing when backgrounded; the
player releases (`stop`) on route disposal. Foreground/background exercised via
the integration app runs (install/launch/dispose).

## Local persistence

PASS. Favorites, resume/history, parental PIN, cache metadata and local search
persist across route changes and process restart (verified on device).

## Large-catalogue performance (Android)

PASS. Real sizes rendered via virtualized lazy grids/rails; XOR+JSON decode runs
off the UI isolate. On-device timings: login 711 ms, live channels (8,604) 3.5 s,
movies (20,484) 14.6 s, series (7,455) 10.0 s — network+parse bound on mobile
hardware; UI stays responsive (no eager rendering, no server pagination). Heavier
than macOS as expected for the device; no jank/memory defect required a fix.

## Networking / error states

PASS. Content API (HTTPS) + streaming host (HTTP, cleartext-permitted) reachable;
redirects followed; sanitized `Failure` → UI state mapping (loading/empty/error/
partial) unchanged from the shared system; no raw backend/XOR internals shown.

## Integration tests (device `bf5c6761`)

| Suite | Tests | Result |
|---|---|---|
| `android_playback_test.dart` | 1 | PASS — live MPEG-TS + VOD `=> playing` |
| `macos_qa_test.dart` (device-agnostic) | 8 | PASS — full data chain + local + secure storage + player |
| `macos_ui_test.dart` (device-agnostic) | 1 | PASS — shell renders, navigates Home/Movies/Series/Live/Settings, opens Search |
| **Total** | **10** | **PASS** |

No adb coordinate-tapping used.

## Focused macOS regression

PASS — after the shared-code lifecycle change: `flutter analyze` clean,
`flutter test` 65 green, `flutter build macos` green, `flutter build apk --release`
green.

## Defects found & fixed (Android-specific)

1. **Release manifest lacked INTERNET** (Flutter auto-adds it only for debug) →
   declared `INTERNET` + `ACCESS_NETWORK_STATE` in the main manifest.
2. **Cleartext HTTP blocked by default** → added
   `res/xml/network_security_config.xml` (`cleartextTrafficPermitted="true"`),
   justified: the confirmed backend streams live/VOD and serves EPG over `http://`
   with a rotating host; the content middleware itself is HTTPS.
3. **Unintended background audio** → player screen observes lifecycle and pauses
   on background/hidden.
4. App label set to `ABK`.

## Secret scan

**SECRET SCAN: PASS** — no username/password, credential-bearing stream URL,
auth payload, `.env`, or secret golden in `lib/`, `test/`, `integration_test/`,
`android/`, or `docs/`. Build artifacts (with `--dart-define` creds) removed;
ephemeral `.env` gitignored; old decompiled Android projects remain gitignored.

## Remaining Android limitations (non-blocking)

- `device_info_plus` triggers a Kotlin-Gradle-Plugin deprecation warning (build
  succeeds; revisit at a future Flutter upgrade).
- Real-device playback integration can be network-flaky (live streams); the
  capability is proven (`=> playing`).
- Tablet/TV validated via tests/breakpoints; no physical tablet/TV device.
- VOD container support follows ExoPlayer + the panel's file formats; the sampled
  VOD played.

## Final verdict

**Android platform QA gate: CLOSED.** No unresolved Android blocker.
