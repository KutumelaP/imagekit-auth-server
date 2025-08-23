import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureCredentialStore {
  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  static const _keyEmail = 'secure_email';
  static const _keyPassword = 'secure_password';

  static Future<void> saveCredentials({required String email, required String password}) async {
    await _storage.write(key: _keyEmail, value: email);
    await _storage.write(key: _keyPassword, value: password);
  }

  static Future<Map<String, String>?> readCredentials() async {
    final email = await _storage.read(key: _keyEmail);
    final password = await _storage.read(key: _keyPassword);
    if (email == null || password == null) return null;
    return {'email': email, 'password': password};
  }

  static Future<void> clear() async {
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyPassword);
  }
}


