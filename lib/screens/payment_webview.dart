import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String? url; // Full URL with query string
  final String? successPath; // e.g., '/api/payfastReturn'
  final String? cancelPath; // e.g., '/api/payfastCancel'

  const PaymentWebViewScreen({super.key, this.url, this.successPath, this.cancelPath});

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

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
            debugPrint('✅ Payment success detected: $url');
            Navigator.of(context).pop({'status': 'success', 'url': url});
            return NavigationDecision.prevent;
          }
          if (widget.cancelPath != null && url.contains(widget.cancelPath!)) {
            debugPrint('❌ Payment cancelled: $url');
            Navigator.of(context).pop({'status': 'cancel', 'url': url});
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onPageFinished: (url) {
          debugPrint('📄 WebView page finished loading: $url');
          if (mounted) setState(() => _isLoading = false);
        },
        onWebResourceError: (error) {
          debugPrint('❌ WebView error: ${error.description}');
          if (mounted) setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = error.description;
          });
        },
      ));
    
    // Load URL if provided, otherwise show error
    if (widget.url != null && widget.url!.isNotEmpty) {
      print('🌐 PaymentWebView: Loading URL: ${widget.url}');
      try {
        _controller.loadRequest(Uri.parse(widget.url!));
      } catch (e) {
        print('❌ PaymentWebView: Error loading URL: $e');
        if (mounted) setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    } else {
      print('⚠️ PaymentWebView: No URL provided');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: widget.url == null || widget.url!.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Payment URL not provided',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please complete your payment through the checkout process.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'This page is only accessible during the payment process.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            )
          : Stack(
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


