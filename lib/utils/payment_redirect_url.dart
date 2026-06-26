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

/// Hosts ExpressPay may redirect to after checkout (merchant return URLs).
const merchantPaymentReturnHosts = <String>[
  'eclcommerce.ernestchemists.com.gh',
  'eclcommerce.test',
  'ernestchemists.com.gh',
];

/// True when [url] navigates away from ExpressPay back to the merchant site.
bool isMerchantPaymentReturnUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme) return false;
  final scheme = uri.scheme.toLowerCase();
  if (!scheme.startsWith('http')) return false;

  final host = uri.host.toLowerCase();
  if (host.contains('expresspay')) return false;

  return merchantPaymentReturnHosts.any(
    (known) => host == known || host.endsWith('.$known'),
  );
}

/// True when [candidate] is the configured ExpressPay return URL (e.g. test root).
bool matchesPaymentRedirectUrl(String candidate, String configuredRedirect) {
  final configured = Uri.tryParse(configuredRedirect.trim());
  final current = Uri.tryParse(candidate.trim());
  if (configured == null || current == null) return false;
  if (configured.host.toLowerCase() != current.host.toLowerCase()) {
    return false;
  }
  if (configured.scheme.toLowerCase() != current.scheme.toLowerCase()) {
    return false;
  }

  final configPath =
      configured.path.isEmpty || configured.path == '/' ? '/' : configured.path;
  final currentPath =
      current.path.isEmpty || current.path == '/' ? '/' : current.path;

  if (configPath == '/') {
    return currentPath == '/';
  }
  return currentPath == configPath || currentPath.startsWith('$configPath/');
}

const _expressPayAmountQueryKeys = <String>[
  'amount',
  'total',
  'total_amount',
  'order_amount',
  'payable',
  'payable_amount',
];

double? _parseUrlAmount(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return double.tryParse(raw.replaceAll(',', '').trim());
}

/// When the portal link embeds a merchandise-only amount, bump query params to
/// [expectedAmount] so ExpressPay checkout matches the app total.
String alignExpressPayCheckoutUrl(String url, double expectedAmount) {
  if (expectedAmount <= 0) return url;

  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme) return url;

  final params = Map<String, String>.from(uri.queryParameters);
  var changed = false;

  for (final key in _expressPayAmountQueryKeys) {
    final current = _parseUrlAmount(params[key]);
    if (current == null) continue;
    if ((current - expectedAmount).abs() < 0.01) continue;
    if (current >= expectedAmount) continue;

    params[key] = expectedAmount.toStringAsFixed(2);
    changed = true;
  }

  if (!changed) return url;
  return uri.replace(queryParameters: params).toString();
}

/// Parses the express-payment API response into a loadable checkout URL.
String? prepareExpressPayPortalUrl(String raw) => parsePaymentRedirectUrl(raw);
