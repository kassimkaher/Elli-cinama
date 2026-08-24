/// Central secret redactor. Every log line and every diagnostic string that
/// might contain credentials is passed through this. Secrets are registered
/// once (after login / on credential load) and scrubbed from all output,
/// including their URL-encoded forms and credential-bearing URL segments.
class Redactor {
  final Set<String> _secrets = <String>{};

  void registerSecret(String? value) {
    if (value != null && value.isNotEmpty) {
      _secrets.add(value);
    }
  }

  void clear() => _secrets.clear();

  String redact(String input) {
    var out = input;
    for (final s in _secrets) {
      if (s.isEmpty) continue;
      out = out.replaceAll(s, '***');
      final enc = Uri.encodeComponent(s);
      if (enc != s) out = out.replaceAll(enc, '***');
    }
    return out;
  }

  /// Redacts registered secrets plus common credential-bearing URL shapes:
  /// query params (username/password/user/pass) and Xtream-style
  /// `/{user}/{pass}/{id}` path segments.
  String redactUrl(String url) {
    var out = redact(url);
    out = out.replaceAllMapped(
      RegExp(r'((?:username|password|user|pass)=)[^&#]*', caseSensitive: false),
      (m) => '${m[1]}***',
    );
    return out;
  }
}
