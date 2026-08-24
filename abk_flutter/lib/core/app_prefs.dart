import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'di/providers.dart';
import 'storage/key_value_store.dart';

/// Theme mode (System/Dark/Light, default System) — persisted; supports live
/// OS-appearance changes when System (Design §04).
class ThemeModeController extends StateNotifier<ThemeMode> {
  final KeyValueStore store;
  ThemeModeController(this.store) : super(ThemeMode.system) {
    _load();
  }
  Future<void> _load() async {
    final v = await store.getString('pref_theme_mode');
    if (v != null) {
      state = ThemeMode.values.firstWhere((m) => m.name == v, orElse: () => ThemeMode.system);
    }
  }

  Future<void> set(ThemeMode m) async {
    state = m;
    await store.setString('pref_theme_mode', m.name);
  }
}

/// App locale (Arabic-first, default 'ar'); persisted; live switch without
/// restart (Design §81).
class LocaleController extends StateNotifier<Locale> {
  final KeyValueStore store;
  LocaleController(this.store) : super(const Locale('ar')) {
    _load();
  }
  Future<void> _load() async {
    final v = await store.getString('pref_locale');
    if (v != null) state = Locale(v);
  }

  Future<void> set(Locale l) async {
    state = l;
    await store.setString('pref_locale', l.languageCode);
  }

  void toggle() => set(state.languageCode == 'ar' ? const Locale('en') : const Locale('ar'));
}

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
    (ref) => ThemeModeController(ref.watch(keyValueStoreProvider)));

final localeProvider = StateNotifierProvider<LocaleController, Locale>(
    (ref) => LocaleController(ref.watch(keyValueStoreProvider)));
