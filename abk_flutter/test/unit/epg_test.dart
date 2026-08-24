import 'dart:convert';

import 'package:abk_player/core/config/app_config.dart';
import 'package:abk_player/core/errors/failures.dart';
import 'package:abk_player/core/network/runtime_session.dart';
import 'package:abk_player/core/utils/result.dart';
import 'package:abk_player/features/epg/data/datasource.dart';
import 'package:abk_player/features/epg/domain/entities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

RuntimeSession _session() {
  final s = RuntimeSession();
  s.update(
    username: 'u',
    password: 'p',
    roles: const ServerRoles(streamingHost: 'http://h:80', userAgent: 'UA'),
  );
  return s;
}

EpgRemoteDataSource _ds(Future<http.Response> Function(http.Request) handler) =>
    EpgRemoteDataSource(
      httpClient: MockClient(handler),
      session: _session(),
      logger: silentLogger(),
    );

void main() {
  test('EpgListing decodes Base64 title', () {
    final e = EpgListing(titleRaw: base64.encode(utf8.encode('Now Playing')));
    expect(e.title, 'Now Playing');
  });

  test('empty body is a normal empty result (not a failure)', () async {
    final ds = _ds((req) async => http.Response('', 200));
    final res = await ds.getShortEpg(1);
    expect(res, isA<Ok>());
    expect((res as Ok).value, isEmpty);
  });

  test('array [] response is a normal empty result', () async {
    final ds = _ds((req) async => http.Response('[]', 200));
    final res = await ds.getShortEpg(1);
    expect((res as Ok).value, isEmpty);
  });

  test('populated epg_listings are parsed with decoded titles', () async {
    final body = jsonEncode({
      'epg_listings': [
        {
          'title': base64.encode(utf8.encode('Match')),
          'start': '2026-08-24 20:00:00',
          'end': '2026-08-24 22:00:00',
        }
      ]
    });
    final ds = _ds((req) async => http.Response(body, 200));
    final res = await ds.getShortEpg(1);
    final list = (res as Ok).value;
    expect(list.length, 1);
    expect(list.first.title, 'Match');
    expect(list.first.start, '2026-08-24 20:00:00');
  });

  test('403 maps to HttpFailure', () async {
    final ds = _ds((req) async => http.Response('forbidden', 403));
    final res = await ds.getShortEpg(1);
    expect((res as Err).failure, isA<HttpFailure>());
  });

  test('a valid User-Agent is always sent', () async {
    late http.Request captured;
    final ds = _ds((req) async {
      captured = req;
      return http.Response('', 200);
    });
    await ds.getShortEpg(1);
    expect(captured.headers['User-Agent'], 'UA');
    expect(captured.url.queryParameters['action'], 'get_short_epg');
  });
}
