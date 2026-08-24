// Real-device Flutter integration test. Crosses all app layers (bootstrap,
// secure storage, device info, Remote Config resolve, content client).
//
// Secrets are passed via --dart-define (never in source):
//   flutter test integration_test/app_test.dart -d <device> \
//     --dart-define=ABK_USERNAME=… --dart-define=ABK_PASSWORD=… \
//     [--dart-define=ABK_CONTENT_BASE_URL=…]
import 'package:abk_player/app/bootstrap.dart';
import 'package:abk_player/core/di/providers.dart';
import 'package:abk_player/features/auth/presentation/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const user = String.fromEnvironment('ABK_USERNAME');
  const pass = String.fromEnvironment('ABK_PASSWORD');
  final skip = user.isEmpty || pass.isEmpty;

  testWidgets('device: bootstrap → login → live categories & channels',
      (tester) async {
    final container = await bootstrap();
    addTearDown(container.dispose);

    // Session restore should have run; start logged out for a fresh device.
    await container.read(sessionControllerProvider.notifier).login(user, pass);

    final state = container.read(sessionControllerProvider);
    expect(state, isA<AuthAuthenticated>(),
        reason: 'login should authenticate on-device');

    final cats = await container.read(getLiveCategoriesProvider).call();
    final chans = await container.read(getLiveChannelsProvider).call();
    expect((cats.valueOrNull ?? const []).length, greaterThan(0));
    expect((chans.valueOrNull ?? const []).length, greaterThan(0));

    // Session persisted in secure storage — logout clears it.
    await container.read(sessionControllerProvider.notifier).logout();
    expect(container.read(sessionControllerProvider), isA<AuthLoggedOut>());
  }, skip: skip);
}
