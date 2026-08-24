import '../logging/app_logger.dart';
import 'app_config.dart';
import 'remote_config_service.dart';

/// Resolves the effective CONTENT_API:
///   Remote Config `activity` -> validate -> else known-working fallback.
/// Supports live refresh so a rotated Remote Config value is picked up without
/// a new release.
class ContentApiResolver {
  final RemoteConfigService remoteConfig;
  final AppLogger logger;
  final Uri fallback;

  Uri? _cached;

  ContentApiResolver({
    required this.remoteConfig,
    required this.logger,
    Uri? fallback,
  }) : fallback = fallback ?? Uri.parse(AppConstants.fallbackContentApi);

  /// Last resolved value, or the fallback if not resolved yet.
  Uri get currentOrFallback => _cached ?? fallback;

  Future<Uri> resolve({Duration timeout = const Duration(seconds: 8)}) async {
    try {
      final raw = await remoteConfig.fetchActivity().timeout(timeout);
      final validated = _validate(raw);
      if (validated != null) {
        _cached = validated;
        logger.info('config', 'CONTENT_API resolved from Remote Config (host=${validated.host})');
        return validated;
      }
      logger.warn('config', 'Remote Config `activity` empty/invalid; using fallback');
    } catch (e) {
      logger.warn('config', 'Remote Config fetch failed/timeout; using fallback');
    }
    _cached ??= fallback;
    return _cached!;
  }

  Future<Uri> refresh({Duration timeout = const Duration(seconds: 8)}) {
    _cached = null;
    return resolve(timeout: timeout);
  }

  Uri? _validate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final u = Uri.tryParse(value.trim());
    if (u == null) return null;
    if (!(u.isScheme('http') || u.isScheme('https'))) return null;
    if (u.host.isEmpty) return null;
    return u;
  }
}
