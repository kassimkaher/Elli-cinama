import '../../../../core/utils/json_utils.dart';
import '../../domain/entities/account.dart';

/// Maps the login response JSON <-> [Account]. Also used to (de)serialize the
/// persisted session in secure storage.
class AccountModel {
  static Account fromJson(Map json) {
    final m = asMap(json);
    return Account(
      status: asIntOrNull(m['status']),
      message: asString(m['message']),
      host: asStringOrNull(m['host']),
      playerApi: asStringOrNull(m['player_api']),
      epgApi: asStringOrNull(m['epg_api']),
      username: asStringOrNull(m['username']),
      password: asStringOrNull(m['password']),
      userAgent: asStringOrNull(m['user_agent']),
      timezone: asStringOrNull(m['timezone']),
      expire: asStringOrNull(m['expire']),
      apkVerCode: asStringOrNull(m['apk_ver_code']),
      forceUpdate: asIntOrNull(m['force_update']),
      updateUrl: asStringOrNull(m['update_url']),
    );
  }

  static Map<String, dynamic> toJson(Account a) => {
        'status': a.status,
        'message': a.message,
        'host': a.host,
        'player_api': a.playerApi,
        'epg_api': a.epgApi,
        'username': a.username,
        'password': a.password,
        'user_agent': a.userAgent,
        'timezone': a.timezone,
        'expire': a.expire,
        'apk_ver_code': a.apkVerCode,
        'force_update': a.forceUpdate,
        'update_url': a.updateUrl,
      };
}
