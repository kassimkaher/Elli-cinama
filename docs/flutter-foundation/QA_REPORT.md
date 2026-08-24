# ABK Flutter — Phase 1 QA Report

Date: 2026-08-24. Credentials supplied via environment / `--dart-define`;
redacted from all output. No secrets in source (scan clean).

## Summary

| Area | Result |
|---|---|
| Static analysis (`flutter analyze`) | **PASS** — No issues found |
| Unit tests | **PASS** — 54/54 |
| Data-layer integration (live backend, VM) | **PASS** |
| Real-device Flutter integration | **PASS** (nubia NX679J) |
| Secret scan | **PASS** — clean |
| Large-catalogue handling | **PASS** |

## Unit tests (54, `flutter test test/unit`)

Coverage: XOR codec (empty/ASCII/JSON/long-wraparound/unicode/involution/empty-key);
content client (object/list decode, form-POST shape, HttpFailure/EmptyResult/
ParseFailure mapping, 20k-item off-isolate decode); config resolution (valid/
empty/invalid-scheme/default-fallback/refresh); request builder (login + envelope);
redaction (secrets, URL-encoded, url params); auth (AccountModel + success flags,
session persistence, repository success/logical-failure/restore); live parsing +
literal URL resolver (incl. regex-special credentials); movie parsing + quality
selection; series parsing (seasons/episodes, backdrop list vs string); EPG (Base64
title, empty-state Ok, 403→HttpFailure, UA sent); local repos (favorites, resume
ordering, parental lock, cache staleness).

## Data-layer integration (live, `test/integration/backend_integration_test.dart`)

Ran the full chain from Flutter code against `https://header21.b-cdn.net`:

| Step | Result | Evidence (sanitized) |
|---|---|---|
| Login | PASS | `status=100`, rewrite_user=false, streaming host `domaio40.hype04.site` |
| packages | PASS | 124 categories |
| channels | PASS | 8,604 total; 8,604 with `stream_url`; 8,604 templated |
| live stream reachability | PASS | `http=200`, `video/mp2t` (MPEG-TS); URL redacted `…/***/***/308779` |
| movies | PASS | cats=30, list=20,484, `movies_info.stream_url` object best=present |
| series | PASS | cats=36, list=7,455, seasons parsed |
| EPG | EMPTY-SUPPORTED | reachable, listings=0 (account `has_epg=0`) — treated as Ok |

## Real-device Flutter integration (`integration_test/app_test.dart`)

| Property | Value |
|---|---|
| Device | nubia **NX679J** |
| Serial | bf5c6761 |
| Android | 13 (API 33) |
| Screen | 1080×2400, density 480 (xxhdpi) |
| Build | assembleDebug OK (~44s), installed, ran |
| Result | **PASS** — bootstrap → login (authenticated) → live categories & channels > 0 → logout (secure session cleared) |

Verified on real hardware: Remote Config resolve, secure storage (session
persist + clear on logout), device envelope, and the content client crossing all
app layers.

## Playback smoke

Live URL resolved via literal `{user}`/`{pass}` substitution reached the panel
and returned MPEG-TS (`video/mp2t`, HTTP 200) with the account User-Agent. The
`PlaybackService`/`PlaybackSourceFactory` abstraction is available for the UI
phase (no final player UI built).

## Performance observations

- End-to-end live chain (login → packages → channels → stream probe → movies →
  series → EPG) completed in ~26 s wall-clock, dominated by network + a 15 s
  media-probe wait, not parsing.
- Large responses (8,604 channels; 20,484 movies) decode **off the UI isolate**
  (`compute`, >64 KB threshold), so the UI isolate never blocks on XOR+JSON.
- No demonstrated bottleneck required fixing. Deferred to the UI phase: lazy grid
  rendering and image loading (out of scope here).

## Security scan

- No credentials in `lib/`, `test/`, `integration_test/`, or `pubspec.yaml`.
- Secrets only in secure storage; redactor scrubs credentials (and URL-encoded
  forms / credential URL params) from all logs.
- Debug APK built with `--dart-define` creds was deleted post-run; `build/` is
  gitignored. No legacy anti-repackaging code, native library, or unnecessary
  cleartext config in source.

## Unresolved / notes

- EPG returns no data for this account (`has_epg=0` everywhere) — transport
  verified; the model is exercised via unit tests with synthetic listings.
- Panel requires a valid User-Agent (403 on unknown) — handled for stream + EPG.
- `device_info_plus` emits a Kotlin-Gradle-Plugin deprecation warning (build
  succeeds); revisit at a future Flutter upgrade.
- No iOS device available; iOS target scaffolded but untested this phase.

---

## macOS QA Closure (Phase 1B)

Native macOS is the primary dev/QA platform. Full detail:
[`MACOS_QA_CLOSURE.md`](MACOS_QA_CLOSURE.md).

| Gate | Result |
|---|---|
| Environment | macOS 26.5.1 · arm64 · Flutter 3.44.4 · Dart 3.12.2 |
| `flutter analyze` | PASS |
| Unit + widget tests | PASS — 55 |
| `flutter build macos` | PASS (`abk_player.app`) |
| Native launch | PASS |
| Remote Config | PASS — resolved rotated value `header26.b-cdn.net` |
| Authentication / session | PASS (login 100, restart-restore, logout-clear) |
| Live | PASS (124 / 8,604) |
| Movies | PASS (30 / 20,484) |
| Series | PASS (36 / 7,455) |
| EPG | EMPTY-SUPPORTED |
| Secure storage | PASS (legacy keychain; resilient) |
| Local persistence | PASS |
| Player abstraction | PASS WITH PLATFORM ADAPTER (native MPEG-TS needs desktop adapter) |
| Desktop window/input | PASS |
| Large catalogue | PASS (off-isolate decode; login 346ms, movies 6.6s) |
| macOS integration tests | PASS — 8 |
| Secret scan | PASS |

**Defects fixed:** (1) added macOS `network.client` entitlement; (2) secure
storage `-34018` → legacy keychain + resilient datasource; (3) removed a
`flutter create`-regenerated default widget test.

**macOS Phase 1 QA gate: CLOSED.** Ready for Cloud Design → Flutter UI.
