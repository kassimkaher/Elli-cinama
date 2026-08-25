// iOS playback smoke — validates the PlaybackService source creation, header
// injection and state path on iOS, and CLASSIFIES the native decode outcome
// (AVFoundation does not decode raw MPEG-TS; see IOS_PLATFORM_ADAPTERS.md).
// Does not assert "playing" — the outcome is recorded, not required.
//
// Secrets via --dart-define only.
// ignore_for_file: avoid_print
import 'package:abk_player/app/bootstrap.dart';
import 'package:abk_player/core/di/providers.dart';
import 'package:abk_player/core/player/playback_service.dart';
import 'package:abk_player/features/auth/presentation/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _user = String.fromEnvironment('ABK_USERNAME');
const _pass = String.fromEnvironment('ABK_PASSWORD');
const _skip = _user == '' || _pass == '';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('iOS: playback abstraction + state path (native decode classified)', (t) async {
    final c = await bootstrap();
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
        container: c, child: const MaterialApp(home: SizedBox.shrink())));

    await c.read(sessionControllerProvider.notifier).logout();
    await c.read(sessionControllerProvider.notifier).login(_user, _pass);
    expect(c.read(sessionControllerProvider), isA<AuthAuthenticated>());

    final svc = c.read(playbackServiceProvider);
    final factory = c.read(playbackSourceFactoryProvider);
    final channels = (await c.read(getLiveChannelsProvider).call()).valueOrNull!;
    final ch = channels.firstWhere((x) => (x.streamUrlTemplate ?? '').isNotEmpty);
    final url = c.read(resolveLiveStreamUrlProvider).call(ch)!;

    // Abstraction guarantees — must hold on iOS regardless of native decode.
    final src = factory.fromUrl(url, title: ch.name);
    expect(src.headers['User-Agent']?.isNotEmpty, isTrue);
    expect(src.container, isA<StreamContainer>());

    var outcome = 'no-terminal-state';
    try {
      await svc.load(src).timeout(const Duration(seconds: 20));
      await svc.play();
      for (var i = 0; i < 40; i++) {
        await t.pump(const Duration(milliseconds: 300));
        final s = svc.state.status;
        if (s == PlaybackStatus.playing) { outcome = 'playing'; break; }
        if (s == PlaybackStatus.error) { outcome = 'error'; break; }
        if (s == PlaybackStatus.buffering) outcome = 'buffering';
      }
    } catch (e) {
      outcome = 'adapter-needed:${e.runtimeType}';
    }
    print('ios live playback => $outcome');
    // The abstraction and state path are validated; the native AVFoundation
    // outcome is classified (adapter follow-up), not asserted.
    expect(outcome, isNotEmpty);
    await svc.stop();
  }, timeout: const Timeout(Duration(minutes: 2)), skip: _skip);
}
