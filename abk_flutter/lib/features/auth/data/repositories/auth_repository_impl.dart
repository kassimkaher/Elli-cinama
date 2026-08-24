import '../../../../core/errors/failures.dart';
import '../../../../core/logging/redaction.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/session_local_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remote;
  final SessionLocalDataSource local;
  final Redactor redactor;

  AuthRepositoryImpl({
    required this.remote,
    required this.local,
    required this.redactor,
  });

  @override
  Future<Result<Account>> login({
    required String username,
    required String password,
  }) async {
    // Register secrets for redaction before any request/log.
    redactor.registerSecret(username);
    redactor.registerSecret(password);

    final res = await remote.login(username: username, password: password);
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (!value.isSuccess) {
          return Err(BackendLogicalFailure(
            message: value.message.isNotEmpty ? value.message : 'Login rejected',
            status: value.status,
          ));
        }
        // Server may rewrite credentials — register those too, then persist.
        redactor.registerSecret(value.username);
        redactor.registerSecret(value.password);
        await local.save(value);
        return Ok(value);
    }
  }

  @override
  Future<Account?> restoreSession() async {
    final account = await local.load();
    if (account != null) {
      redactor.registerSecret(account.username);
      redactor.registerSecret(account.password);
    }
    return account;
  }

  @override
  Future<void> logout() => local.clear();
}
