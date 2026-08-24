import 'dart:convert';
import 'dart:typed_data';

import 'package:abk_player/core/config/content_api_resolver.dart';
import 'package:abk_player/core/config/remote_config_service.dart';
import 'package:abk_player/core/logging/app_logger.dart';
import 'package:abk_player/core/logging/redaction.dart';
import 'package:abk_player/core/network/content_client.dart';
import 'package:abk_player/core/network/xor_codec.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// XOR-encode a JSON value the way the middleware returns it.
Uint8List encodeContent(Object json) =>
    XorCodec.abk().encodeString(jsonEncode(json));

AppLogger silentLogger() => AppLogger(redactor: Redactor(), sink: (_) {});

/// Builds a [ContentClient] whose HTTP layer is a [MockClient]. The resolver
/// uses [base] as its fallback so no network/Remote Config is touched.
ContentClient contentClientWith(
  Future<http.Response> Function(http.Request request) handler, {
  String base = 'https://content.test',
}) {
  final logger = silentLogger();
  final resolver = ContentApiResolver(
    remoteConfig: const StaticRemoteConfigService(null),
    logger: logger,
    fallback: Uri.parse(base),
  );
  return ContentClient(
    httpClient: MockClient(handler),
    codec: XorCodec.abk(),
    resolver: resolver,
    logger: logger,
  );
}

http.Response contentResponse(Object json, {int status = 200}) =>
    http.Response.bytes(encodeContent(json), status, headers: {
      'content-type': 'text/plain',
    });
