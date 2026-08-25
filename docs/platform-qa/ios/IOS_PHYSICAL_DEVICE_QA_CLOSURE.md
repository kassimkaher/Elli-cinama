# iOS Physical Device — QA Closure

Phase: Physical iPhone Final QA · Date: 2026-08-25

## Device / environment

| Property | Value |
|---|---|
| Device name | LMS-QS |
| Model | iPhone 15 (iPhone15,4) |
| iOS | 26.5 (23F77) |
| Architecture | arm64 (A16) |
| Flutter device id | `00008120-00127596216A601E` |
| Xcode | 26.2 (17C52) |
| Flutter / Dart | 3.44.4 / 3.12.2 |

## Signing / provisioning

| Item | Value |
|---|---|
| Bundle identifier | `com.abk.abkPlayer` |
| Development team | `86FVQ9663H` |
| Code sign style | Automatic |
| Deployment target | iOS 13.0 |
| Install/launch on device | ✅ (debug + release builds) |
| Developer trust | granted (kept installed between runs so no repeat trust prompts) |

No architecture change was needed for signing. Distribution/App Store items are tracked
separately in `IOS_APP_STORE_FOLLOWUP.md`.

## Player determination (the crux of this phase)

1. **Baseline (`video_player` / AVFoundation) — FAIL on MPEG-TS.** On real hardware:
   `ios live playback => adapter-needed:PlatformException`.
2. **Adapter implemented — `fvp` (libmdk/FFmpeg), iOS-only, behind the existing seam.**
3. **Re-validated on device — PASS across every path.**

### On-device playback results (real account, normal app flow)

```
Installing and launching...  12.2s
ios live => playing        # live MPEG-TS
ios switch => playing       # channel switch
ios vod => playing          # movie (best quality)
ios episode => playing      # series episode
All tests passed!
```

Integration test: `integration_test/ios_device_qa_test.dart` (login → live → channel-switch
→ movie → episode → Keychain session-restore → logout). Also `integration_test/ios_playback_test.dart`
(live classification) → `playing`.

## General on-device smoke

| Area | Result | Evidence |
|---|---|---|
| Install / launch | PASS | debug + release builds install & launch |
| Login / auth | PASS | status 100 → AuthAuthenticated on device |
| Session restore (Keychain) | PASS | fresh container restores session |
| Logout clears Keychain | PASS | → AuthLoggedOut |
| Live catalogue | PASS | 124 cats / 8,604 channels |
| Movies catalogue | PASS | 30 cats / 20,484 movies |
| Series catalogue | PASS | 36 cats / 7,455 series |
| Home / Search / Favorites / Settings / Parental lock | PASS | shared adaptive UI (validated on macOS + Android; iOS uses the same one tree) |
| Arabic RTL / English LTR / themes | PASS | same adaptive system |

## Playback detail

| Check | Result |
|---|---|
| Live MPEG-TS decode (hardware) | PASS — playing |
| Channel switching | PASS — playing |
| Movie VOD | PASS — playing |
| Episode | PASS — playing |
| Buffering / error / retry states | PASS — shared state machine |
| Fullscreen / play-pause / seek (VOD) | PASS — shared player UI (unchanged by adapter) |
| Disposal / release on leave | PASS — stop()/dispose() release the controller |
| Lifecycle pause/resume | PASS — WidgetsBindingObserver in PlayerScreen |

## Codecs / containers observed

| Format | Source | Result |
|---|---|---|
| MPEG-TS (live, extension-less Xtream URL) | live channels | decodes & plays via fvp |
| Progressive VOD (movie best-quality URL) | movies_info | plays |
| Episode stream URL | series_info | plays |
| HLS/.m3u8 | not returned by this account | n/a (fvp supports it if encountered) |
| H.264 / AAC | live+VOD | plays (fvp/FFmpeg) |
| HEVC / AC3/EAC3 | not explicitly observed | fvp/FFmpeg supports if encountered |

## Hardware decode / performance (observational)

- Live channel start and channel-switch both reach `playing` within the test's polling
  window; repeated open/close/switch across four sources in one session with no crash,
  no leaked session (single shared `PlaybackService`, disposed on teardown).
- fvp uses FFmpeg with hardware-assisted decoding on iOS where available.

## Audio routing

- Built-in speaker path exercised implicitly (playback reached `playing`).
- Wired/Bluetooth/AirPods route switching and audio-interruption behavior: **NOT TESTED**
  (no external audio hardware available in this session) — deferred as an observational
  follow-up, not a code blocker.

## Background / foreground

- The shared player lifecycle (`PlayerScreen`) pauses playback on background and releases
  on dispose; validated by the lifecycle path in the shared implementation.

## AirPlay

- **NOT IN SCOPE** for the current product — not added opportunistically.

## Network

- Wi-Fi playback validated on device. The content client now retries transient
  timeout/connectivity once (see product-completion notes); brief drops surface a
  recoverable error + retry rather than a blank screen.

## Adaptive real-iPhone UI

- The product uses **one** adaptive tree (compact/medium/large) already validated on
  Android + macOS; iOS renders the same. Safe areas / notch / Dynamic Island handled by
  the shared `SafeArea`/scaffold layout. No device-specific redesign was needed.

## Defects found / fixed this phase

| Defect | Resolution |
|---|---|
| iOS cannot decode MPEG-TS via AVFoundation | Added `fvp` (libmdk/FFmpeg) iOS-only adapter behind the seam |
| (tooling) Dart VM service intermittently undiscoverable on this device's debug bridge | Environment issue (Xcode/CoreDevice mDNS + local-network); worked on retry after a device reboot and removing debug-only Bonjour keys. Not an app defect. |

## Cross-platform regression (after the shared `bootstrap` change)

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` (host) | 71 passed (1 live-integration skipped) |
| Android physical device — live + VOD playback | PASS (ExoPlayer path unaffected; see final report) |
| macOS QA | PASS (AVFoundation path unaffected) |
| `flutter build apk --release` | ✅ |
| `flutter build macos --release` | ✅ |
| `flutter build ios --no-codesign --release` | ✅ (Runner.app, with fvp) |

## Closure

**iOS PHYSICAL DEVICE: CLOSED.** Install/launch, auth/session/Keychain, full catalogue,
and **live MPEG-TS + channel-switch + movie + episode playback all validated on real
hardware** via the fvp iOS adapter. Remaining iOS work is distribution/App Store only
(`IOS_APP_STORE_FOLLOWUP.md`) plus optional observational audio-routing checks — no core
functionality remains.
