import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/i18n/strings.dart';
import '../../shared/widgets/brand.dart';
import '../catalogue/catalogue_providers.dart';
import '../settings/settings_screen.dart';

/// Launch / Configuration (Design §10) — a held brand moment. Config, session
/// restore and the first catalogue fetch happen behind it. Always dark.
class LaunchScreen extends ConsumerStatefulWidget {
  const LaunchScreen({super.key});
  @override
  ConsumerState<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends ConsumerState<LaunchScreen> {
  bool _showText = false;

  @override
  void initState() {
    super.initState();
    // Warm the catalogue behind the screen (fire-and-forget; sections show
    // their own skeletons afterwards).
    ref.read(liveCategoriesProvider.future).ignore();
    ref.read(moviesProvider.future).ignore();
    ref.read(seriesListProvider.future).ignore();

    Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showText = true);
    });
    // Proceed to the app quickly — catalogues stream in behind their skeletons.
    Timer(const Duration(milliseconds: 450), () {
      if (mounted) ref.read(appReadyProvider.notifier).state = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlwaysDark(
      child: Builder(builder: (context) {
        final c = context.c;
        return Scaffold(
          backgroundColor: c.background,
          body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const AbkLogo.chip(size: 64),
              const SizedBox(height: AbkSpace.s16),
              Text('ABK', style: context.type.sectionTitle),
              const SizedBox(height: AbkSpace.s32),
              SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                    minHeight: 2, backgroundColor: c.surfaceStrong, color: c.accentPrimary),
              ),
              const SizedBox(height: AbkSpace.s16),
              AnimatedOpacity(
                opacity: _showText ? 1 : 0,
                duration: AbkMotion.base,
                child: Text(context.tr('preparingLibrary'),
                    style: context.type.caption.copyWith(color: c.textMuted)),
              ),
            ]),
          ),
        );
      }),
    );
  }
}
