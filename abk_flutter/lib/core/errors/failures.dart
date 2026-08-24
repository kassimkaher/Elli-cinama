/// Typed failure taxonomy. Every layer maps errors to one of these — no
/// swallowed errors, no leaking raw exceptions to the UI.
sealed class Failure {
  final String message;
  final Object? cause;
  const Failure(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';
}

/// No network / DNS / socket.
class ConnectivityFailure extends Failure {
  const ConnectivityFailure({String message = 'No network connectivity', Object? cause})
      : super(message, cause: cause);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure({String message = 'Request timed out', Object? cause})
      : super(message, cause: cause);
}

/// Non-2xx HTTP status.
class HttpFailure extends Failure {
  final int statusCode;
  const HttpFailure(this.statusCode, {String? message, Object? cause})
      : super(message ?? 'HTTP $statusCode', cause: cause);
}

/// XOR decode of the response body failed.
class DecodeFailure extends Failure {
  const DecodeFailure({String message = 'Response decode failed', Object? cause})
      : super(message, cause: cause);
}

/// Body decoded but was not valid/expected JSON shape.
class ParseFailure extends Failure {
  const ParseFailure({String message = 'Malformed or unexpected JSON', Object? cause})
      : super(message, cause: cause);
}

/// Backend returned a well-formed response indicating logical failure
/// (e.g. login status not in {100,101}).
class BackendLogicalFailure extends Failure {
  final int? status;
  const BackendLogicalFailure({required String message, this.status, Object? cause})
      : super(message, cause: cause);
}

/// Valid response, but empty where content was expected.
class EmptyResultFailure extends Failure {
  const EmptyResultFailure({String message = 'Empty result', Object? cause})
      : super(message, cause: cause);
}

/// Runtime configuration (content API resolution) failed.
class ConfigFailure extends Failure {
  const ConfigFailure({String message = 'Configuration unavailable', Object? cause})
      : super(message, cause: cause);
}

/// Authentication rejected / no session.
class AuthFailure extends Failure {
  const AuthFailure({String message = 'Authentication failed', Object? cause})
      : super(message, cause: cause);
}

class UnknownFailure extends Failure {
  const UnknownFailure({String message = 'Unexpected error', Object? cause})
      : super(message, cause: cause);
}
