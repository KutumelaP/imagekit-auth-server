import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String url; // Full URL with query string
  final String? successPath; // e.g., '/api/payfastReturn'
  final String? cancelPath; // e.g., '/api/payfastCancel'

  const PaymentWebViewScreen({super.key, required this.url, this.successPath, this.cancelPath});

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final url = request.url;
          debugPrint('🌐 WebView navigating → $url');
          if (widget.successPath != null && url.contains(widget.successPath!)) {
            Navigator.of(context).pop({'status': 'success', 'url': url});
            return NavigationDecision.prevent;
          }
          if (widget.cancelPath != null && url.contains(widget.cancelPath!)) {
            Navigator.of(context).pop({'status': 'cancel', 'url': url});
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Payment'),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}


