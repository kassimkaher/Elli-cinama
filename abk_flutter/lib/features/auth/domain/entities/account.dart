import '../../../../core/config/app_config.dart';

/// The login/activation account object (contract §2). Also carries the server
/// roles the rest of the app depends on.
class Account {
  final int? status;
  final String message;
  final String? host; // streaming host
  final String? playerApi; // EPG base
  final String? epgApi; // optional XMLTV (unused)
  final String? username; // may be server-rewritten
  final String? password; // may be server-rewritten
  final String? userAgent; // playback/panel UA
  final String? timezone;
  final String? expire;
  final String? apkVerCode;
  final int? forceUpdate;
  final String? updateUrl;

  const Account({
    required this.status,
    required this.message,
    this.host,
    this.playerApi,
    this.epgApi,
    this.username,
    this.password,
    this.userAgent,
    this.timezone,
    this.expire,
    this.apkVerCode,
    this.forceUpdate,
    this.updateUrl,
  });

  bool get isSuccess => AppConstants.isLoginSuccess(status);

  ServerRoles get roles => ServerRoles(
        streamingHost: host,
        playerApi: playerApi,
        epgApi: epgApi,
        userAgent: userAgent,
        timezone: timezone,
      );
}
