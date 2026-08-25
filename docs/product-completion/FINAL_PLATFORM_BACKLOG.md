# ABK Player — Final Platform Backlog

Only **intentionally deferred platform work** belongs here. No unfinished core-product
features are listed — the product is feature-complete (see PRODUCT_COMPLETION_STATUS.md).

## 1. iOS physical device — player/device closure
- Real-device install/signing, on-device smoke, real MPEG-TS/HLS/VOD playback, hardware
  decode, audio routing, lifecycle, performance.
- iOS-specific playback adapter (media_kit / libmpv) **only if** `video_player`/AVFoundation
  fails MPEG-TS on real hardware — integrated behind the existing `PlaybackService` seam.
- Detail: `IOS_PHYSICAL_DEVICE_DEFERRED.md`.
- Status at Product Completion close: **DEFERRED** (dedicated physical-iPhone phase now in progress; see `docs/platform-qa/ios/`).

## 2. Windows — implementation / QA
- **DEFERRED.** Not started. To be addressed only after: product complete · Android closed ·
  macOS closed · physical iPhone playback closed.
- Likely touch points when picked up: window chrome/min-size, keyboard/mouse focus,
  media backend for MPEG-TS on Windows (video_player Windows uses Media Foundation —
  verify or add adapter), secure storage backend.

## 3. Linux — implementation / QA
- **DEFERRED.** Not started. Same ordering as Windows.
- Likely touch points: GTK window behavior, media backend (video_player Linux support is
  limited — may require the same media_kit/libmpv adapter as iOS), secure storage backend.

---

### Explicitly NOT in this backlog
- Core product features (all complete).
- Android / macOS defects (none open).
- Backend/contract redesign (out of scope; contract is stable).

### Ordering rule
Windows and Linux begin only after the physical-iPhone player closure. This phase did not
touch Windows or Linux.
