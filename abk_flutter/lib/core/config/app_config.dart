/// Confirmed constants and the four distinct server roles. These roles must
/// never be conflated (see ABK_FINAL_BACKEND_CONTRACT.md §0).
class AppConstants {
  /// Known-working fallback for CONTENT_API if Remote Config is unavailable.
  static const String fallbackContentApi = 'https://header21.b-cdn.net';

  /// User-Agent used for streaming-host / panel requests when the account
  /// `user_agent` is missing. The panel 403s unknown UAs (e.g. Python-urllib);
  /// an okhttp-style UA is accepted.
  static const String defaultStreamingUserAgent = 'okhttp/3.12.1';

  static const int loginStatusActivated = 100;
  static const int loginStatusAlt = 101;

  static bool isLoginSuccess(int? status) =>
      status == loginStatusActivated || status == loginStatusAlt;
}

/// Server roles derived from the login response. Distinct from CONTENT_API
/// (which comes from Remote Config), the streaming host, the player API and
/// the EPG API.
class ServerRoles {
  final String? streamingHost; // login `host`   — base for stream URLs
  final String? playerApi; // login `player_api`  — EPG (use `/player_api.php`)
  final String? epgApi; // login `epg_api`        — optional XMLTV (unused)
  final String? userAgent; // login `user_agent`  — playback/panel UA
  final String? timezone; // login `timezone`     — EPG time parsing

  const ServerRoles({
    this.streamingHost,
    this.playerApi,
    this.epgApi,
    this.userAgent,
    this.timezone,
  });

  /// Canonical Xtream player_api base (`{host}/player_api.php`). The middleware
  /// returns `player_api` as the panel root; get_short_epg lives at `.php`.
  String? get playerApiPhp {
    final host = (streamingHost ?? playerApi);
    if (host == null || host.isEmpty) return null;
    final trimmed = host.endsWith('/') ? host.substring(0, host.length - 1) : host;
    return '$trimmed/player_api.php';
  }
}
