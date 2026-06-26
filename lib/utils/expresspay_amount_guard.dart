// ExpressPay WebView helpers (page scan, navigation hooks, outcome detection).

const extractExpressPayPageTextJs = r'''
(function() {
  const parts = [];
  const grab = (root) => {
    if (!root) return;
    try {
      if (root.body) parts.push(root.body.innerText || '');
      if (root.documentElement) parts.push(root.documentElement.innerText || '');
      root.querySelectorAll('input, [data-amount], [data-total], .amount, .total, [class*="amount"], [class*="total"]').forEach((el) => {
        parts.push(el.value || el.getAttribute('data-amount') || el.getAttribute('data-total') || el.textContent || '');
      });
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
