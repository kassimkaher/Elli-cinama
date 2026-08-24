import '../config/app_config.dart';
import 'request_builder.dart';

/// Single mutable data-layer session state: the current (server-returned)
/// credentials plus the resolved [ServerRoles]. Updated by the session
/// controller (presentation) and read by the request builder (as
/// [CredentialSource]), the EPG datasource, and the streaming header provider.
/// Keeping it a leaf breaks the DI cycle between auth and the content layer.
class RuntimeSession implements CredentialSource {
  String? _username;
  String? _password;
  ServerRoles _roles = const ServerRoles();

  @override
  String? get username => _username;
  @override
  String? get password => _password;

  ServerRoles get roles => _roles;
  bool get hasCredentials => (_username?.isNotEmpty ?? false) && (_password != null);

  void update({
    required String? username,
    required String? password,
    required ServerRoles roles,
  }) {
    _username = username;
    _password = password;
    _roles = roles;
  }

  void clear() {
    _username = null;
    _password = null;
    _roles = const ServerRoles();
  }
}
