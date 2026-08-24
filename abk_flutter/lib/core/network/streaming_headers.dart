import '../config/app_config.dart';

/// Header provider for streaming-host / panel (EPG) requests — a distinct
/// concern from the content-middleware transport. The panel returns HTTP 403
/// for unknown User-Agents, so a valid UA is always sent (account `user_agent`
/// when available, else an okhttp-style fallback).
class StreamingHeaders {
  final ServerRoles roles;
  const StreamingHeaders(this.roles);

  String get userAgent {
    final ua = roles.userAgent;
    return (ua != null && ua.isNotEmpty) ? ua : AppConstants.defaultStreamingUserAgent;
  }

  Map<String, String> headers() => {'User-Agent': userAgent};
}
