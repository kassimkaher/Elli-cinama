import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_prefs.dart';
import '../core/design/breakpoints.dart';
import '../core/design/theme.dart';
import '../core/i18n/strings.dart';
import 'root_gate.dart';

/// App root. Theme mode + locale are live (Design §04/§81). Arabic → RTL via
/// the global localizations.
class AbkAppRoot extends ConsumerWidget {
  const AbkAppRoot({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      title: 'ABK',
      debugShowCheckedModeBanner: false,
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
      // On TV, switch focus to directional (D-pad) mode app-wide so a focused
      // element activates with SELECT and traversal never loses focus.
      builder: (context, child) {
        final c = child ?? const SizedBox.shrink();
        if (!AbkBreakpoints.isTv) return c;
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(navigationMode: NavigationMode.directional),
          child: c,
        );
      },
      home: const RootGate(),
    );
  }
}
