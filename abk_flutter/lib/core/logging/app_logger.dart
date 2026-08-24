import 'dart:developer' as developer;

import 'redaction.dart';

enum LogLevel { debug, info, warn, error }

/// Structured logger with mandatory redaction. Never prints a raw string that
/// could carry a secret — everything goes through [Redactor].
class AppLogger {
  final Redactor redactor;
  final LogLevel minLevel;
  final void Function(String line)? sink; // overridable for tests

  AppLogger({required this.redactor, this.minLevel = LogLevel.debug, this.sink});

  void debug(String tag, String msg) => _log(LogLevel.debug, tag, msg);
  void info(String tag, String msg) => _log(LogLevel.info, tag, msg);
  void warn(String tag, String msg) => _log(LogLevel.warn, tag, msg);
  void error(String tag, String msg, [Object? err, StackTrace? st]) =>
      _log(LogLevel.error, tag, '$msg${err != null ? ' :: ${redactor.redact(err.toString())}' : ''}');

  void _log(LogLevel level, String tag, String msg) {
    if (level.index < minLevel.index) return;
    final line = '[${level.name.toUpperCase()}] $tag: ${redactor.redact(msg)}';
    if (sink != null) {
      sink!(line);
    } else {
      developer.log(line, name: 'abk');
    }
  }
}
