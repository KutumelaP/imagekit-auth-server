import 'dart:convert';
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

// Minimal WebAuthn bridge for Flutter web using navigator.credentials.get/create via functions backend
class BiometricStepUp {
  static Future<bool> authenticate({String reason = 'Confirm your identity'}) async {
    if (!kIsWeb) return false;
    try {
      // 1) Get auth options (challenge, allowCredentials)
      final callable = FirebaseFunctions.instance.httpsCallable('webauthnAuthenticationOptions');
      final optionsResp = await callable();
      final options = Map<String, dynamic>.from(optionsResp.data as Map);

      // 2) navigator.credentials.get with PublicKeyCredentialRequestOptions
      final publicKey = _decodePublicKeyRequestOptions(options);
      final creds = await js_util.promiseToFuture(js_util.callMethod(js_util.getProperty(js_util.getProperty(js_util.globalThis, 'navigator'), 'credentials'), 'get', [
        js_util.jsify({'publicKey': publicKey}),
      ]));

      final assertion = _extractAssertion(creds);

      // 3) Verify on server
      final verify = FirebaseFunctions.instance.httpsCallable('webauthnVerifyAuthentication');
      final vresp = await verify(assertion);
      return vresp.data == null ? false : true;
    } catch (e) {
      if (kDebugMode) {
        print('WebAuthn authenticate error: $e');
      }
      return false;
    }
  }

  // Helpers to convert JSON from server into proper ArrayBuffers for WebAuthn
  static Object _bufferFromB64u(String s) {
    // atob polyfill via JS; simplest is to pass base64url to Uint8Array.from
    final bin = base64Url.decode(s);
    return js_util.callConstructor(js_util.getProperty(js_util.globalThis, 'Uint8Array'), [js_util.jsify(bin)]) as Object;
  }

  static Object _decodePublicKeyRequestOptions(Map<String, dynamic> o) {
    final Map<String, Object> pk = {};
    pk['challenge'] = _bufferFromB64u(o['challenge']);
    if (o['rpId'] != null) pk['rpId'] = o['rpId'];
    if (o['timeout'] != null) pk['timeout'] = o['timeout'];
    if (o['userVerification'] != null) pk['userVerification'] = o['userVerification'];
    if (o['allowCredentials'] is List) {
      pk['allowCredentials'] = (o['allowCredentials'] as List).map((c) => {
            'type': 'public-key',
            'id': _bufferFromB64u(c['id']),
            if (c['transports'] != null) 'transports': c['transports'],
          }).toList();
    }
    return js_util.jsify(pk);
  }

  static Map<String, dynamic> _extractAssertion(Object credential) {
    final id = js_util.getProperty(credential, 'id');
    final rawId = js_util.getProperty(credential, 'rawId');
    final response = js_util.getProperty(credential, 'response');
    final clientDataJSON = js_util.getProperty(response, 'clientDataJSON');
    final authenticatorData = js_util.getProperty(response, 'authenticatorData');
    final signature = js_util.getProperty(response, 'signature');
    final userHandle = js_util.getProperty(response, 'userHandle');

    String b64u(Object buf) {
      final uint8 = js_util.callMethod(js_util.getProperty(js_util.globalThis, 'Uint8Array'), 'from', [buf]);
      final dartList = List<int>.from(js_util.getProperty(uint8, 'slice').apply([0]) ?? []);
      return base64UrlEncode(dartList).replaceAll('=', '');
    }

    return {
      'id': id,
      'rawId': b64u(rawId),
      'response': {
        'clientDataJSON': b64u(clientDataJSON),
        'authenticatorData': b64u(authenticatorData),
        'signature': b64u(signature),
        'userHandle': userHandle != null ? b64u(userHandle) : null,
      },
      'type': 'public-key',
      'clientExtensionResults': {},
      'authenticatorAttachment': js_util.getProperty(credential, 'authenticatorAttachment') ?? null,
    };
  }
}



