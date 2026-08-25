import 'package:abk_player/core/design/theme.dart';
import 'package:abk_player/core/di/providers.dart';
import 'package:abk_player/core/i18n/strings.dart';
import 'package:abk_player/core/storage/key_value_store.dart';
import 'package:abk_player/core/storage/secure_store.dart';
import 'package:abk_player/features/favorites/parental_lock_repository.dart';
import 'package:abk_player/features/settings/parental_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a button that calls [ensureUnlocked] and records the result. The gate
/// dialog (when shown) renders into this app's overlay.
Future<ParentalLockRepository> _pump(
  WidgetTester t, {
  required ParentalLockRepository repo,
  required bool categoryLocked,
  required void Function(bool) onResult,
}) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: [parentalLockRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AbkTheme.dark(),
        supportedLocales: AbkStrings.supported,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Consumer(builder: (context, ref, _) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final ok = await ensureUnlocked(context, ref,
                      kind: 'live', id: '7', categoryLocked: categoryLocked);
                  onResult(ok);
                },
                child: const Text('go'),
              ),
            ),
          );
        }),
      ),
    ),
  );
  return repo;
}

void main() {
  testWidgets('no PIN configured → allowed immediately, no dialog', (t) async {
    bool? result;
    await _pump(t,
        repo: ParentalLockRepository(secure: InMemorySecureStore(), store: InMemoryKeyValueStore()),
        categoryLocked: true,
        onResult: (v) => result = v);
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    expect(result, isTrue);
    expect(find.text('Locked content'), findsNothing);
  });

  testWidgets('PIN set + unlocked category → allowed, no dialog', (t) async {
    final repo = ParentalLockRepository(secure: InMemorySecureStore(), store: InMemoryKeyValueStore());
    await repo.setPin('4321');
    bool? result;
    await _pump(t, repo: repo, categoryLocked: false, onResult: (v) => result = v);
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    expect(result, isTrue);
    expect(find.text('Locked content'), findsNothing);
  });

  testWidgets('PIN set + locked category → prompts, correct PIN unlocks', (t) async {
    final repo = ParentalLockRepository(secure: InMemorySecureStore(), store: InMemoryKeyValueStore());
    await repo.setPin('4321');
    bool? result;
    await _pump(t, repo: repo, categoryLocked: true, onResult: (v) => result = v);
    await t.tap(find.text('go'));
    await t.pumpAndSettle();

    // Dialog is shown; the gate has not resolved yet.
    expect(find.text('Locked content'), findsOneWidget);
    expect(result, isNull);

    await t.enterText(find.byType(TextField), '4321');
    await t.pumpAndSettle();
    expect(result, isTrue);
    expect(find.text('Locked content'), findsNothing);
  });
}
