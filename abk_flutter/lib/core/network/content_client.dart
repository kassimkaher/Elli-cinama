import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;

import '../config/content_api_resolver.dart';
import '../errors/failures.dart';
import '../logging/app_logger.dart';
import '../utils/result.dart';
import 'xor_codec.dart';

typedef JsonDecoder<T> = T Function(Object json);

/// Content middleware transport. Every content operation is a
/// `POST {CONTENT_API}` with a single form field `json` = XOR(payload).
/// Transport-only: callers pass a fully-built payload map (mode + envelope).
///
/// Heavy XOR+JSON decoding of large catalogue responses runs off the UI isolate.
class ContentClient {
  final http.Client httpClient;
  final XorCodec codec;
  final ContentApiResolver resolver;
  final AppLogger logger;
  final Duration timeout;

  /// Responses larger than this are decoded in a background isolate.
  static const int isolateThresholdBytes = 64 * 1024;

  ContentClient({
    required this.httpClient,
    required this.codec,
    required this.resolver,
    required this.logger,
    this.timeout = const Duration(seconds: 45),
  });

  Future<Result<T>> callObject<T>({
    required Map<String, dynamic> payload,
    required JsonDecoder<T> decoder,
  }) async {
    return _call(payload, (json) {
      if (json is! Map) {
        throw const FormatException('Expected a JSON object');
      }
      return decoder(json);
    });
  }

  Future<Result<List<T>>> callList<T>({
    required Map<String, dynamic> payload,
    required JsonDecoder<T> itemDecoder,
  }) async {
    return _call(payload, (json) {
      if (json is! List) {
        throw const FormatException('Expected a JSON array');
      }
      return json.map((e) => itemDecoder(e as Object)).toList(growable: false);
    });
  }

  /// Total attempts per call. A single transient failure (timeout/connectivity)
  /// on a large-catalogue payload retries once with a short backoff before
  /// surfacing a recoverable error to the UI. Deterministic failures
  /// (HTTP status, parse, decode) never retry.
  static const int maxAttempts = 2;

  Future<Result<R>> _call<R>(
    Map<String, dynamic> payload,
    R Function(Object json) shape,
  ) async {
    final uri = resolver.currentOrFallback;
    final mode = payload['mode']?.toString() ?? '(none)';

    final String body;
    try {
      final cipher = codec.encodeString(jsonEncode(payload));
      body = 'json=${_percentEncodeBytes(cipher)}';
    } catch (e) {
      logger.error('content', 'mode=$mode payload encode failed', e);
      return Err(UnknownFailure(cause: e));
    }

    Failure transient = const TimeoutFailure();
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final resp = await httpClient
            .post(
              uri,
              headers: const {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Accept-Encoding': 'identity',
              },
              body: body,
              encoding: latin1,
            )
            .timeout(timeout);

        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          logger.warn('content', 'mode=$mode http=${resp.statusCode}');
          return Err(HttpFailure(resp.statusCode));
        }

        final bytes = resp.bodyBytes;
        if (bytes.isEmpty) {
          return Err(const EmptyResultFailure(message: 'Empty response body'));
        }

        final Object decoded;
        try {
          decoded = bytes.length > isolateThresholdBytes
              ? (await compute(decodeContentJson, (bytes, codec.key)) as Object)
              : (_decodeInline(bytes) as Object);
        } on FormatException catch (e) {
          logger.warn('content', 'mode=$mode JSON parse failed');
          return Err(ParseFailure(cause: e));
        } catch (e) {
          logger.warn('content', 'mode=$mode decode failed');
          return Err(DecodeFailure(cause: e));
        }

        try {
          return Ok(shape(decoded));
        } on FormatException catch (e) {
          return Err(ParseFailure(message: e.message, cause: e));
        } catch (e) {
          return Err(ParseFailure(cause: e));
        }
      } on TimeoutException catch (e) {
        logger.warn('content', 'mode=$mode timeout (attempt $attempt/$maxAttempts)');
        transient = TimeoutFailure(cause: e);
      } on SocketException catch (e) {
        logger.warn('content', 'mode=$mode connectivity error (attempt $attempt/$maxAttempts)');
        transient = ConnectivityFailure(cause: e);
      } on http.ClientException catch (e) {
        logger.warn('content', 'mode=$mode client error (attempt $attempt/$maxAttempts)');
        transient = ConnectivityFailure(message: 'Network client error', cause: e);
      } catch (e) {
        logger.error('content', 'mode=$mode unexpected error', e);
        return Err(UnknownFailure(cause: e));
      }
      if (attempt < maxAttempts) {
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    return Err(transient);
  }

  Object? _decodeInline(Uint8List bytes) => decodeContentJson((bytes, codec.key));

  /// Percent-encode arbitrary bytes for an x-www-form-urlencoded value
  /// (unreserved chars pass through; everything else -> %XX). Matches the
  /// middleware's expectation.
  static final Set<int> _unreserved = {
    for (final c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~'.codeUnits)
      c
  };

  static String _percentEncodeBytes(Uint8List data) {
    final sb = StringBuffer();
    for (final b in data) {
      if (_unreserved.contains(b)) {
        sb.writeCharCode(b);
      } else {
        sb.write('%');
        sb.write(b.toRadixString(16).padLeft(2, '0').toUpperCase());
      }
    }
    return sb.toString();
  }
}

/// Top-level so it can run under `compute`. XOR-decodes bytes, trims, JSON-parses.
Object? decodeContentJson((Uint8List, Uint8List) message) {
  final (body, key) = message;
  final klen = key.length;
  final out = Uint8List(body.length);
  for (var i = 0; i < body.length; i++) {
    out[i] = body[i] ^ key[i % klen];
  }
  final text = utf8.decode(out, allowMalformed: true).trim();
  return jsonDecode(text);
}
