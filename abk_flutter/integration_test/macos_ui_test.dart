// macOS UI journey (deterministic) — renders the real product shell/screens
// natively on macOS with fixture catalogue data (no network, no live video),
// then navigates. Reliable UI QA for the Phase 3 gate.
// ignore_for_file: avoid_print
import 'package:abk_player/core/design/theme.dart';
import 'package:abk_player/core/di/providers.dart';
import 'package:abk_player/core/i18n/strings.dart';
import 'package:abk_player/core/storage/key_value_store.dart';
import 'package:abk_player/core/storage/secure_store.dart';
import 'package:abk_player/features/catalogue/catalogue_providers.dart';
import 'package:abk_player/features/live/domain/entities.dart';
import 'package:abk_player/features/movies/domain/entities.dart';
import 'package:abk_player/features/series/domain/entities.dart';
import 'package:abk_player/features/shell/adaptive_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _cats = [const LiveCategory(id: '1', name: 'Sports', channelCount: 3)];
final _channels = [
  const LiveChannel(id: 101, name: 'Sports One', categoryId: 1, viewOrder: 101, streamUrlTemplate: 'http://h/{user}/{pass}/101'),
  const LiveChannel(id: 102, name: 'News 24', categoryId: 1, viewOrder: 102, streamUrlTemplate: 'http://h/{user}/{pass}/102'),
];
final _movies = [
  const MovieListItem(id: 'm1', name: 'Sahara Nights', year: '2024', genre: 'Drama', rating: '8.4'),
  const MovieListItem(id: 'm2', name: 'The Harbor', year: '2023', genre: 'History'),
];
final _series = [const SeriesListItem(id: 's1', title: 'Cactus House', genre: 'Drama', rating: '7.9')];

List<Override> _overrides(SharedPreferences prefs) => [
      sharedPreferencesProvider.overrideWithValue(prefs),
      deviceModelProvider.overrideWithValue('generic'),
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      liveCategoriesProvider.overrideWith((ref) => _cats),
      liveChannelsProvider.overrideWith((ref) => _channels),
      movieCategoriesProvider.overrideWith((ref) => [const MovieCategory(id: '1', name: 'Action')]),
      moviesProvider.overrideWith((ref) => _movies),
      seriesCategoriesProvider.overrideWith((ref) => [const SeriesCategory(id: '1', name: 'Drama')]),
      seriesListProvider.overrideWith((ref) => _series),
      featuredProvider.overrideWith((ref) => _movies.first),
      favoriteChannelsProvider.overrideWith((ref) => const []),
      continueWatchingProvider.overrideWith((ref) => const []),
    ];

Widget _app() => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AbkTheme.light(),
      darkTheme: AbkTheme.dark(),
      themeMode: ThemeMode.dark,
      locale: const Locale('en'),
      supportedLocales: AbkStrings.supported,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AdaptiveShell(),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('macOS UI: shell renders Home, navigates catalogues, opens search', (t) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: _overrides(prefs));
    addTearDown(container.dispose);

    await t.pumpWidget(UncontrolledProviderScope(container: container, child: _app()));
    await t.pump(const Duration(milliseconds: 600));

    // Home rendered with the featured hero + a search affordance.
    expect(find.byIcon(Icons.search_rounded), findsWidgets);
    expect(find.text('Sahara Nights'), findsWidgets);
    print('UI: Home rendered');

    // Movies tab.
    container.read(shellIndexProvider.notifier).state = 2;
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('The Harbor'), findsWidgets);
    print('UI: Movies rendered');

    // Series tab.
    container.read(shellIndexProvider.notifier).state = 3;
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Cactus House'), findsWidgets);
    print('UI: Series rendered');

    // Live tab.
    container.read(shellIndexProvider.notifier).state = 1;
    await t.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Sports'), findsWidgets);
    print('UI: Live rendered');

    // Settings tab.
    container.read(shellIndexProvider.notifier).state = 5;
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byIcon(Icons.account_circle_rounded), findsWidgets);
    print('UI: Settings rendered');

    // Open global search.
    await t.tap(find.byIcon(Icons.search_rounded).first);
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(TextField), findsWidgets);
    print('UI: Search opened');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
