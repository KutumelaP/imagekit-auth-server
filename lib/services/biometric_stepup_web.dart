class BiometricStepUp {
  static Future<bool> authenticate({String reason = 'Confirm your identity'}) async {
    // Not supported on web via local_auth; handled via WebAuthn in future
    return false;
  }
}


