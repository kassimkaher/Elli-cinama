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
import 'package:abk_player/shared/widgets/focusable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Override> _shellOverrides(SharedPreferences prefs) => [
      sharedPreferencesProvider.overrideWithValue(prefs),
      deviceModelProvider.overrideWithValue('generic'),
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      liveCategoriesProvider.overrideWith((ref) => [const LiveCategory(id: '1', name: 'Sports', channelCount: 2)]),
      liveChannelsProvider.overrideWith((ref) => [
            const LiveChannel(id: 101, name: 'Sports One', categoryId: 1, viewOrder: 101, streamUrlTemplate: 'http://h/{user}/{pass}/101'),
          ]),
      movieCategoriesProvider.overrideWith((ref) => [const MovieCategory(id: '1', name: 'Action')]),
      moviesProvider.overrideWith((ref) => [const MovieListItem(id: 'm1', name: 'Sahara', year: '2024')]),
      seriesCategoriesProvider.overrideWith((ref) => [const SeriesCategory(id: '1', name: 'Drama')]),
      seriesListProvider.overrideWith((ref) => [const SeriesListItem(id: 's1', title: 'Cactus House')]),
      featuredProvider.overrideWith((ref) => null),
      favoriteChannelsProvider.overrideWith((ref) => const []),
      continueWatchingProvider.overrideWith((ref) => const []),
    ];

void main() {
  tearDown(() => AbkBreakpoints.isTv = false);

  testWidgets('AbkFocusable activates on D-pad SELECT and ENTER, shows focus ring', (t) async {
    var taps = 0;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: AbkFocusable(
            autofocus: true,
            onTap: () => taps++,
            builder: (_, __) => const SizedBox(width: 120, height: 60),
          ),
        ),
      ),
    ));
    await t.pump();

    // D-pad centre (SELECT) activates.
    await t.sendKeyEvent(LogicalKeyboardKey.select);
    await t.pump();
    expect(taps, 1, reason: 'D-pad SELECT activates the focused item');

    // Enter also activates.
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(taps, 2);

    // A focus ring (Border) is drawn when focused → focus is visible.
    final decorated = t.widgetList<Container>(find.byType(Container)).where(
        (c) => c.foregroundDecoration is BoxDecoration &&
            (c.foregroundDecoration as BoxDecoration).border != null);
    expect(decorated, isNotEmpty, reason: 'focused item shows a visible ring');
  });

  testWidgets('TV shell uses the sidebar (no phone bottom bar) and keeps D-pad focus', (t) async {
    AbkBreakpoints.isTv = true;
    t.view.devicePixelRatio = 1.0;
    t.view.physicalSize = const Size(1920, 1080); // 1080p TV, logical 1920
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: _shellOverrides(prefs));
    addTearDown(container.dispose);

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AbkTheme.dark(),
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
        locale: const Locale("en"),
        home: const AdaptiveShell(),
      ),
    ));
    await t.pump(const Duration(milliseconds: 400));

    // TV navigation is the sidebar, never the phone bottom bar.
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Live'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);

    // D-pad down moves focus into the rail and never loses it.
    for (var i = 0; i < 3; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pump();
    }
    expect(FocusManager.instance.primaryFocus, isNotNull,
        reason: 'focus is retained during D-pad traversal (never lost)');
  });

  testWidgets('phone shell keeps the bottom bar (TV nav does not pollute phone)', (t) async {
    AbkBreakpoints.isTv = false;
    await t.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => t.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: _shellOverrides(prefs));
    addTearDown(container.dispose);

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AbkTheme.dark(),
        supportedLocales: AbkStrings.supported,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        locale: const Locale("en"),
        home: const AdaptiveShell(),
      ),
    ));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(NavigationBar), findsOneWidget, reason: 'phone keeps bottom bar');
  });
}
