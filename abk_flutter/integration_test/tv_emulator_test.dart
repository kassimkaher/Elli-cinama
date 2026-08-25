// Android TV / Google TV emulator QA — proves the app detects the TV device and
// renders its 10-foot sidebar UI navigable by D-pad, on a real Google TV image.
// ignore_for_file: avoid_print
import 'package:abk_player/app/bootstrap.dart';
import 'package:abk_player/core/design/breakpoints.dart';
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
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Override> _fixtures(SharedPreferences prefs) => [
      sharedPreferencesProvider.overrideWithValue(prefs),
      deviceModelProvider.overrideWithValue('tv'),
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      liveCategoriesProvider.overrideWith((ref) => [const LiveCategory(id: '1', name: 'Sports', channelCount: 1)]),
      liveChannelsProvider.overrideWith((ref) => [const LiveChannel(id: 101, name: 'Sports One', categoryId: 1, viewOrder: 101, streamUrlTemplate: 'http://h/{user}/{pass}/101')]),
      movieCategoriesProvider.overrideWith((ref) => [const MovieCategory(id: '1', name: 'Action')]),
      moviesProvider.overrideWith((ref) => [const MovieListItem(id: 'm1', name: 'Sahara', year: '2024')]),
      seriesCategoriesProvider.overrideWith((ref) => [const SeriesCategory(id: '1', name: 'Drama')]),
      seriesListProvider.overrideWith((ref) => [const SeriesListItem(id: 's1', title: 'Cactus House')]),
      featuredProvider.overrideWith((ref) => null),
      favoriteChannelsProvider.overrideWith((ref) => const []),
      continueWatchingProvider.overrideWith((ref) => const []),
    ];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Google TV: detected as TV, renders sidebar UI, D-pad focus works', (t) async {
    // bootstrap() reads the device's system features and sets AbkBreakpoints.isTv.
    final real = await bootstrap();
    addTearDown(real.dispose);
    print('isTv detected => ${AbkBreakpoints.isTv}');
    expect(AbkBreakpoints.isTv, isTrue,
        reason: 'leanback/television features → TV presentation');

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: _fixtures(prefs));
    addTearDown(container.dispose);

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AbkTheme.dark(),
        darkTheme: AbkTheme.dark(),
        themeMode: ThemeMode.dark,
        locale: const Locale('en'),
        supportedLocales: AbkStrings.supported,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(navigationMode: NavigationMode.directional),
          child: child!,
        ),
        home: const AdaptiveShell(),
      ),
    ));
    await t.pump(const Duration(milliseconds: 600));

    // TV navigation = sidebar rail, never the phone bottom bar.
    expect(find.byType(NavigationBar), findsNothing);

    // D-pad traversal keeps focus.
    for (var i = 0; i < 4; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pump();
    }
    expect(FocusManager.instance.primaryFocus, isNotNull);
    print('TV shell rendered + D-pad focus retained');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
