import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/di/providers.dart';

/// Composition root. Resolves async singletons (prefs, device model), resolves
/// the effective CONTENT_API from Remote Config (with fallback), and restores
/// any persisted session — then returns a ready [ProviderContainer].
Future<ProviderContainer> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
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
