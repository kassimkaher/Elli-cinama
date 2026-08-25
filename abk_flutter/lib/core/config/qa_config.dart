import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Development/QA-only test credentials.
///
/// Supplied at build time via `--dart-define` (never hard-coded, never printed):
///
///   flutter run --dart-define=ABK_QA_USERNAME=… --dart-define=ABK_QA_PASSWORD=…
///
/// When the defines are absent — as in any production/release build intended for
/// users — [qaCredentialsProvider] is `null` and the login QA-autofill helper is
/// hidden entirely. This is an autofill convenience only: it fills the fields and
/// nothing else (no auto-submit, no auth bypass).
class QaCredentials {
  final String username;
  final String password;
  const QaCredentials(this.username, this.password);
}

const _qaUser = String.fromEnvironment('ABK_QA_USERNAME');
const _qaPass = String.fromEnvironment('ABK_QA_PASSWORD');

/// Non-null only when both QA defines are present (i.e. a dev/QA build).
/// Overridable in tests to exercise the present/absent branches.
final qaCredentialsProvider = Provider<QaCredentials?>((ref) {
  if (_qaUser.isEmpty || _qaPass.isEmpty) return null;
  return const QaCredentials(_qaUser, _qaPass);
});
