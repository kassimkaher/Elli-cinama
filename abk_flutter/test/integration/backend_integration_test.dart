// Data-layer integration test against the AUTHORIZED live backend.
// Credentials come ONLY from environment variables and are never printed:
//   ABK_USERNAME, ABK_PASSWORD  (required)
//   ABK_CONTENT_BASE_URL        (optional; default https://header21.b-cdn.net)
// Skips automatically when credentials are absent.
//
// Run: flutter test test/integration/backend_integration_test.dart
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:abk_player/core/config/app_config.dart';
import 'package:abk_player/core/config/content_api_resolver.dart';
import 'package:abk_player/core/config/remote_config_service.dart';
import 'package:abk_player/core/device/device_envelope.dart';
import 'package:abk_player/core/logging/app_logger.dart';
import 'package:abk_player/core/logging/redaction.dart';
import 'package:abk_player/core/network/content_client.dart';
import 'package:abk_player/core/network/request_builder.dart';
import 'package:abk_player/core/network/runtime_session.dart';
import 'package:abk_player/core/network/xor_codec.dart';
import 'package:abk_player/core/utils/result.dart';
import 'package:abk_player/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:abk_player/features/epg/data/datasource.dart';
import 'package:abk_player/features/live/data/datasource.dart';
import 'package:abk_player/features/movies/data/datasource.dart';
import 'package:abk_player/features/series/data/datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  final user = Platform.environment['ABK_USERNAME'];
  final pass = Platform.environment['ABK_PASSWORD'];
  final base = Platform.environment['ABK_CONTENT_BASE_URL'] ?? AppConstants.fallbackContentApi;
  final skip = (user == null || pass == null)
      ? 'ABK_USERNAME/ABK_PASSWORD not set — skipping live integration'
      : false;

  test('full backend chain: login → packages → channels → stream → movies → series → epg',
      () async {
    final redactor = Redactor()
      ..registerSecret(user)
      ..registerSecret(pass);
    final logger = AppLogger(redactor: redactor, sink: (_) {});
    final httpClient = http.Client();
    addTearDown(httpClient.close);

    final resolver = ContentApiResolver(
      remoteConfig: const StaticRemoteConfigService(null),
      logger: logger,
      fallback: Uri.parse(base),
    );
    final session = RuntimeSession();
    final builder = ContentRequestBuilder(
      credentials: session,
      device: const DeviceEnvelope(mac: '02:00:00:00:00:00', sn: '02:00:00:00:00:00', model: 'generic'),
    );
    final client = ContentClient(
      httpClient: httpClient,
      codec: XorCodec.abk(),
      resolver: resolver,
      logger: logger,
    );

    // 1) LOGIN
    final auth = AuthRemoteDataSource(client: client, builder: builder);
    final loginRes = await auth.login(username: user!, password: pass!);
    expect(loginRes, isA<Ok>(), reason: 'login should succeed');
    final account = loginRes.valueOrNull!;
    expect(account.isSuccess, isTrue);
    session.update(
      username: account.username ?? user,
      password: account.password ?? pass,
      roles: account.roles,
    );
    print('login: status=${account.status} rewrite_user=${account.username != user} '
        'streaming_host=${Uri.tryParse(account.host ?? '')?.host}');

    // 2) PACKAGES
    final live = LiveRemoteDataSource(client: client, builder: builder);
    final cats = await live.getCategories();
    expect(cats, isA<Ok>());
    final catList = cats.valueOrNull!;
    expect(catList, isNotEmpty);
    print('packages: ${catList.length} categories');

    // 3) CHANNELS
    final chans = await live.getChannels();
    expect(chans, isA<Ok>());
    final chanList = chans.valueOrNull!;
    expect(chanList, isNotEmpty);
    final withUrl = chanList.where((c) => (c.streamUrlTemplate ?? '').isNotEmpty).length;
    final withTpl = chanList.where((c) => (c.streamUrlTemplate ?? '').contains('{user}')).length;
    print('channels: ${chanList.length} total, $withUrl with stream_url, $withTpl templated');
    expect(withUrl, greaterThan(0));

    // 4) LIVE URL + media reachability
    final ch = chanList.firstWhere((c) => (c.streamUrlTemplate ?? '').isNotEmpty);
    final url = ch.streamUrlTemplate!
        .replaceAll('{user}', session.username ?? '')
        .replaceAll('{pass}', session.password ?? '');
    final ua = (account.userAgent?.isNotEmpty ?? false)
        ? account.userAgent!
        : AppConstants.defaultStreamingUserAgent;
    final media = await _probeMedia(httpClient, url, ua);
    print('live stream: http=${media.$1} type=${media.$2} '
        'url=${redactor.redactUrl(url)}');
    expect(media.$1, lessThan(400), reason: 'stream should be reachable');

    // 5) MOVIES
    final movies = MovieRemoteDataSource(client: client, builder: builder);
    final mcats = await movies.getCategories();
    final mlist = await movies.getMovies();
    expect(mcats, isA<Ok>());
    expect(mlist, isA<Ok>());
    final firstMovieId = mlist.valueOrNull!.first.id;
    final minfo = await movies.getMovieInfo(firstMovieId);
    expect(minfo, isA<Ok>());
    final q = minfo.valueOrNull!.streamUrl;
    print('movies: cats=${mcats.valueOrNull!.length} list=${mlist.valueOrNull!.length} '
        'info.best=${q.best != null}');

    // 6) SERIES
    final series = SeriesRemoteDataSource(client: client, builder: builder);
    final scats = await series.getCategories();
    final slist = await series.getSeries();
    expect(scats, isA<Ok>());
    expect(slist, isA<Ok>());
    final firstSeriesId = slist.valueOrNull!.first.id;
    final sinfo = await series.getSeriesInfo(firstSeriesId);
    expect(sinfo, isA<Ok>());
    print('series: cats=${scats.valueOrNull!.length} list=${slist.valueOrNull!.length} '
        'seasons=${sinfo.valueOrNull!.seasons.length}');

    // 7) EPG (empty is acceptable)
    final epg = EpgRemoteDataSource(httpClient: httpClient, session: session, logger: logger);
    final epgRes = await epg.getShortEpg(ch.id);
    epgRes.fold(
      (list) => print('epg: reachable, listings=${list.length} '
          '(empty is normal — has_epg=${ch.hasEpg})'),
      (f) => print('epg: ${f.runtimeType} ${f.message}'),
    );
    expect(epgRes, isA<Ok>(), reason: 'EPG transport should succeed (empty allowed)');
  }, timeout: const Timeout(Duration(minutes: 3)), skip: skip);
}

/// Minimal media reachability: reads the first chunk, classifies, stops.
Future<(int, String)> _probeMedia(http.Client client, String url, String ua) async {
  try {
    final req = http.Request('GET', Uri.parse(url))
      ..followRedirects = true
      ..headers.addAll({'User-Agent': ua, 'Range': 'bytes=0-4095'});
    final resp = await client.send(req).timeout(const Duration(seconds: 20));
    final ct = resp.headers['content-type'] ?? '';
    String kind = 'unknown';
    try {
      final chunk = await resp.stream.first.timeout(const Duration(seconds: 15));
      if (chunk.isNotEmpty && chunk[0] == 0x47) {
        kind = 'mpeg-ts';
      } else if (String.fromCharCodes(chunk.take(7)) == '#EXTM3U') {
        kind = 'hls';
      } else if (ct.contains('mpegurl')) {
        kind = 'hls';
      } else if (ct.contains('mp2t') || ct.contains('video')) {
        kind = 'video';
      }
    } catch (_) {}
    return (resp.statusCode, '$kind ($ct)');
  } catch (e) {
    return (599, 'error:${e.runtimeType}');
  }
}
