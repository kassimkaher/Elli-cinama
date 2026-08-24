import 'dart:convert';

/// A short-EPG listing. `title` is Base64-encoded on the wire.
class EpgListing {
  final String? titleRaw;
  final String? start;
  final String? end;
  final String? startTimestamp;
  final String? stopTimestamp;

  const EpgListing({
    this.titleRaw,
    this.start,
    this.end,
    this.startTimestamp,
    this.stopTimestamp,
  });

  /// Decoded title (Base64 -> UTF-8); falls back to the raw value if it is not
  /// valid Base64.
  String? get title {
    final t = titleRaw;
    if (t == null || t.isEmpty) return t;
    try {
      final padded = t.padRight((t.length + 3) & ~3, '=');
      return utf8.decode(base64.decode(padded), allowMalformed: true);
    } catch (_) {
      return t;
    }
  }
}
