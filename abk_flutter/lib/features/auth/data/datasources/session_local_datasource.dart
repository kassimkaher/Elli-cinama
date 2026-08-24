import 'dart:convert';

import '../../../../core/storage/secure_store.dart';
import '../../domain/entities/account.dart';
import '../models/account_model.dart';

/// Persists the authenticated session (including server-returned credentials)
/// ONLY in secure storage. All secure-store access is resilient: a platform
/// failure (e.g. a missing macOS Keychain entitlement) degrades cleanly to a
/// non-persistent session rather than crashing startup or login.
class SessionLocalDataSource {
  final SecureStore secure;
  static const _key = 'session_account_v1';

  SessionLocalDataSource(this.secure);

  /// Returns true if the session was persisted, false if secure storage failed.
  Future<bool> save(Account account) async {
    try {
      await secure.write(_key, jsonEncode(AccountModel.toJson(account)));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Account?> load() async {
    try {
      final raw = await secure.read(_key);
      if (raw == null || raw.isEmpty) return null;
      return AccountModel.fromJson(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await secure.delete(_key);
    } catch (_) {
      // best-effort
    }
  }
}
