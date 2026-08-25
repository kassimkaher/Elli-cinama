import 'package:abk_player/core/errors/failures.dart';
import 'package:abk_player/core/network/content_client.dart';
import 'package:abk_player/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers.dart';

void main() {
  group('ContentClient', () {
    test('callObject decodes a XOR object response', () async {
      final client = contentClientWith(
          (req) async => contentResponse({'status': 100, 'message': 'ok'}));
      final res = await client.callObject(
        payload: {'mode': 'login'},
        decoder: (j) => (j as Map)['status'],
      );
      expect(res, isA<Ok>());
      expect((res as Ok).value, 100);
    });

    test('request is a form POST with a json field', () async {
      late http.Request captured;
      final client = contentClientWith((req) async {
        captured = req;
        return contentResponse([]);
      });
      await client.callList(payload: {'mode': 'packages'}, itemDecoder: (j) => j);
      expect(captured.method, 'POST');
      expect(captured.headers['Content-Type'], contains('x-www-form-urlencoded'));
      expect(captured.body.startsWith('json='), isTrue);
      expect(captured.body.length, greaterThan('json='.length));
    });

    test('callList decodes a XOR array response', () async {
      final client = contentClientWith((req) async => contentResponse([
            {'id': '1'},
            {'id': '2'},
          ]));
      final res = await client.callList(
        payload: {'mode': 'packages'},
        itemDecoder: (j) => (j as Map)['id'],
      );
      expect((res as Ok).value, ['1', '2']);
    });

    test('non-2xx maps to HttpFailure (body not decoded)', () async {
      final client = contentClientWith((req) async => http.Response('nope', 403));
      final res = await client.callObject(payload: {'mode': 'login'}, decoder: (j) => j);
      expect(res, isA<Err>());
      final f = (res as Err).failure;
      expect(f, isA<HttpFailure>());
      expect((f as HttpFailure).statusCode, 403);
    });

    test('empty body maps to EmptyResultFailure', () async {
      final client = contentClientWith((req) async => http.Response.bytes([], 200));
      final res = await client.callObject(payload: {'mode': 'login'}, decoder: (j) => j);
      expect((res as Err).failure, isA<EmptyResultFailure>());
    });

    test('object decoder on an array response maps to ParseFailure', () async {
      final client = contentClientWith((req) async => contentResponse([1, 2, 3]));
      final res = await client.callObject(payload: {'mode': 'login'}, decoder: (j) => j);
      expect((res as Err).failure, isA<ParseFailure>());
    });

    test('list decoder on an object response maps to ParseFailure', () async {
      final client = contentClientWith((req) async => contentResponse({'a': 1}));
      final res = await client.callList(payload: {'mode': 'packages'}, itemDecoder: (j) => j);
      expect((res as Err).failure, isA<ParseFailure>());
    });

    test('large array (> isolate threshold) decodes correctly', () async {
      final big = List.generate(20000, (i) => {'id': '$i'});
      final client = contentClientWith((req) async => contentResponse(big));
      final res = await client.callList(
        payload: {'mode': 'channels'},
        itemDecoder: (j) => (j as Map)['id'],
      );
      final ok = res as Ok;
      expect(ok.value.length, 20000);
      expect(ok.value.first, '0');
    });

    test('retries once on a transient error, then succeeds', () async {
      var calls = 0;
      final client = contentClientWith((req) async {
        calls++;
        if (calls == 1) {
          throw http.ClientException('transient reset');
        }
        return contentResponse([
          {'id': '1'},
          {'id': '2'},
        ]);
      });
      final res = await client.callList(
        payload: {'mode': 'channels'},
        itemDecoder: (j) => (j as Map)['id'],
      );
      expect(calls, 2, reason: 'first attempt failed, retry succeeded');
      expect((res as Ok).value, ['1', '2']);
    });

    test('gives up after maxAttempts on a persistent transient error', () async {
      var calls = 0;
      final client = contentClientWith((req) async {
        calls++;
        throw http.ClientException('down');
      });
      final res = await client.callList(payload: {'mode': 'channels'}, itemDecoder: (j) => j);
      expect(calls, ContentClient.maxAttempts);
      expect((res as Err).failure, isA<ConnectivityFailure>());
    });

    test('does not retry a deterministic HTTP failure', () async {
      var calls = 0;
      final client = contentClientWith((req) async {
        calls++;
        return http.Response('nope', 403);
      });
      final res = await client.callObject(payload: {'mode': 'login'}, decoder: (j) => j);
      expect(calls, 1, reason: 'HTTP status is deterministic — no retry');
      expect((res as Err).failure, isA<HttpFailure>());
    });
  });
}
