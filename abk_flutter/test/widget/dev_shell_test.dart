import 'package:abk_player/app/app.dart';
import 'package:abk_player/core/di/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Desktop resize + keyboard-input safety for the (temporary) dev shell.
/// Runs on the VM (no device, no network): logged-out state renders the login
/// form without touching the backend.
void main() {
  testWidgets('dev shell renders and survives narrow/wide resize + text input',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    Widget app() => ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const AbkApp(),
        );

    // Narrow (phone-ish) width.
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Logged-out → login form is present and operable.
    expect(find.text('Login'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);

    // Keyboard input works.
    await tester.enterText(find.byType(TextField).first, 'demo-user');
    await tester.pump();
    expect(find.text('demo-user'), findsOneWidget);

    // Wide (desktop) width — no layout crash.
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    await tester.pumpAndSettle();

    // Very narrow — no hard crash.
    await tester.binding.setSurfaceSize(const Size(240, 500));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
