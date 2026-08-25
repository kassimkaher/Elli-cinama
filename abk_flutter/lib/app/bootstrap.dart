import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/di/providers.dart';

bool _fvpRegistered = false;

/// iOS media adapter. On iOS, `video_player`/AVFoundation cannot decode the
/// backend's raw MPEG-TS live streams (verified on real hardware). Registering
/// [fvp] backs `video_player` with libmdk/FFmpeg **for iOS only**, so the same
/// `VideoPlayerController` code path decodes MPEG-TS on-device. Android keeps
/// ExoPlayer and macOS keeps AVFoundation — neither is in the platform list, so
/// both are untouched. This sits entirely behind the existing `PlaybackService`
/// seam: no feature/UI/state changes.
void _registerIosPlaybackAdapter() {
  if (_fvpRegistered) return;
  fvp.registerWith(options: {
    'platforms': ['ios'],
  });
  _fvpRegistered = true;
}

/// Composition root. Resolves async singletons (prefs, device model), resolves
/// the effective CONTENT_API from Remote Config (with fallback), and restores
/// any persisted session — then returns a ready [ProviderContainer].
Future<ProviderContainer> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerIosPlaybackAdapter();
  final prefs = await SharedPreferences.getInstance();
  final model = await _deviceModel();

  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    deviceModelProvider.overrideWithValue(model),
  ]);

  // Effective CONTENT_API (Remote Config `activity` -> validate -> fallback).
  await container.read(contentApiResolverProvider).resolve();

  // Restore persisted session (secure storage).
  await container.read(sessionControllerProvider.notifier).restore();

  return container;
}

Future<String> _deviceModel() async {
  try {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) return (await info.androidInfo).model;
    if (Platform.isIOS) return (await info.iosInfo).utsname.machine;
  } catch (_) {}
  return 'generic';
}
