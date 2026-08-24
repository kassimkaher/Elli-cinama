import 'dart:convert';

import '../../../../core/storage/secure_store.dart';
import '../../domain/entities/account.dart';
import '../models/account_model.dart';

/// Persists the authenticated session (including server-returned credentials)
/// ONLY in secure storage.
class SessionLocalDataSource {
  final SecureStore secure;
  static const _key = 'session_account_v1';

  SessionLocalDataSource(this.secure);

  Future<void> save(Account account) =>
      secure.write(_key, jsonEncode(AccountModel.toJson(account)));

  Future<Account?> load() async {
    final raw = await secure.read(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AccountModel.fromJson(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() => secure.delete(_key);
}
