import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../logging/app_logger.dart';

/// Firebase project identity used to read the operator-published Remote Config
/// key `activity`. These are public client identifiers (as embedded in any
/// APK), not secrets. The operator publishes the current CONTENT_API here, so
/// the client must read the SAME project (`eliaapro`) to pick up rotations.
class FirebaseOptionsRc {
  final String apiKey;
  final String appId;
  final String projectId;
  final String projectNumber;
  final String androidPackage;
  final String androidCertSha1;

  const FirebaseOptionsRc({
    required this.apiKey,
    required this.appId,
    required this.projectId,
    required this.projectNumber,
    required this.androidPackage,
    required this.androidCertSha1,
  });

  /// Confirmed project identity (Phase 2A).
  static const eliaapro = FirebaseOptionsRc(
    apiKey: 'AIzaSyBZyxL8c2-a9bE1IXv8zxtL-ctueI-JIrs',
    appId: '1:722642815778:android:81593e922af4127dd0737b',
    projectId: 'eliaapro',
    projectNumber: '722642815778',
    androidPackage: 'com.mbm_soft.eliaapro',
    androidCertSha1: 'FB85099F501D54139F6901B6D848D8265575BC1F',
  );
}

/// Reads a single Remote Config key. Injectable so tests/fallbacks can supply a
/// static value without any network.
abstract class RemoteConfigService {
  Future<String?> fetchActivity();
}

/// Test/offline implementation.
class StaticRemoteConfigService implements RemoteConfigService {
  final String? value;
  const StaticRemoteConfigService(this.value);
  @override
  Future<String?> fetchActivity() async => value;
}

/// Real Firebase Remote Config over its REST protocol (Installations token +
/// firebase:fetch). Pure-Dart — keeps the native build free of the Firebase
/// gradle plugin while remaining genuine Remote Config. The SDK plugin can be
/// swapped behind [RemoteConfigService] later without touching callers.
class FirebaseRestRemoteConfigService implements RemoteConfigService {
  final http.Client client;
  final FirebaseOptionsRc options;
  final AppLogger logger;

  FirebaseRestRemoteConfigService({
    required this.client,
    required this.logger,
    this.options = FirebaseOptionsRc.eliaapro,
  });

  @override
  Future<String?> fetchActivity() async {
    try {
      final token = await _registerInstallation();
      if (token == null) return null;
      final entries = await _fetchConfig(token);
      final v = entries['activity'];
      return (v is String && v.isNotEmpty) ? v : null;
    } catch (e) {
      logger.warn('remoteConfig', 'fetchActivity failed');
      return null;
    }
  }

  String _generateFid() {
    final rnd = Random.secure();
    final b = List<int>.generate(17, (_) => rnd.nextInt(256));
    b[0] = 0x70 | (b[0] & 0x0F); // version nibble 0111
    final s = base64Url.encode(b).replaceAll('=', '');
    return s.substring(0, 22);
  }

  Future<String?> _registerInstallation() async {
    final fid = _generateFid();
    final resp = await client.post(
      Uri.parse(
          'https://firebaseinstallations.googleapis.com/v1/projects/${options.projectId}/installations'),
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache',
        'X-Android-Package': options.androidPackage,
        'X-Android-Cert': options.androidCertSha1,
        'x-goog-api-key': options.apiKey,
      },
      body: jsonEncode({
        'fid': fid,
        'appId': options.appId,
        'authVersion': 'FIS_v2',
        'sdkVersion': 'a:17.0.1',
      }),
    );
    if (resp.statusCode != 200) {
      logger.warn('remoteConfig', 'FIS register http=${resp.statusCode}');
      return null;
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final auth = json['authToken'];
    final token = (auth is Map) ? auth['token'] as String? : null;
    return token;
  }

  Future<Map<String, dynamic>> _fetchConfig(String installationToken) async {
    final fid = _generateFid();
    final resp = await client.post(
      Uri.parse(
          'https://firebaseremoteconfig.googleapis.com/v1/projects/${options.projectNumber}/namespaces/firebase:fetch?key=${options.apiKey}'),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': options.apiKey,
        'X-Android-Package': options.androidPackage,
        'X-Android-Cert': options.androidCertSha1,
      },
      body: jsonEncode({
        'appInstanceId': fid,
        'appInstanceIdToken': installationToken,
        'appId': options.appId,
        'packageName': options.androidPackage,
        'languageCode': 'en-US',
        'platformVersion': '30',
        'appVersion': '1.0.0',
        'sdkVersion': '21.2.0',
      }),
    );
    if (resp.statusCode != 200) {
      logger.warn('remoteConfig', 'RC fetch http=${resp.statusCode}');
      return const {};
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final entries = json['entries'];
    return entries is Map<String, dynamic> ? entries : const {};
  }
}
