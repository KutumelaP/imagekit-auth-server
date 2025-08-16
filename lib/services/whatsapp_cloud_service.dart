import 'dart:convert';
import 'package:http/http.dart' as http;

class WhatsAppCloudService {
  WhatsAppCloudService._();
  static final WhatsAppCloudService instance = WhatsAppCloudService._();

  final String _accessToken = const String.fromEnvironment('WA_ACCESS_TOKEN', defaultValue: '');
  final String _phoneNumberId = const String.fromEnvironment('WA_PHONE_NUMBER_ID', defaultValue: '');
  final String _apiVersion = const String.fromEnvironment('WA_API_VERSION', defaultValue: 'v20.0');

  bool get isConfigured => _accessToken.isNotEmpty && _phoneNumberId.isNotEmpty;

  Future<bool> sendTemplate({
    required String toE164,
    required String templateName,
    String language = 'en',
    List<String> parameters = const [],
  }) async {
    if (!isConfigured) {
      // Sandbox/no-op
      return true;
    }
    final url = Uri.parse('https://graph.facebook.com/$_apiVersion/$_phoneNumberId/messages');
    final body = {
      'messaging_product': 'whatsapp',
      'to': toE164,
      'type': 'template',
      'template': {
        'name': templateName,
        'language': {'code': language},
        if (parameters.isNotEmpty)
          'components': [
            {
              'type': 'body',
              'parameters': parameters.map((p) => {'type': 'text', 'text': p}).toList(),
            }
          ]
      }
    };
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_accessToken',
      },
      body: jsonEncode(body),
    );
    return res.statusCode >= 200 && res.statusCode < 300;
  }
}


