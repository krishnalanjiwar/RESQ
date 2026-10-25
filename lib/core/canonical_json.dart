import 'dart:convert';

/// Deterministic JSON: object keys sorted recursively, no whitespace.
/// Signatures are computed over this form so every node hashes identical bytes.
String canonicalJson(Object? value) => jsonEncode(_sorted(value));

List<int> canonicalBytes(Object? value) => utf8.encode(canonicalJson(value));

Object? _sorted(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: _sorted(value[k])};
  }
  if (value is List) return value.map(_sorted).toList();
  return value;
}

/// Maximum nesting depth of a decoded JSON value; guards against hostile payloads.
int jsonDepth(Object? value, [int depth = 0]) {
  if (value is Map) {
    var max = depth + 1;
    for (final v in value.values) {
      final d = jsonDepth(v, depth + 1);
      if (d > max) max = d;
    }
    return max;
  }
  if (value is List) {
    var max = depth + 1;
    for (final v in value) {
      final d = jsonDepth(v, depth + 1);
      if (d > max) max = d;
    }
    return max;
  }
  return depth;
}
