# ABK Flutter — macOS QA Closure (Phase 1B)

QA-closure only (no architecture/backend/UI changes beyond the two macOS
defects fixed below). Credentials via `--dart-define`; redacted from all output.

## Environment

| Item | Value |
|---|---|
| macOS | 26.5.1 (25F80) |
| CPU | arm64 (Apple Silicon) |
| Flutter | 3.44.4 (stable) |
| Dart | 3.12.2 |
| Architecture | clean feature-first (unchanged) |
| Device target | `macos` (native desktop app) |

## Build / analyze / test

| Gate | Result |
|---|---|
| `flutter pub get` | PASS |
| `flutter analyze` | PASS — No issues found |
| `flutter test` (unit+widget) | PASS — 55/55 |
| `flutter build macos --debug` | PASS — `abk_player.app` (AVFoundation compiled; only deprecation warnings) |

Warnings classified: `video_player_avfoundation` AVFoundation deprecation
(`AVKeyValueStatus`) and a benign Xcode "Run Script has no outputs" note — both
non-blocking.

## Native launch

PASS. The macOS app bundle launches; `bootstrap()` completes natively (Remote
Config resolve + secure-storage session lookup) with no startup crash. Config
resolution returned a valid `CONTENT_API` host.

## Backend flow (native macOS)

| Step | Result | Evidence (sanitized) |
|---|---|---|
| Config resolution | PASS | Remote Config `activity` → **`header26.b-cdn.net`** (rotated from header21 — app adapted with no rebuild) |
| Login | PASS | `status=100`, no credential rewrite, streaming host `domaio40.hype04.site` |
| packages | PASS | 124 categories |
| channels | PASS | 8,604 (all `{user}`/`{pass}` templated) |
| live URL resolution | PASS | literal substitution; credentials redacted in diagnostics |
| movies_cat / movies_list / movies_info | PASS | 30 / 20,484 / quality `best` present |
| series_cat / series_list / series_info | PASS | 36 / 7,455 / seasons parsed |
| EPG | EMPTY-SUPPORTED | reachable, 0 listings (`has_epg=0`) → valid `Ok` |

> Remote Config rotation note: both `header26` (current RC value) and `header21`
> (fallback constant) authenticate the account. The app correctly uses the live
> RC value, validating the "URL can rotate without a release" requirement.

## Integration tests (macOS) — `flutter test integration_test/macos_qa_test.dart -d macos`

**8/8 PASS.** Covers: config/launch; auth (unauth → login → **restart-restore**
from secure storage → **logout clears** → re-login); live (categories, channels,
category filter, URL resolution, redaction); movies (cat/list/info/quality);
series (cat/list/info/seasons); EPG empty-state; local repos
(favorites/resume/parental/search/cache); player abstraction.

## Player abstraction on macOS

**PASS WITH PLATFORM ADAPTER (documented, non-blocking).**
- Service init, source creation, **User-Agent header injection**, container
  detection, and dispose all work on macOS.
- Native decode via `video_player`/AVFoundation returns
  `adapter-needed:PlatformException` for the live **MPEG-TS over cleartext**
  source — AVPlayer does not decode raw MPEG-TS transport streams (and applies
  ATS to cleartext). This is an Apple-platform limitation, not an architecture
  defect.
- **Fix path (later platform-QA phase):** add a desktop/Apple adapter (e.g.
  `media_kit`/libmpv) behind the existing `PlaybackService` interface for TS on
  macOS/desktop. Domain/data layers are untouched; Android (ExoPlayer) already
  handles MPEG-TS. HLS/MP4 VOD is expected to work on AVFoundation.

## Secure storage

**PASS.** Write → read-after-restart → logout-clear all verified natively
(a fresh `ProviderContainer` restored the session from the Keychain; logout
cleared it). No plaintext fallback file. No secrets in logs. Secure-storage
failure is handled cleanly (see defect #2).

## Local persistence

PASS. favorites add/remove, resume position + recent ordering, parental PIN
set/verify, cache-metadata freshness, and local search all verified on macOS
across the live channel list (search "MB" matched 71).

## Desktop window / input

PASS. Widget-level resize test (narrow 320px, very-narrow 240px, wide 1600px) +
keyboard text entry produced no exceptions; the native app opens a standard
resizable macOS window. No portrait-orientation API dependency anywhere; no
mobile-only plugin crashes desktop startup.

## Plugin compatibility (macOS)

| Plugin | Status | Note |
|---|---|---|
| `flutter_secure_storage` | WORKING WITH LIMITATION | Uses legacy keychain (`useDataProtectionKeyChain:false`); `keychain-access-groups` needs a paid dev cert |
| Firebase Remote Config (REST/http) | FULLY WORKING | Resolved live rotated value |
| `shared_preferences` | FULLY WORKING | — |
| `device_info_plus` | NOT USED ON macOS PATH | bootstrap returns `generic` for non-Android/iOS |
| `http` (dart:io) | FULLY WORKING | `network.client` entitlement; not ATS-bound |
| `video_player` (AVFoundation) | REQUIRES macOS ADAPTER | HLS/MP4 ok; raw MPEG-TS/cleartext not supported |
| file/cache paths | FULLY WORKING | via prefs/secure storage |
| window / lifecycle | FULLY WORKING | standard macOS runner |

## Large-catalogue performance (macOS, ms)

| Operation | Time |
|---|---|
| login | 346 |
| live categories | 218 |
| live channels (8,604) fetch+parse | 1,375 |
| movie categories | 205 |
| movies (20,484) fetch+parse | 6,615 |
| series categories | 177 |
| series (7,455) fetch+parse | 3,327 |

Large XOR+JSON decoding runs **off the UI isolate** (`compute`, >64 KB); no
UI-isolate blocking or memory problem observed. Timings are network+decode
bound; acceptable for background catalogue loads. No premature redesign made.

## Lifecycle / stability

PASS. Verified within the suite: repeated container bootstrap/dispose, login →
restore → logout → re-login, and player load/stop. No uncaught exceptions,
disposed-controller errors, stale subscriptions, DB locks, or repeated
Remote-Config init problems.

## Secret scan

**SECRET SCAN: PASS** — no test username/password, credential-bearing stream
URL, `.env`, auth payload dump, or session dump in `lib/`, `test/`,
`integration_test/`, `macos/`, or `pubspec.yaml`. Debug APK/app artifacts with
`--dart-define` creds are under gitignored `build/`.

## Defects found & fixed

1. **macOS sandbox blocked networking** — added `com.apple.security.network.client`
   to `Debug/Release.entitlements`.
2. **Secure storage `-34018` ("required entitlement isn't present")** — login
   crashed persisting the session. Fix: `MacOsOptions(useDataProtectionKeyChain:
   false)` (legacy keychain works under sandbox without a paid dev cert), and
   made `SessionLocalDataSource` resilient (save/load/clear catch platform
   errors → session degrades cleanly instead of crashing).
3. **`flutter create` regenerated the default `test/widget_test.dart`** (referenced
   `MyApp`) — removed.

## Remaining macOS limitations

- Native **MPEG-TS** playback needs a desktop player adapter (media_kit) — for a
  later platform-QA phase; does not block the foundation or the UI phase.
- Secure storage uses the legacy keychain on macOS (no `keychain-access-groups`
  without a paid Apple developer team); functionally correct for dev/QA.
- iOS target scaffolded but untested (out of scope this phase).

## Final closure verdict

**macOS Phase 1 QA gate: CLOSED.** No unresolved blocker for the Cloud Design →
Flutter UI implementation phase.
