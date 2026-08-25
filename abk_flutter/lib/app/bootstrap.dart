import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/design/breakpoints.dart';
import '../core/di/providers.dart';

bool _fvpRegistered = false;

/// Apple media adapter. On iOS **and macOS**, `video_player`/AVFoundation cannot
/// decode the backend's raw MPEG-TS live streams (verified on iOS hardware; the
/// same AVFoundation limitation applies on macOS). Registering [fvp] backs
/// `video_player` with libmdk/FFmpeg on those platforms, so the same
/// `VideoPlayerController` code path decodes MPEG-TS live + VOD. Android is NOT
/// in the list, so it keeps ExoPlayer (which already decodes MPEG-TS well) and
/// is untouched. This sits entirely behind the existing `PlaybackService` seam:
/// no feature/UI/state changes.
void _registerApplePlaybackAdapter() {
  if (_fvpRegistered) return;
  // Only call registerWith on Apple platforms — never risk touching Android.
  if (Platform.isIOS || Platform.isMacOS) {
    fvp.registerWith(options: {
      'platforms': ['ios', 'macos'],
    });
  }
  _fvpRegistered = true;
}

/// Composition root. Resolves async singletons (prefs, device model), resolves
/// the effective CONTENT_API from Remote Config (with fallback), and restores
/// any persisted session — then returns a ready [ProviderContainer].
Future<ProviderContainer> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerApplePlaybackAdapter();
  AbkBreakpoints.isTv = await _isAndroidTv(); // drives the 10-foot presentation
  if (AbkBreakpoints.isTv) {
    // TV/remote root-cause fix: FocusManager boots in `touch` highlight mode, so
    // focus rings do NOT paint until the first key event flips the mode — the
    // "screen only settles after the first D-pad press" symptom. Force the
    // traditional (focus-ring) highlight up front so the very first frame shows
    // a visible focus. TV has no pointer, so this never mis-highlights a click.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  }
  final prefs = await SharedPreferences.getInstance();
  final model = await _deviceModel();

  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    deviceModelProvider.overrideWithValue(model),
  ]);

  // Effective CONTENT_API (Remote Config `activity` -> validate -> fallback).
  // Bounded tightly so a slow/unreachable Remote Config cannot stall first
  // frame — the known-good fallback host is used if it does not resolve fast.
  await container
      .read(contentApiResolverProvider)
      .resolve(timeout: const Duration(seconds: 3));

  // Restore persisted session (secure storage) — the single session read.
  await container.read(sessionControllerProvider.notifier).restore();

  // Warm the parental PIN into memory once, so content/playback paths never
  // read the Keychain again (avoids repeated macOS system-password prompts).
  await container.read(parentalLockRepositoryProvider).warmUp();

  return container;
}

/// True on Android TV / Google TV (leanback) devices. Detected from the
/// declared system features so the app can force its 10-foot presentation.
/// Overridable for emulator/dev via `--dart-define=ABK_FORCE_TV=true`.
Future<bool> _isAndroidTv() async {
  if (const bool.fromEnvironment('ABK_FORCE_TV')) return true;
  if (!Platform.isAndroid) return false;
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    final f = info.systemFeatures;
    return f.contains('android.software.leanback') ||
        f.contains('android.software.leanback_only') ||
        f.contains('android.hardware.type.television');
  } catch (_) {
    return false;
  }
}

Future<String> _deviceModel() async {
  try {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) return (await info.androidInfo).model;
    if (Platform.isIOS) return (await info.iosInfo).utsname.machine;
  } catch (_) {}
  return 'generic';
}
