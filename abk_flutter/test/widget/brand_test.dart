import 'package:abk_player/core/design/theme.dart';
import 'package:abk_player/shared/widgets/brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {required bool dark}) => MaterialApp(
      theme: dark ? AbkTheme.dark() : AbkTheme.light(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('AbkLogo.chip renders (dark + light), no letter placeholder', (t) async {
    for (final dark in [true, false]) {
      await t.pumpWidget(_wrap(const AbkLogo.chip(size: 48), dark: dark));
      expect(find.byType(AbkLogo), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      // The mark is vector art — there must be no 'A'/'ABK' text placeholder.
      expect(find.text('A'), findsNothing);
      expect(find.text('ABK'), findsNothing);
    }
  });

  testWidgets('AbkLogo.mark renders on a transparent background', (t) async {
    await t.pumpWidget(_wrap(const AbkLogo.mark(size: 96), dark: true));
    expect(find.byType(AbkLogo), findsOneWidget);
    expect(noRenderException(t), isTrue);
  });

  testWidgets('AbkWordmark shows the mark + ABK wordmark', (t) async {
    await t.pumpWidget(_wrap(const AbkWordmark(markSize: 34), dark: true));
    expect(find.byType(AbkLogo), findsOneWidget);
    expect(find.text('ABK'), findsOneWidget);
  });
}

/// No render overflow was reported during the pump.
bool noRenderException(WidgetTester t) => t.takeException() == null;
