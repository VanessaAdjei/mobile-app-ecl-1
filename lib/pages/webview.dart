// pages/webview.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'app_back_button.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';

class WebViewPage extends StatefulWidget {
  final String url;
  final String title;
  final Function(String)? onError;

  const WebViewPage({
    super.key,
    required this.url,
    required this.title,
    this.onError,
  });

  @override
  WebViewPageState createState() => WebViewPageState();
}

class WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _webViewError;

  void _reloadWebView() {
    setState(() {
      _webViewError = null;
      _isLoading = true;
    });
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _webViewError = null;
            });
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _webViewError = 'WebView Error: ${error.description}';
              _isLoading = false;
            });
            widget.onError?.call('WebView Error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          EclExpandableSliverAppBar(
            toolbarTitle: widget.title,
            heroTitle: widget.title,
            heroSubtitle: 'Secure in-app browser',
            leading: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: BackButtonUtils.simple(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: true,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.white),
                if (_webViewError != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: Colors.red, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            _webViewError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red, fontSize: 16),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _reloadWebView,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              textStyle: const TextStyle(fontSize: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  WebViewWidget(controller: _controller),
                if (_isLoading && _webViewError == null)
                  const ColoredBox(
                    color: Colors.white,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
