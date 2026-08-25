# ABK Cinema — iOS Platform Adapter (required, deferred)

One iOS-specific platform adapter is **required** and **deferred** to physical-
device QA. It is documented here; it was intentionally **not implemented** in the
Simulator phase to avoid regressing the green Android/macOS baseline without
device validation (and because a Simulator cannot prove hardware decode anyway).

## Capability

Native playback of the confirmed **live MPEG-TS** streams (and any non-MP4/HLS
VOD containers) on Apple platforms.

## Existing abstraction (unchanged)

`core/player/playback_service.dart` — `PlaybackService` (load/play/pause/stop/
dispose + `stateStream`), consumed only through the UI/`PlayerScreen` and
`playbackServiceProvider` DI. The current implementation is
`VideoPlayerPlaybackService` (`video_player`), which maps to **ExoPlayer** on
Android and **AVFoundation** on iOS/macOS.

## Why iOS differs (demonstrated)

- **Android (ExoPlayer):** decodes raw MPEG-TS over HTTP — runtime-confirmed
  `=> playing` (see `ANDROID_QA_CLOSURE.md`). No adapter needed.
- **iOS/macOS (AVFoundation/AVPlayer):** does **not** decode raw MPEG-TS
  transport streams. Runtime evidence on the iOS Simulator and macOS:
  `native playback => adapter-needed:PlatformException`. This is an AVFoundation
  limitation, not an app defect — the `PlaybackService` source creation, header
  (User-Agent) injection, and state path all work; only native decode fails.

The confirmed backend serves **live as MPEG-TS over HTTP**
(`{host}/{user}/{pass}/{id}`), so AVFoundation cannot play it as-is.

## Proposed iOS implementation

A `MediaKitPlaybackService` (libmpv via `media_kit`) implementing the same
`PlaybackService` interface, selected for Apple platforms in DI:

```
playbackServiceProvider → (Platform.isIOS || Platform.isMacOS)
    ? MediaKitPlaybackService()      // libmpv: decodes MPEG-TS
    : VideoPlayerPlaybackService()   // ExoPlayer on Android (green — keep)
```

libmpv decodes MPEG-TS/HLS/DASH/progressive and honours custom headers, matching
the design's playback requirements. The swap is **DI-only**.

## Shared layers unaffected

Domain, data, backend contract, UI, and `PlayerScreen` are untouched — the
adapter is a new `PlaybackService` implementation behind the existing interface.
The `PlaybackSourceFactory` (URL + headers + container hint) is reused as-is.

## Android / macOS implications

- **Android:** keep `VideoPlayerPlaybackService`/ExoPlayer (already green — do
  not replace).
- **macOS:** may adopt the same `MediaKitPlaybackService` (currently the same
  AVFoundation limitation applies); no regression required — DI-gated.

## Physical-device follow-up (required before store readiness)

1. Add `media_kit` (+ `media_kit_libs_ios_video`), implement
   `MediaKitPlaybackService`, gate via DI for iOS.
2. Validate on a **real iPhone**: live MPEG-TS decode, VOD/HLS, seek/resume,
   audio routing, background audio (respect the Android lifecycle-pause fix),
   AirPlay, and hardware performance.
3. Confirm no regression on Android (ExoPlayer) and macOS builds/tests.

## Status

**DESIGNED / DEFERRED.** Not implemented this phase. The Simulator gate is not
blocked by this — the architecture is correct, the limitation is demonstrated
and documented, no iOS implementation defect exists, and the physical-device
adapter work is recorded above.
