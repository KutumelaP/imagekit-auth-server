import 'package:flutter/material.dart';
import 'screens/payment_webview.dart';

Route<dynamic>? generateAppRoute(RouteSettings settings) {
  if (settings.name == '/paymentWebview') {
    final args = settings.arguments as Map?;
    final url = args?['url'] as String?;
    final successPath = args?['successPath'] as String?;
    final cancelPath = args?['cancelPath'] as String?;
    if (url == null) return null;
    return MaterialPageRoute(
      builder: (_) => PaymentWebViewScreen(
        url: url,
        successPath: successPath,
        cancelPath: cancelPath,
      ),
      settings: settings,
    );
  }
  return null;
}


