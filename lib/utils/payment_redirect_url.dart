import 'dart:convert';

/// Normalizes the express-pay (and similar) HTTP body into a single loadable HTTPS URL.
///
/// The server may return a bare URL, a JSON string, or JSON with nested `data`.
/// A bad value breaks [Uri.parse] / [WebViewController.loadRequest] and can leave the
/// WebView transparent so the green payment header shows through as a "green screen".
String? parsePaymentRedirectUrl(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('\uFEFF')) {
    s = s.substring(1).trim();
  }
  if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
    s = s.substring(1, s.length - 1).trim();
  }
  if (s.startsWith('<')) {
    return null;
  }
  final direct = _asHttpUrl(s);
  if (direct != null) return direct;

  if (s.startsWith('{') || s.startsWith('[')) {
    try {
      final decoded = jsonDecode(s);
      return _extractUrlFromJson(decoded);
    } catch (_) {
      return null;
    }
  }
  return null;
}

String? _asHttpUrl(String s) {
  final lower = s.toLowerCase();
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
    return null;
  }
  final uri = Uri.tryParse(s);
  if (uri == null || !uri.hasScheme) return null;
  if (uri.host.isEmpty) return null;
  return s;
}

String? _extractUrlFromJson(Object? value) {
  if (value == null) return null;
  if (value is String) {
    return parsePaymentRedirectUrl(value);
  }
  if (value is List && value.isNotEmpty) {
    for (final e in value) {
      final u = _extractUrlFromJson(e);
      if (u != null) return u;
    }
    return null;
  }
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    const keys = <String>[
      'url',
      'redirect_url',
      'redirectUrl',
      'checkout_url',
      'payment_url',
      'link',
      'href',
    ];
    for (final key in keys) {
      final u = _extractUrlFromJson(map[key]);
      if (u != null) return u;
    }
    return _extractUrlFromJson(map['data']);
  }
  return null;
}
