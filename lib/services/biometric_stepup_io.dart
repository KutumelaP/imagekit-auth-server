import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BiometricStepUp {
  static Future<bool> authenticate({String reason = 'Confirm your identity'}) async {
    if (kIsWeb) return false;
    try {
      final auth = LocalAuthentication();
      final supported = await auth.isDeviceSupported();
      if (!supported) return false;
      try {
        final ok = await auth.authenticate(
          localizedReason: reason,
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
            useErrorDialogs: true,
          ),
        );
        if (ok) return true;
      } on PlatformException {
        // fallthrough to device credential
      }
      // Fallback to device credentials if biometrics unavailable
      try {
        final fallbackOk = await auth.authenticate(
          localizedReason: reason,
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
            useErrorDialogs: true,
          ),
        );
        return fallbackOk;
      } catch (_) {
        return false;
      }
    } catch (_) {
      return false;
    }
  }
}


