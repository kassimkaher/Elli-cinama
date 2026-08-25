# iOS App Store / Distribution Follow-up

Only **distribution-specific** work remains here. Core app functionality and on-device
playback are CLOSED (see `IOS_PHYSICAL_DEVICE_QA_CLOSURE.md`). No product/player defects
belong in this file.

## Remaining distribution work

1. **Distribution signing**
   - Development signing (team `86FVQ9663H`, automatic) is validated for device install/run.
   - Create/assign an **App Store distribution** certificate + provisioning profile for
     release upload (separate from the development profile used in QA).

2. **App Store Connect**
   - App record, bundle id `com.abk.abkPlayer`, name/subtitle, category, age rating.
   - Screenshots for required device classes; app privacy questionnaire.

3. **TestFlight**
   - Upload a release build; internal/external testing before submission.

4. **Privacy / entitlements review**
   - `NSAppTransportSecurity → NSAllowsArbitraryLoads = true` is set because the backend
     streams live/VOD/EPG over **cleartext HTTP** with a rotating host. App Review may
     request a justification; document the streaming-host constraint. Prefer narrowing to
     `NSExceptionDomains` if/when the streaming hosts stabilize.
   - No Local Network usage in the shipped product (the debug-only Bonjour/local-network
     keys used for VM-service discovery during QA are **not** required for release and are
     not present).
   - Confirm no background modes are declared beyond product scope (no background audio).

5. **Build settings for release**
   - Verify bitcode/dSYM upload, deployment target (iOS 13.0), and that the `fvp` libmdk
     xcframework is embedded & signed in the archive (Xcode "Embed & Sign").

## Explicitly NOT here
- iOS player functionality (CLOSED — fvp adapter validated on device).
- Core app features (complete).
- Android / macOS work (closed).

## Optional observational follow-ups (not blockers)
- Audio-routing matrix (wired / Bluetooth / AirPods, interruptions) — needs external audio
  hardware; recorded as NOT TESTED in the QA closure.
- AirPlay — NOT IN SCOPE unless the product adds it.
