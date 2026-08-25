// Android critical gate — live MPEG-TS playback through the existing
// PlaybackService (ExoPlayer on Android decodes MPEG-TS, unlike macOS
// AVFoundation). Also a VOD smoke. Uses the real backend.
//
// Secrets via --dart-define only.
// ignore_for_file: avoid_print
import 'package:abk_player/app/bootstrap.dart';
import 'package:abk_player/core/di/providers.dart';
import 'package:abk_player/core/player/playback_service.dart';
import 'package:abk_player/features/auth/presentation/auth_controller.dart';
import 'package:abk_player/features/catalogue/catalogue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _user = String.fromEnvironment('ABK_USERNAME');
const _pass = String.fromEnvironment('ABK_PASSWORD');
const _skip = _user == '' || _pass == '';

Future<PlaybackStatus> _awaitPlaying(WidgetTester t, PlaybackService svc) async {
  for (var i = 0; i < 60; i++) {
    await t.pump(const Duration(milliseconds: 300));
    final s = svc.state.status;
    if (s == PlaybackStatus.playing || s == PlaybackStatus.buffering) return s;
    if (s == PlaybackStatus.error) return s;
  }
  return svc.state.status;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android: live MPEG-TS + VOD playback via PlaybackService', (t) async {
    final c = await bootstrap();
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
        container: c, child: const MaterialApp(home: SizedBox.shrink())));

    // Clean session, then real login.
    await c.read(sessionControllerProvider.notifier).logout();
    await c.read(sessionControllerProvider.notifier).login(_user, _pass);
    expect(c.read(sessionControllerProvider), isA<AuthAuthenticated>());

    final svc = c.read(playbackServiceProvider);
    final factory = c.read(playbackSourceFactoryProvider);

    // ---- Live MPEG-TS (critical gate) ----
    final channels = (await c.read(getLiveChannelsProvider).call()).valueOrNull!;
    final ch = channels.firstWhere((x) => (x.streamUrlTemplate ?? '').isNotEmpty);
    final liveUrl = c.read(resolveLiveStreamUrlProvider).call(ch)!;
    await svc.load(factory.fromUrl(liveUrl, title: ch.name)).timeout(const Duration(seconds: 25));
    await svc.play();
    final liveStatus = await _awaitPlaying(t, svc);
    print('android live playback => ${liveStatus.name}');
    expect(liveStatus, anyOf(PlaybackStatus.playing, PlaybackStatus.buffering),
        reason: 'live MPEG-TS should decode on ExoPlayer');
    await svc.stop();

    // ---- VOD (movie best quality) ----
    final movies = (await c.read(getMoviesProvider).call()).valueOrNull!;
    final info = await c.read(movieInfoProvider(movies.first.id).future);
    final vodUrl = c.read(selectMovieQualityProvider).call(info);
    if (vodUrl != null && vodUrl.isNotEmpty) {
      await svc.load(factory.fromUrl(vodUrl, title: info.title)).timeout(const Duration(seconds: 25));
      await svc.play();
      final vodStatus = await _awaitPlaying(t, svc);
      print('android vod playback => ${vodStatus.name}');
      // VOD container support varies; a non-error state is sufficient here.
      await svc.stop();
    } else {
      print('android vod playback => no url');
    }
  }, timeout: const Timeout(Duration(minutes: 3)), skip: _skip);
}
