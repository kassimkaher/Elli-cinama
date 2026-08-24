import '../device/device_envelope.dart';

/// Supplies the credentials used for content requests. Implemented by the
/// session controller so downstream calls always use the server-returned
/// (possibly rewritten) username/password.
abstract class CredentialSource {
  String? get username;
  String? get password;
}

/// Builds the confirmed content payload envelope for a `mode`:
/// `{ code:"00000000", user, pass, mac, sn, model, group:0, mode, ...extra }`.
class ContentRequestBuilder {
  final CredentialSource credentials;
  final DeviceEnvelope device;

  ContentRequestBuilder({required this.credentials, required this.device});

  Map<String, dynamic> build(String mode, {Map<String, dynamic>? extra}) => {
        'code': '00000000',
        'user': credentials.username ?? '',
        'pass': credentials.password ?? '',
        ...device.toPayload(),
        'mode': mode,
        if (extra != null) ...extra,
      };

  /// Explicit login payload using freshly-entered credentials (before a
  /// session exists).
  Map<String, dynamic> buildLogin({
    required String username,
    required String password,
  }) =>
      {
        'code': '00000000',
        'user': username,
        'pass': password,
        ...device.toPayload(),
        'mode': 'login',
      };
}
