/// Parses monetary amounts shown on the ExpressPay checkout page.
/// Returns the largest GHS value found (often the payable total when multiple appear).
double? parseExpressPayDisplayedAmount(String pageText) {
  if (pageText.trim().isEmpty) return null;

  final normalized = pageText.replaceAll('\u00a0', ' ');
  final patterns = [
    RegExp(
      r'GHS\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ),
    RegExp(
      r'GHC\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ),
    RegExp(
      r'GH\s*₵\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ),
    RegExp(r'₵\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)'),
    RegExp(
      r'(?:total|amount\s+due|pay(?:able)?(?:\s+amount)?)\s*[:\-]?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ),
  ];

  double? best;
  for (final pattern in patterns) {
    for (final match in pattern.allMatches(normalized)) {
      final raw = match.group(1)?.replaceAll(',', '');
      final value = double.tryParse(raw ?? '');
      if (value == null || value <= 0) continue;
      if (best == null || value > best) best = value;
    }
  }

  return best;
}

bool expressPayAmountMatchesExpected({
  required double expected,
  required double displayed,
  double tolerance = 0.02,
}) {
  return (expected - displayed).abs() <= tolerance;
}

/// True when [displayed] is materially below [expectedTotal] (e.g. delivery omitted).
bool expressPayAmountIsUndercharged({
  required double expectedTotal,
  required double displayed,
  double tolerance = 0.02,
}) {
  return displayed + tolerance < expectedTotal;
}

/// True when [displayed] matches merchandise subtotal but not the full total.
bool expressPayAmountLooksLikeSubtotalOnly({
  required double expectedTotal,
  required double displayed,
  required double merchandiseSubtotal,
}) {
  if (merchandiseSubtotal <= 0 || expectedTotal <= merchandiseSubtotal) {
    return false;
  }
  return expressPayAmountMatchesExpected(
        expected: merchandiseSubtotal,
        displayed: displayed,
      ) &&
      !expressPayAmountMatchesExpected(
        expected: expectedTotal,
        displayed: displayed,
      );
}

double? tryParsePayableAmount(dynamic raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse('${raw ?? ''}'.replaceAll(',', '').trim());
}

/// JS run in the WebView to collect visible copy (body + iframes when allowed).
const extractExpressPayPageTextJs = r'''
(function() {
  const parts = [];
  const grab = (root) => {
    if (!root) return;
    try {
      if (root.body) parts.push(root.body.innerText || '');
      if (root.documentElement) parts.push(root.documentElement.innerText || '');
    } catch (e) {}
  };
  grab(document);
  try {
    document.querySelectorAll('iframe').forEach((frame) => {
      try { grab(frame.contentDocument); } catch (e) {}
    });
  } catch (e) {}
  return parts.join('\n').slice(0, 80000);
})()
''';

const injectExpressPayNavigationHookJs = r'''
(function() {
  if (window.__eclExpressPayNavHook) return;
  window.__eclExpressPayNavHook = true;
  var disposed = false;
  window.__eclDisposeExpressPayNav = function() {
    disposed = true;
    if (window.__eclExpressPayNavInterval != null) {
      clearInterval(window.__eclExpressPayNavInterval);
      window.__eclExpressPayNavInterval = null;
    }
  };
  var post = function() {
    if (disposed) return;
    try { EclPaymentNav.postMessage(location.href); } catch (e) {}
  };
  post();
  window.addEventListener('load', post);
  window.addEventListener('pageshow', post);
  var pushState = history.pushState;
  history.pushState = function() {
    pushState.apply(history, arguments);
    post();
  };
  var replaceState = history.replaceState;
  history.replaceState = function() {
    replaceState.apply(history, arguments);
    post();
  };
  window.addEventListener('popstate', post);
})();
''';

/// Stops JS navigation hooks before the native WebView is torn down (iOS).
const disposeExpressPayNavigationHookJs = r'''
(function() {
  if (typeof window.__eclDisposeExpressPayNav === 'function') {
    window.__eclDisposeExpressPayNav();
  }
})();
''';

String normalizeWebViewJsString(Object? raw) {
  final rawText = raw?.toString() ?? '';
  if (rawText.startsWith('"') && rawText.endsWith('"')) {
    return rawText
        .substring(1, rawText.length - 1)
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\"', '"')
        .replaceAll(r'\\', '\\');
  }
  return rawText.replaceAll('"', '').trim();
}

bool expressPayUrlIsCheckoutEntry(String url) {
  final lower = url.toLowerCase();
  return lower.contains('checkout.php') &&
      !lower.contains('success') &&
      !lower.contains('pending');
}

enum ExpressPayPageSignal { none, pending, success, failed }

/// Reads ExpressPay in-page copy after the user submits payment.
ExpressPayPageSignal expressPayPageSignal(String pageText, {String? pageUrl}) {
  final text = pageText.toLowerCase();
  if (text.trim().isEmpty) return ExpressPayPageSignal.none;

  final url = pageUrl?.toLowerCase() ?? '';
  final onCheckoutEntry =
      url.contains('checkout.php') && !url.contains('success');

  if (expressPayPageLooksFailed(text)) {
    return ExpressPayPageSignal.failed;
  }
  if (!onCheckoutEntry && expressPayPageLooksSuccessful(text)) {
    return ExpressPayPageSignal.success;
  }
  if (expressPayPageLooksPending(text)) {
    return ExpressPayPageSignal.pending;
  }
  return ExpressPayPageSignal.none;
}

bool expressPayPageLooksFailed(String text) {
  const phrases = <String>[
    'payment failed',
    'transaction failed',
    'payment was declined',
    'payment declined',
    'transaction declined',
    'could not process',
    'unable to process',
    'unsuccessful',
    'payment unsuccessful',
  ];
  return phrases.any(text.contains);
}

bool expressPayPageLooksSuccessful(String text) {
  const phrases = <String>[
    'payment successful',
    'transaction successful',
    'payment complete',
    'payment completed',
    'successfully paid',
    'your payment was successful',
    'thank you for your payment',
    'payment received',
    'transaction complete',
  ];
  return phrases.any(text.contains);
}

/// True when ExpressPay page copy indicates the payment is awaiting confirmation.
bool expressPayPageLooksPending(String pageText) {
  final text = pageText.toLowerCase();
  if (text.trim().isEmpty) return false;

  const phrases = <String>[
    'payment pending',
    'transaction pending',
    'payment is pending',
    'payment is being processed',
    'transaction is being processed',
    'awaiting approval',
    'awaiting confirmation',
    'authorization pending',
    'pending approval',
    'waiting for payment confirmation',
    'your payment is pending',
    'check your phone',
    'confirm the payment on your phone',
    'dial *170#',
  ];

  return phrases.any(text.contains);
}
