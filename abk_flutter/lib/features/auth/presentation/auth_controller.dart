import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/runtime_session.dart';
import '../../../../core/utils/result.dart';
import '../domain/entities/account.dart';
import '../domain/usecases/auth_usecases.dart';

/// Explicit auth states (contract §6): logged-out, authenticating,
/// authenticated, and typed error (auth / config / network).
sealed class AuthState {
  const AuthState();
}

class AuthLoggedOut extends AuthState {
  const AuthLoggedOut();
}

class AuthAuthenticating extends AuthState {
  const AuthAuthenticating();
}

class AuthAuthenticated extends AuthState {
  final Account account;
  const AuthAuthenticated(this.account);
}

enum AuthErrorKind { auth, config, network, unknown }

class AuthError extends AuthState {
  final Failure failure;
  final AuthErrorKind kind;
  const AuthError(this.failure, this.kind);
}

class SessionController extends StateNotifier<AuthState> {
  final LoginUseCase loginUseCase;
  final LogoutUseCase logoutUseCase;
  final RestoreSessionUseCase restoreUseCase;
  final RuntimeSession session;

  SessionController({
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.restoreUseCase,
    required this.session,
  }) : super(const AuthLoggedOut());

  Account? get account =>
      state is AuthAuthenticated ? (state as AuthAuthenticated).account : null;

  Future<void> restore() async {
    final acc = await restoreUseCase();
    if (acc != null && acc.isSuccess) {
      session.update(username: acc.username, password: acc.password, roles: acc.roles);
      state = AuthAuthenticated(acc);
    } else {
      session.clear();
      state = const AuthLoggedOut();
    }
  }

  Future<void> login(String username, String password) async {
    state = const AuthAuthenticating();
    final res = await loginUseCase(username: username, password: password);
    switch (res) {
      case Ok(:final value):
        session.update(
          username: value.username ?? username,
          password: value.password ?? password,
          roles: value.roles,
        );
        state = AuthAuthenticated(value);
      case Err(:final failure):
        session.clear();
        state = AuthError(failure, _kindOf(failure));
    }
  }

  Future<void> logout() async {
    await logoutUseCase();
    session.clear();
    state = const AuthLoggedOut();
  }

  AuthErrorKind _kindOf(Failure f) => switch (f) {
        ConfigFailure() => AuthErrorKind.config,
        ConnectivityFailure() || TimeoutFailure() || HttpFailure() => AuthErrorKind.network,
        BackendLogicalFailure() || AuthFailure() => AuthErrorKind.auth,
        _ => AuthErrorKind.unknown,
      };
}
