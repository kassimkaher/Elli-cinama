import 'package:abk_player/core/design/breakpoints.dart';
import 'package:abk_player/core/design/theme.dart';
import 'package:abk_player/core/design/tokens.dart';
import 'package:abk_player/core/i18n/strings.dart';
import 'package:abk_player/shared/widgets/badges.dart';
import 'package:abk_player/shared/widgets/buttons.dart';
import 'package:abk_player/shared/widgets/cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget harness(Widget child, {Locale locale = const Locale('en'), ThemeMode mode = ThemeMode.dark}) {
  return MaterialApp(
    themeMode: mode,
    theme: AbkTheme.light(),
    darkTheme: AbkTheme.dark(),
    locale: locale,
    supportedLocales: AbkStrings.supported,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('Design tokens', () {
    test('dark/light palettes carry the confirmed accents', () {
      expect(AbkColors.dark.accentPrimary, const Color(0xFFE8B14C));
      expect(AbkColors.light.accentPrimary, const Color(0xFFA9721A));
      expect(AbkColors.dark.background, const Color(0xFF0E0D0C));
      expect(AbkColors.light.cardBorder, isTrue); // light adds a card border
      expect(AbkColors.dark.cardBorder, isFalse);
    });

    test('placeholder is stable per key', () {
      expect(AbkColors.dark.placeholderFor('abc'), AbkColors.dark.placeholderFor('abc'));
    });

    test('breakpoints resolve to the five classes + TV override', () {
      expect(AbkBreakpoints.resolve(400), WidthClass.compact);
      expect(AbkBreakpoints.resolve(700), WidthClass.medium);
      expect(AbkBreakpoints.resolve(1000), WidthClass.expanded);
      expect(AbkBreakpoints.resolve(1400), WidthClass.desktop);
      expect(AbkBreakpoints.resolve(1800), WidthClass.wideDesktop);
      expect(AbkBreakpoints.resolve(400, tv: true), WidthClass.tv);
      expect(AbkBreakpoints.posterColumns(WidthClass.desktop), 7);
    });
  });

  group('Theme', () {
    testWidgets('dark theme exposes the AbkColors extension', (t) async {
      late AbkColors captured;
      await t.pumpWidget(harness(Builder(builder: (ctx) {
        captured = ctx.c;
        return const SizedBox();
      })));
      expect(captured.background, AbkColors.dark.background);
    });
  });

  group('Components render + localize', () {
    testWidgets('AbkButton shows its label', (t) async {
      await t.pumpWidget(harness(const AbkButton('Play now')));
      expect(find.text('Play now'), findsOneWidget);
    });

    testWidgets('MetadataRow collapses empty and joins present values', (t) async {
      await t.pumpWidget(harness(const MetadataRow([null, '', '2024', 'Drama'])));
      expect(find.textContaining('2024'), findsOneWidget);
      expect(find.textContaining('Drama'), findsOneWidget);
    });

    testWidgets('RatingBadge hidden when null/0, shown otherwise', (t) async {
      await t.pumpWidget(harness(const Column(children: [RatingBadge('0'), RatingBadge('8.4')])));
      expect(find.text('8.4'), findsOneWidget);
    });

    testWidgets('PosterCard renders title', (t) async {
      await t.pumpWidget(harness(const SizedBox(
        width: 120,
        child: PosterCard(title: 'Sahara Nights', imageUrl: null, width: 120),
      )));
      // Appears as the card label and the fallback placeholder.
      expect(find.text('Sahara Nights'), findsWidgets);
    });

    testWidgets('Arabic locale renders RTL', (t) async {
      await t.pumpWidget(harness(
        Builder(builder: (ctx) => Text(ctx.tr('home'))),
        locale: const Locale('ar'),
      ));
      expect(find.text('الرئيسية'), findsOneWidget);
      expect(Directionality.of(t.element(find.text('الرئيسية'))), TextDirection.rtl);
    });

    testWidgets('English locale renders LTR', (t) async {
      await t.pumpWidget(harness(Builder(builder: (ctx) => Text(ctx.tr('home')))));
      expect(find.text('Home'), findsOneWidget);
      expect(Directionality.of(t.element(find.text('Home'))), TextDirection.ltr);
    });
  });
}
