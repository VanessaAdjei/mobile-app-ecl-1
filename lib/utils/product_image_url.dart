import 'dart:convert';

/// Normalizes API `product_img` / `image` values into a plain path or absolute URL.
///
/// Backend sometimes returns a nested map or a JSON string; using that directly in
/// [Image.network] causes `FormatException` (URI scheme cannot start with `{`).
String coerceProductImageSource(dynamic value) {
  if (value == null) return '';
  if (value is String) {
    final s = value.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('{') || s.startsWith('[')) {
      try {
        final decoded = jsonDecode(s);
        return coerceProductImageSource(decoded);
      } catch (_) {
        return '';
      }
    }
    return s;
  }
  if (value is Map) {
    final m = Map<String, dynamic>.from(value);
    for (final key in <String>[
      'url',
      'path',
      'src',
      'image',
      'product_img',
      'file',
      'thumbnail',
      'photo',
    ]) {
      final inner = m[key];
      if (inner == null) continue;
      final out = coerceProductImageSource(inner);
      if (out.isNotEmpty) return out;
    }
    return '';
  }
  if (value is List && value.isNotEmpty) {
    return coerceProductImageSource(value.first);
  }
  final asString = value.toString().trim();
  if (asString.startsWith('{')) return '';
  return asString;
}
