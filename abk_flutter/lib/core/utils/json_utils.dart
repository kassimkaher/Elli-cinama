/// Lenient JSON field coercion — the middleware mixes string/number types.
String? asStringOrNull(Object? v) => v?.toString();

String asString(Object? v, {String fallback = ''}) => v?.toString() ?? fallback;

int? asIntOrNull(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is bool) return v ? 1 : 0;
  if (v is String) return int.tryParse(v.trim());
  return null;
}

int asInt(Object? v, {int fallback = 0}) => asIntOrNull(v) ?? fallback;

bool? asBoolOrNull(Object? v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0' || s.isEmpty) return false;
  }
  return null;
}

Map<String, dynamic> asMap(Object? v) =>
    v is Map ? v.map((k, val) => MapEntry(k.toString(), val)) : <String, dynamic>{};

List<dynamic> asList(Object? v) => v is List ? v : const [];
