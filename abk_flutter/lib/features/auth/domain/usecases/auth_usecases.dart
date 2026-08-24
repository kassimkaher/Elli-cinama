import '../../../../core/utils/result.dart';
import '../entities/account.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repo;
  LoginUseCase(this.repo);
  Future<Result<Account>> call({required String username, required String password}) =>
      repo.login(username: username, password: password);
}

class LogoutUseCase {
  final AuthRepository repo;
  LogoutUseCase(this.repo);
  Future<void> call() => repo.logout();
}

class RestoreSessionUseCase {
  final AuthRepository repo;
  RestoreSessionUseCase(this.repo);
  Future<Account?> call() => repo.restoreSession();
}
