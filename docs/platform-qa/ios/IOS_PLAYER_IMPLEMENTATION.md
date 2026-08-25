# iOS Player Implementation

Date: 2026-08-25 · Phase: Physical iPhone Final QA

## Decision: an iOS playback adapter IS required, and is implemented via `fvp`

On real iPhone hardware the current `video_player` (AVFoundation) backend **cannot**
decode the backend's raw **MPEG-TS** live streams. Verified on-device:

```
ios live playback => adapter-needed:PlatformException   # video_player / AVFoundation
```

After adding the adapter:

```
ios live => playing      # MPEG-TS live
ios switch => playing     # channel switch
ios vod => playing        # movie
ios episode => playing    # episode
All tests passed!
```

## Selected engine: `fvp` (libmdk / FFmpeg), iOS-only

`fvp` registers itself as the **`video_player` platform implementation**, backing the
existing `VideoPlayerController` with **libmdk (FFmpeg)** instead of AVFoundation. FFmpeg
decodes MPEG-TS (and HLS/VOD/H.264/HEVC/AAC) that AVFoundation rejects.

Why `fvp` over a separate `media_kit` service:
- **Zero feature/UI/state changes.** The same `VideoPlayerPlaybackService`, the same
  `VideoPlayer(controller)` surface, the same `PlaybackState` machine, the same seek /
  resume / fullscreen code all keep working — only the decode backend changes on iOS.
- **No competing state machine**, no duplicated player, no per-platform UI tree.
- **Surgical platform scoping** — activated for iOS only.

## Architecture seam (unchanged)

```
Feature / UI  (player_screen.dart — PlaybackItem playlist, controls, seek, resume, EPG)
  → PlaybackService            (abstract: load/play/pause/stop/seek/dispose + PlaybackState)
    → VideoPlayerPlaybackService   (video_player; single implementation, all platforms)
        → Android: ExoPlayer            (video_player_android — unchanged)
        → macOS:   AVFoundation         (video_player_avfoundation — unchanged)
        → iOS:     fvp / libmdk (FFmpeg) (registered for iOS only — MPEG-TS capable)
```

The adapter is a **single registration call**, not a new code path:

```dart
// lib/app/bootstrap.dart
void _registerIosPlaybackAdapter() {
  if (_fvpRegistered) return;
  fvp.registerWith(options: {'platforms': ['ios']}); // iOS only
  _fvpRegistered = true;
}
```

`'platforms': ['ios']` means Android keeps ExoPlayer and macOS keeps AVFoundation — they
are not in the list, so their official `video_player` implementations remain the active
`VideoPlayerPlatform`. Confirmed by regression (Android live+VOD still play; macOS QA green).

## Supported media behavior on device (iPhone 15, iOS 26.5)

| Media | Result |
|---|---|
| Live MPEG-TS | playing |
| Live channel switch | playing |
| Movie VOD (best quality) | playing |
| Series episode | playing |

## Lifecycle / errors / states (reused, unchanged)

- States: `idle · buffering · playing · paused · ended · error` — emitted by
  `VideoPlayerPlaybackService` from the controller listener (same on all platforms).
- Lifecycle: `PlayerScreen` pauses on `AppLifecycleState.paused/hidden`; persists
  resume position on dispose; releases the controller on `stop()`/`dispose()`.
- Errors: load timeout + controller error → `PlaybackStatus.error` → in-player retry UI.
- Channel/source switching + VOD next-episode + auto-advance: playlist model, unchanged.

## Platform-specific code footprint

- One file touched: `lib/app/bootstrap.dart` (the `registerWith` call).
- One dependency added: `fvp` (pulls its own prebuilt libmdk xcframework for iOS).
- No feature, UI, domain, data, or `PlaybackService` interface changes.

## Known limitations

- Audio/subtitle **track selection UI** is not exposed (not surfaced by the current
  product scope or `video_player` for these sources) — playback selects defaults.
- The Dart VM service on this specific device's debug bridge is intermittently
  undiscoverable (an Xcode/CoreDevice + mDNS/local-network environment issue, **not** an
  app defect) — see the QA closure doc. It does not affect the shipped app; it only
  affects attaching the debugger for integration tests, which succeeded on retry.
