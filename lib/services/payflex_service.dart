import 'dart:convert';
import 'package:http/http.dart' as http;

class PayflexService {
  PayflexService._();
  static final PayflexService instance = PayflexService._();

  final String _base = const String.fromEnvironment('PAYFLEX_BASE', defaultValue: 'https://sandbox.payflex.co.za');
  final String _key = const String.fromEnvironment('PAYFLEX_KEY', defaultValue: '');
  final String _secret = const String.fromEnvironment('PAYFLEX_SECRET', defaultValue: '');

  bool get isConfigured => _key.isNotEmpty && _secret.isNotEmpty;

  Future<Uri?> createCheckout({required String orderId, required double amount, required String returnUrl, required String cancelUrl}) async {
    if (!isConfigured) {
      // Sandbox: fake URL
      return Uri.parse('$_base/checkout/fake?orderId=$orderId&amount=$amount');
    }
    final url = Uri.parse('$_base/api/checkout');
    final body = {
      'merchantReference': orderId,
      'amount': (amount * 100).round(),
      'currency': 'ZAR',
      'returnUrl': returnUrl,
      'cancelUrl': cancelUrl,
    };
    final res = await http.post(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Basic ${base64Encode(utf8.encode('$_key:$_secret'))}',
    }, body: jsonEncode(body));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final redirect = json['redirectUrl'] as String?;
      if (redirect != null) return Uri.parse(redirect);
    }
    return null;
  }
}


