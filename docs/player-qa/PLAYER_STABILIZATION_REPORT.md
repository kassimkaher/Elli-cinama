# Player Stabilization Report

Phase: macOS + Android + iOS player stabilization & viewer QA · Date: 2026-08-25
Flutter 3.44.4 · Dart 3.12.2

## Summary of root causes and fixes

| Area | Root cause | Fix | Verified |
|---|---|---|---|
| **macOS Keychain prompts** | Per-content PIN reads + ad-hoc signing (legacy Keychain re-authorises per signature) | PIN cached in memory (read once); **macOS stores secrets in the App-Sandbox file, not the Keychain** | macOS QA + UI test ran login/restore/logout with no prompt-hang |
| **macOS playback** | AVFoundation cannot decode raw MPEG-TS live | Enabled the **fvp/libmdk** adapter for macOS (behind `PlaybackService`) | `ui live status => playing` on `-d macos` |
| **Android playback** | Not a decode issue (ExoPlayer decodes MPEG-TS). Owner symptoms were lifecycle: audio leak / hang / stuck switching | Player lifecycle rewrite (below) | `ui live status => playing`, switch `playing`, leave releases — on device |
| **Audio leak on leave** | `stop()` only paused; the singleton controller stayed alive | `stop()` now **fully disposes the controller**; player `dispose()` calls it | player widget test + on-device leave check |
| **Hang after live switch + back** | Concurrent `load()` calls raced on the singleton controller; stale async clobbered state | **Debounced switching** (one load per surf) + a **generation token** dropping stale async; dispose invalidates in-flight loads | player widget test (surf → one load) |
| **Unreliable channel switching** | Load race + no visible switching state | Debounce + explicit `switchingSource` phase with visible buffering/target; next/prev always reload the source | on-device switch `playing` |
| **Stuck with no status** | Silent buffering if a switch stalled | Coherent phase model — always a visible state (preparing/buffering/switching/error) | code + tests |
| **Late-event crash** | fvp controller emitted after the state stream closed (`Bad state: add after closing`) | `_emit` guarded + try/catch; controller detached before dispose | macOS run clean after fix |
| **`ref` used after dispose** | Player `dispose()` → `_persist()` read providers via `ref` | Repositories captured in `initState`; dispose uses captured refs | player widget test |

## Player lifecycle & state model (Phase D)

Coherent internal phase, always one visible state — never silent/stuck:

```
preparing → buffering → playing ⇄ paused
          ↘ switchingSource → (buffering → playing | error)
            error → retry
            (leave / logout / dispose) → released
```

- **Source switching** is: current → `switchingSource` (visible target + spinner) → safe
  release/replace (`load()` disposes the prior controller) → prepare → playing OR visible
  error/retry. Rapid presses debounce (320 ms) into a single load.
- **Leaving** (`dispose`) persists progress, cancels timers, invalidates in-flight loads
  (generation bump), and calls `stop()` → the controller is fully released → **no lingering
  audio, no orphan decoder, no reuse of a disposed controller.**
- **Background/foreground:** `didChangeAppLifecycleState` pauses on `paused`/`hidden`.
- **VOD auto-advance** to the next episode on natural completion; guarded against firing
  during a switch.

## Platform playback matrix (real-device)

| Platform | Engine | Live MPEG-TS | Channel switch | Leave releases |
|---|---|---|---|---|
| Android (NX679J, API 33) | ExoPlayer (video_player) | playing | playing | yes |
| macOS (26.5) | fvp / libmdk | playing | playing | yes |
| iOS (iPhone 15, 26.5) | fvp / libmdk | playing | playing | yes |

The `PlaybackService` seam is unchanged in shape; the only platform difference is which
backend `video_player` uses (Android = ExoPlayer; iOS/macOS = fvp). No feature/UI fork.

## Files changed (core)
- `core/player/playback_service.dart` — added `seek()`; documented `stop()` = full release.
- `core/player/video_player_playback_service.dart` — `stop()` disposes controller; `seek()`
  clamped/guarded; `_emit` bulletproofed; `dispose()` idempotent.
- `features/player/player_screen.dart` — rewritten: phase model, debounced switching +
  generation guard, double-tap ±10 s, continuous scrubbing (seek on release), captured
  repos, post-frame open, ±10 s transport + keyboard seek.
- `core/storage/secure_store.dart` — `MacOsFileSecureStore` (sandbox file, no Keychain).
- `core/di/providers.dart` — macOS → `MacOsFileSecureStore`.
- `features/favorites/parental_lock_repository.dart` — in-memory PIN cache + `warmUp()`.
- `app/bootstrap.dart` — fvp for `['ios','macos']` (Apple-guarded); parental `warmUp()`.

## Tests added
- `test/unit/parental_cache_test.dart` — PIN read once; set/clear cache; locks are prefs-only.
- `test/widget/player_test.dart` — stop-on-leave, ±10 s seek, switch debounce (one load),
  error→retry.
- `integration_test/player_ui_test.dart` — real `PlayerScreen` on device: live renders +
  plays, channel switch, leave releases.
