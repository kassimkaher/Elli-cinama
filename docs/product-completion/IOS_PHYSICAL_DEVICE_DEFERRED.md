# iOS Physical Device — Deferred Work (at Product Completion close)

As of the Product Completion phase close (2026-08-25), iOS **Simulator** work remains CLOSED
(Phase 5) and no iOS regression was introduced by this phase. The only remaining iOS work is
**physical-device** validation, centered on media playback and hardware-dependent behavior.

> Note: a physical iPhone became available at the end of this phase and the dedicated
> **Physical iPhone Final QA** phase is starting immediately after this. Its results are
> documented under `docs/platform-qa/ios/`. This file records the scope that was deferred
> out of Product Completion.

## Exactly what remains for the physical iPhone

1. **Install / signing** — Xcode signing, provisioning, bundle id, development team, device trust, deployment target.
2. **On-device smoke** — launch, login, session restore, logout, Keychain, Home/Live/Movies/Series/Search/Favorites/Settings/Parental lock, RTL/LTR, themes, adaptive UI, safe areas / notch / Dynamic Island.
3. **Live playback (critical)** — real MPEG-TS decode on real hardware:
   - If `video_player` (AVFoundation) plays MPEG-TS on-device → **no adapter needed**.
   - If it fails → implement the pre-planned **iOS playback adapter** (media_kit / libmpv) **behind the existing `PlaybackService` seam** — no feature/UI changes, no Android/macOS regression.
4. **Movie playback** — quality selection, start, seek, pause/resume, duration, fullscreen, lifecycle, disposal.
5. **Episode playback** — season/episode selection, playback, next-episode, disposal.
6. **Codec/container coverage** — record actual formats returned (MPEG-TS, HLS/.m3u8, progressive; H.264/HEVC; AAC/AC3/EAC3 if encountered).
7. **Hardware decode / performance** — startup latency, dropped frames, CPU/memory/heat over a reasonable session, repeated channel/source switching.
8. **Audio routing** — speaker, volume/mute, wired/Bluetooth/AirPods where available, interruptions, route changes.
9. **Background / foreground / interruptions** — lock/unlock, interruption handling, no duplicate audio, no leaked session, no crash on resume.
10. **AirPlay** — only if in product scope + hardware available; otherwise mark NOT IN SCOPE.
11. **Secure storage / Keychain on hardware** — write, restart-restore, logout-clear, no plaintext creds in logs/crash output.
12. **Final iOS regression** + focused on-device integration tests (player launch, state transitions, source switch, disposal, background/foreground, error/retry).

## Preserved seam (so this phase stays small)

The shared player abstraction is already in place:

```
Feature / UI
  → PlaybackService (state machine: idle/buffering/playing/paused/ended/error)
    → PlaybackSource factory (url, headers, container detection)
      → video_player implementation (Android ExoPlayer, Apple AVFoundation)
      → [iOS adapter slot — media_kit/libmpv — only if MPEG-TS fails on hardware]
```

Feature/UI code depends only on `PlaybackService` + `PlaybackItem`. An iOS adapter is a
drop-in behind the factory; **no product features require rewriting**.

## What is NOT deferred (already done in product completion)

Every non-device iOS-agnostic product feature is complete (see PRODUCT_COMPLETION_STATUS.md).
The physical-iPhone phase should contain **only** device install/signing + real-hardware
playback/codec/audio/lifecycle validation and, if needed, the iOS adapter — not general app
feature work.
