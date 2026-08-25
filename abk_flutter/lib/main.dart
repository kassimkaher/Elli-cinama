import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap.dart';
import 'core/design/theme.dart';
import 'core/design/tokens.dart';
import 'shared/widgets/brand.dart';
import 'ui/app_root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // runApp FIRST, bootstrap SECOND. Awaiting bootstrap() before runApp() left the
  // screen with no Flutter surface (a black window) for the whole async init —
  // its length varies by device/network, which is why some TVs (e.g. TCL) showed
  // a long black/flicker start while the projector did not. Painting a branded
  // splash on the very first frame makes the cold-launch experience identical and
  // never-black on every device; bootstrap runs behind it.
  runApp(const _BootstrapApp());
}

/// Kicks off [bootstrap] and shows an immediate branded splash until the
/// [ProviderContainer] is ready, then swaps in the real app. No arbitrary delay:
/// the swap is driven purely by bootstrap completing.
class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();
  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  late final Future<ProviderContainer> _boot = bootstrap();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProviderContainer>(
      future: _boot,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done && snap.hasData) {
          return UncontrolledProviderScope(
            container: snap.data!,
            child: const AbkAppRoot(),
          );
        }
        // First frame — a branded splash, painted immediately (never black).
        return const _SplashApp();
      },
    );
  }
}

/// Minimal self-contained splash app (no providers/localization needed) shown
/// while bootstrap resolves. Always dark, matching the app's launch moment.
class _SplashApp extends StatelessWidget {
  const _SplashApp();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AbkTheme.dark(),
      home: const _Splash(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
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
                minHeight: 2,
                backgroundColor: c.surfaceStrong,
                color: c.accentPrimary),
          ),
        ]),
      ),
    );
  }
}
