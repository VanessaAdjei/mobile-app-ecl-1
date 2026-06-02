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

/// Percent-encodes each path segment so filenames with spaces, `'`, `(`, `+`, etc.
/// work with [CachedNetworkImage] and the preload cache.
///
/// Uses [Uri.pathSegments] (decoded segments) so mixed `%20` + raw `(` inputs are
/// not double-encoded. Apostrophe is encoded explicitly because [Uri.encodeComponent]
/// leaves `'` unreserved.
String encodeProductImageUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return '';

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    try {
      final uri = Uri.parse(trimmed);
      if (uri.host.isEmpty) return _encodeRelativePath(trimmed);
      if (uri.pathSegments.isEmpty) return trimmed;
      final encodedPath =
          '/${uri.pathSegments.map(_encodePathSegment).join('/')}';
      return uri.replace(path: encodedPath).toString();
    } catch (_) {
      return _minimalPathFix(trimmed);
    }
  }

  return _encodeRelativePath(trimmed);
}

String _encodePathSegment(String segment) {
  if (segment.isEmpty) return segment;
  return Uri.encodeComponent(segment).replaceAll("'", '%27');
}

String _encodeRelativePath(String path) {
  if (path.startsWith('/')) {
    final segments =
        path.split('/').where((s) => s.isNotEmpty).map(_encodePathSegment);
    return '/${segments.join('/')}';
  }
  return _encodePathSegment(path);
}

String _minimalPathFix(String url) {
  return url.replaceAll(' ', '%20').replaceAll("'", '%27');
}
