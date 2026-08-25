# Windows — Run Preparation (QA deferred)

**Full Windows QA is NOT started.** This documents the exact run workflow and readiness so
the later Windows phase is a straightforward platform adaptation, not new development.

## Prerequisites (on a Windows machine)

- Windows 10/11.
- Flutter SDK (same 3.44.x line as the project) with Windows desktop support.
- **Visual Studio** with the **“Desktop development with C++”** workload (MSVC, Windows SDK,
  CMake) — required to build Flutter Windows apps.
- Git.

## Enable + run commands

```powershell
flutter config --enable-windows-desktop
flutter devices                     # should list "Windows (desktop)"

# One-time: this repo has no windows/ runner yet — generate it:
flutter create --platforms=windows .

flutter pub get
flutter run -d windows              # debug run

# later:
flutter build windows --release
```

Pass QA/backend defines the same way as other platforms:

```powershell
flutter run -d windows `
  --dart-define=ABK_QA_USERNAME=<u> --dart-define=ABK_QA_PASSWORD=<p>
```

## Current project readiness

| Item | State |
|---|---|
| `windows/` runner scaffolding | **Not present** — add via `flutter create --platforms=windows .` |
| Dart/domain/data code | Platform-agnostic — no Windows-specific changes expected |
| Secure storage | `flutter_secure_storage` supports Windows (DPAPI) — verify at QA time |
| Networking / backend | `dart:io` HTTP — not platform-bound; works on Windows |
| Design / adaptive layout | One adaptive tree (compact/medium/large) already desktop-proven on macOS |
| App icon | source asset ready (`assets/brand/abk_icon.png`); wire Windows icon during that phase |

## Windows player readiness

**Windows player adapter: READY (via `fvp`).**

- The official `video_player` has **no** Windows implementation, but **`fvp` (libmdk/FFmpeg)
  already ships a Windows plugin** (`fvp/windows/…`) and is already a project dependency.
- It sits behind the **existing `PlaybackService` seam** — no player rewrite, no new
  dependency. fvp/FFmpeg decodes the backend's MPEG-TS + VOD, same as on iOS.
- **To activate for Windows** (during the Windows phase only), add `'windows'` to the fvp
  platform list in `lib/app/bootstrap.dart`:

  ```dart
  fvp.registerWith(options: {'platforms': ['ios', 'windows']});
  ```

  This must not regress Android (ExoPlayer), macOS (AVFoundation), or iOS (fvp) — those
  stay exactly as they are; Windows simply joins the fvp list.

## Remaining Windows-specific work (for the later phase)

1. `flutter create --platforms=windows .` to add the runner; set app name/icon.
2. Enable fvp for `'windows'` (one line, as above).
3. Validate on Windows: native build/launch, login/session, **secure storage (DPAPI)**,
   backend networking, Live/Movies/Series catalogues, search, favorites, adaptive desktop
   layout, keyboard/mouse, window resize, fullscreen, **Live/Movie/Episode playback**,
   lifecycle, and a `--release` build.

## Status

**Full Windows QA: DEFERRED.** No Windows QA was performed in this task. Android, macOS, and
iOS remain unaffected.
