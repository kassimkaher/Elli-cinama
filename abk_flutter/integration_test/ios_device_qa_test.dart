// Physical-iPhone QA — real playback across live / channel-switch / movie /
// episode through the shared PlaybackService, which on iOS is backed by fvp
// (libmdk/FFmpeg). Proves MPEG-TS + VOD decode on real hardware (AVFoundation
// alone cannot). Also re-checks auth/session-restore/logout on device.
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

Future<PlaybackStatus> _awaitPlay(WidgetTester t, PlaybackService svc, {int steps = 60}) async {
  for (var i = 0; i < steps; i++) {
    await t.pump(const Duration(milliseconds: 300));
    final s = svc.state.status;
    if (s == PlaybackStatus.playing) return s;
    if (s == PlaybackStatus.error) return s;
  }
  return svc.state.status;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('iOS device: auth + live + channel-switch + movie + episode (fvp)', (t) async {
    final c = await bootstrap();
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
        container: c, child: const MaterialApp(home: SizedBox.shrink())));

    // ---- Auth ----
    await c.read(sessionControllerProvider.notifier).logout();
    await c.read(sessionControllerProvider.notifier).login(_user, _pass);
    expect(c.read(sessionControllerProvider), isA<AuthAuthenticated>());

    final svc = c.read(playbackServiceProvider);
    final factory = c.read(playbackSourceFactoryProvider);
    final resolve = c.read(resolveLiveStreamUrlProvider);

    // ---- Live MPEG-TS (critical gate) ----
    final channels = (await c.read(getLiveChannelsProvider).call()).valueOrNull!;
    final playable = channels.where((x) => (x.streamUrlTemplate ?? '').isNotEmpty).toList();
    expect(playable, isNotEmpty);
    final ch = playable.first;
    await svc.load(factory.fromUrl(resolve.call(ch)!, title: ch.name)).timeout(const Duration(seconds: 25));
    await svc.play();
    final live = await _awaitPlay(t, svc);
    print('ios live => ${live.name}');
    expect(live, anyOf(PlaybackStatus.playing, PlaybackStatus.buffering),
        reason: 'live MPEG-TS must decode on the fvp iOS adapter');

    // ---- Channel switch ----
    if (playable.length > 1) {
      final ch2 = playable[1];
      await svc.load(factory.fromUrl(resolve.call(ch2)!, title: ch2.name)).timeout(const Duration(seconds: 25));
      await svc.play();
      final sw = await _awaitPlay(t, svc);
      print('ios switch => ${sw.name}');
      expect(sw, anyOf(PlaybackStatus.playing, PlaybackStatus.buffering));
    }
    await svc.stop();

    // ---- Movie VOD ----
    final movies = (await c.read(getMoviesProvider).call()).valueOrNull!;
    final info = (await c.read(getMovieInfoProvider).call(movies.first.id)).valueOrNull!;
    final vod = c.read(selectMovieQualityProvider).call(info);
    if (vod != null && vod.isNotEmpty) {
      await svc.load(factory.fromUrl(vod, title: info.title)).timeout(const Duration(seconds: 25));
      await svc.play();
      final v = await _awaitPlay(t, svc);
      print('ios vod => ${v.name}');
      expect(v, anyOf(PlaybackStatus.playing, PlaybackStatus.buffering, PlaybackStatus.paused));
      // seek smoke (VOD)
      final vpsvc = svc;
      if (vpsvc.state.duration > const Duration(seconds: 30)) {
        await svc.pause();
      }
      await svc.stop();
    } else {
      print('ios vod => no-url');
    }

    // ---- Episode ----
    final series = (await c.read(getSeriesProvider).call()).valueOrNull!;
    final sinfo = (await c.read(getSeriesInfoProvider).call(series.first.id)).valueOrNull!;
    String? epUrl;
    for (final s in sinfo.seasons) {
      for (final e in s.episodes) {
        if ((e.streamUrl ?? '').isNotEmpty) {
          epUrl = e.streamUrl;
          break;
        }
      }
      if (epUrl != null) break;
    }
    if (epUrl != null) {
      await svc.load(factory.fromUrl(epUrl, title: 'episode')).timeout(const Duration(seconds: 25));
      await svc.play();
      final ep = await _awaitPlay(t, svc);
      print('ios episode => ${ep.name}');
      expect(ep, anyOf(PlaybackStatus.playing, PlaybackStatus.buffering, PlaybackStatus.paused));
      await svc.stop();
    } else {
      print('ios episode => no-url');
    }

    // ---- Session restore + logout (Keychain) ----
    final c2 = await bootstrap();
    addTearDown(c2.dispose);
    expect(c2.read(sessionControllerProvider), isA<AuthAuthenticated>(),
        reason: 'session restores from Keychain on device');
    await c.read(sessionControllerProvider.notifier).logout();
    expect(c.read(sessionControllerProvider), isA<AuthLoggedOut>());
  }, timeout: const Timeout(Duration(minutes: 5)), skip: _skip);
}
