import '../errors/failures.dart';

/// Lightweight Result type used by repositories and use cases so callers must
/// handle both branches explicitly.
sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  T? get valueOrNull => this is Ok<T> ? (this as Ok<T>).value : null;
  Failure? get failureOrNull => this is Err<T> ? (this as Err<T>).failure : null;

  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) {
    final self = this;
    return self is Ok<T> ? onOk(self.value) : onErr((self as Err<T>).failure);
  }

  Result<R> map<R>(R Function(T value) transform) {
    final self = this;
    return self is Ok<T> ? Ok<R>(transform(self.value)) : Err<R>((self as Err<T>).failure);
  }
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

class Err<T> extends Result<T> {
  final Failure failure;
  const Err(this.failure);
}
