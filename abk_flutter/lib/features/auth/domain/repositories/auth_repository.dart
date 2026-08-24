import '../../../../core/utils/result.dart';
import '../entities/account.dart';

abstract class AuthRepository {
  Future<Result<Account>> login({required String username, required String password});

  /// Returns a persisted authenticated account, or null if none/logged out.
  Future<Account?> restoreSession();

  Future<void> logout();
}
