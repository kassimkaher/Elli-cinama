import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/providers.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/launch/launch_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/adaptive_shell.dart';

/// Routes between Launch / Login / Shell from the confirmed auth state
/// (Design §10 conditions).
class RootGate extends ConsumerWidget {
  const RootGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(sessionControllerProvider);
    final ready = ref.watch(appReadyProvider);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: switch (auth) {
        AuthAuthenticated() => ready ? const AdaptiveShell() : const LaunchScreen(),
        AuthLoggedOut() || AuthAuthenticating() || AuthError() => const LoginScreen(),
      },
    );
  }
}
