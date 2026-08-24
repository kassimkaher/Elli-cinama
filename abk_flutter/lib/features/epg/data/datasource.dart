import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/errors/failures.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/runtime_session.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/utils/result.dart';
import '../domain/entities.dart';

/// Short-EPG datasource. Distinct from the content middleware: a plain,
/// NON-XOR GET to `{host}/player_api.php` with the streaming User-Agent (the
/// panel 403s unknown UAs). Empty results are a NORMAL Ok state.
class EpgRemoteDataSource {
  final http.Client httpClient;
  final RuntimeSession session;
  final AppLogger logger;
  final Duration timeout;

  EpgRemoteDataSource({
    required this.httpClient,
    required this.session,
    required this.logger,
    this.timeout = const Duration(seconds: 20),
  });

  Future<Result<List<EpgListing>>> getShortEpg(int streamId) async {
    final base = session.roles.playerApiPhp;
    if (base == null) {
      return Err(const ConfigFailure(message: 'player_api not available in session'));
    }
    final ua = (session.roles.userAgent?.isNotEmpty ?? false)
        ? session.roles.userAgent!
        : AppConstants.defaultStreamingUserAgent;

    // NOTE: this URI carries credentials — never log it unredacted.
    final uri = Uri.parse(base).replace(queryParameters: {
      'username': session.username ?? '',
      'password': session.password ?? '',
      'action': 'get_short_epg',
      'stream_id': '$streamId',
    });

    try {
      final resp = await httpClient.get(
        uri,
        headers: {'User-Agent': ua, 'Accept-Encoding': 'identity'},
      ).timeout(timeout);

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        logger.warn('epg', 'get_short_epg http=${resp.statusCode}');
        return Err(HttpFailure(resp.statusCode));
      }

      final body = resp.body.trim();
      if (body.isEmpty) return const Ok([]); // no EPG — normal

      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['epg_listings'] is List) {
        final list = (decoded['epg_listings'] as List)
            .whereType<Map>()
            .map(_fromJson)
            .toList(growable: false);
        return Ok(list);
      }
      // Panel may return `[]` when there are no listings.
      return const Ok([]);
    } on TimeoutException catch (e) {
      return Err(TimeoutFailure(cause: e));
    } on SocketException catch (e) {
      return Err(ConnectivityFailure(cause: e));
    } on http.ClientException catch (e) {
      return Err(ConnectivityFailure(message: 'Network client error', cause: e));
    } on FormatException catch (e) {
      return Err(ParseFailure(cause: e));
    } catch (e) {
      return Err(UnknownFailure(cause: e));
    }
  }

  static EpgListing _fromJson(Map json) {
    final m = asMap(json);
    return EpgListing(
      titleRaw: asStringOrNull(m['title']),
      start: asStringOrNull(m['start']),
      end: asStringOrNull(m['end']),
      startTimestamp: asStringOrNull(m['start_timestamp']),
      stopTimestamp: asStringOrNull(m['stop_timestamp']),
    );
  }
}
