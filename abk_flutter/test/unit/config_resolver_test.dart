import 'package:abk_player/core/config/content_api_resolver.dart';
import 'package:abk_player/core/config/remote_config_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('ContentApiResolver', () {
    test('valid Remote Config value is used', () async {
      final r = ContentApiResolver(
        remoteConfig: const StaticRemoteConfigService('https://cfg.example'),
        logger: silentLogger(),
      );
      expect((await r.resolve()).host, 'cfg.example');
    });

    test('empty Remote Config falls back', () async {
      final r = ContentApiResolver(
        remoteConfig: const StaticRemoteConfigService(''),
        logger: silentLogger(),
        fallback: Uri.parse('https://fb.example'),
      );
      expect((await r.resolve()).host, 'fb.example');
    });

    test('invalid scheme falls back', () async {
      final r = ContentApiResolver(
        remoteConfig: const StaticRemoteConfigService('ftp://bad.example'),
        logger: silentLogger(),
        fallback: Uri.parse('https://fb.example'),
      );
      expect((await r.resolve()).host, 'fb.example');
    });

    test('default fallback is the confirmed header21 host', () async {
      final r = ContentApiResolver(
        remoteConfig: const StaticRemoteConfigService(null),
        logger: silentLogger(),
      );
      expect((await r.resolve()).host, 'header21.b-cdn.net');
    });

    test('refresh re-resolves', () async {
      final r = ContentApiResolver(
        remoteConfig: const StaticRemoteConfigService('https://a.example'),
        logger: silentLogger(),
      );
      await r.resolve();
      expect(r.currentOrFallback.host, 'a.example');
      final refreshed = await r.refresh();
      expect(refreshed.host, 'a.example');
    });
  });
}
