// TEMP on-device iOS playback probe entrypoint.
//
// The Dart VM service is not discoverable on this device's debug bridge, which
// blocks the normal integration-test path. This entrypoint bypasses the VM
// service entirely: the app launches, runs real playback through the shared
// `PlaybackService` (fvp-backed on iOS), and writes the outcome to the app's
// Documents container — retrievable with `xcrun devicectl device copy from`.
//
// Run: flutter run -t lib/ios_probe_main.dart -d <ios-device> \
//        --dart-define=ABK_USERNAME=… --dart-define=ABK_PASSWORD=…
// Remove after iOS validation.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'app/bootstrap.dart';
import 'core/di/providers.dart';
import 'core/player/playback_service.dart';

const _user = String.fromEnvironment('ABK_USERNAME');
const _pass = String.fromEnvironment('ABK_PASSWORD');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final r = <String, dynamic>{'entry': 'ios_probe'};

  Future<String> playOnce(dynamic c, String url, String title) async {
    final svc = c.read(playbackServiceProvider) as PlaybackService;
    final factory = c.read(playbackSourceFactoryProvider);
    var outcome = 'no-terminal';
    try {
      await svc.load(factory.fromUrl(url, title: title)).timeout(const Duration(seconds: 20));
      await svc.play();
      for (var i = 0; i < 34; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final s = svc.state.status;
        if (s == PlaybackStatus.playing) {
          outcome = 'playing';
          break;
        }
        if (s == PlaybackStatus.error) {
          outcome = 'error';
          break;
        }
        if (s == PlaybackStatus.buffering) outcome = 'buffering';
      }
    } catch (e) {
      outcome = 'exception:${e.runtimeType}';
    }
    try {
      await svc.stop();
    } catch (_) {}
    return outcome;
  }

  try {
    final c = await bootstrap();
    await c.read(sessionControllerProvider.notifier).logout();
    await c.read(sessionControllerProvider.notifier).login(_user, _pass);
    r['auth'] = c.read(sessionControllerProvider).runtimeType.toString();

    final channels = (await c.read(getLiveChannelsProvider).call()).valueOrNull ?? const [];
    r['channels'] = channels.length;
    final playableLive = channels.where((x) => (x.streamUrlTemplate ?? '').isNotEmpty).toList();
    if (playableLive.isNotEmpty) {
      final ch = playableLive.first;
      final liveUrl = c.read(resolveLiveStreamUrlProvider).call(ch);
      r['live_container'] = detectContainer(liveUrl ?? '').name;
      r['live_playback'] = liveUrl == null ? 'no-url' : await playOnce(c, liveUrl, ch.name);
      if (playableLive.length > 1) {
        final ch2 = playableLive[1];
        final u2 = c.read(resolveLiveStreamUrlProvider).call(ch2);
        r['live_switch'] = u2 == null ? 'no-url' : await playOnce(c, u2, ch2.name);
      }
    }

    final movies = (await c.read(getMoviesProvider).call()).valueOrNull ?? const [];
    r['movies'] = movies.length;
    if (movies.isNotEmpty) {
      final info = (await c.read(getMovieInfoProvider).call(movies.first.id)).valueOrNull;
      final vodUrl = info == null ? null : c.read(selectMovieQualityProvider).call(info);
      r['vod_container'] = detectContainer(vodUrl ?? '').name;
      r['vod_playback'] = (vodUrl == null || vodUrl.isEmpty) ? 'no-url' : await playOnce(c, vodUrl, info!.title);
    }

    final series = (await c.read(getSeriesProvider).call()).valueOrNull ?? const [];
    r['series'] = series.length;
    if (series.isNotEmpty) {
      final sinfo = (await c.read(getSeriesInfoProvider).call(series.first.id)).valueOrNull;
      String? epUrl;
      var epTitle = 'episode';
      if (sinfo != null) {
        for (final s in sinfo.seasons) {
          for (final e in s.episodes) {
            if ((e.streamUrl ?? '').isNotEmpty) {
              epUrl = e.streamUrl;
              epTitle = e.episodeName ?? 'episode';
              break;
            }
          }
          if (epUrl != null) break;
        }
      }
      r['episode_playback'] = epUrl == null ? 'no-episode-url' : await playOnce(c, epUrl, epTitle);
    }
    r['ok'] = true;
  } catch (e, st) {
    r['fatal'] = '${e.runtimeType}: $e';
    r['stack'] = st.toString().split('\n').take(3).join(' | ');
  }

  try {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/ios_probe.json');
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(r));
    print('IOS_PROBE_WRITTEN ${f.path} :: ${jsonEncode(r)}');
  } catch (e) {
    print('IOS_PROBE_WRITE_FAILED $e :: ${jsonEncode(r)}');
  }

  runApp(WidgetsApp(
    color: const Color(0xFF000000),
    debugShowCheckedModeBanner: false,
    builder: (_, __) => const ColoredBox(color: Color(0xFF000000)),
  ));
}
