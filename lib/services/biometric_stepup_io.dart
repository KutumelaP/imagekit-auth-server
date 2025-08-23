import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BiometricStepUp {
  static Future<bool> authenticate({String reason = 'Confirm your identity'}) async {
    try {
      final auth = LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics;
      final supported = await auth.isDeviceSupported();
      final biometrics = await auth.getAvailableBiometrics();
      if (kDebugMode) {
        // Debug logs to help diagnose device capability
        print('🔐 Biometrics supported: $supported, canCheck: $canCheck, types: $biometrics');
      }
      if (!canCheck || !supported || biometrics.isEmpty) {
        if (kDebugMode) {
          print('🔐 No enrolled biometrics or device not supported');
        }
        return false;
      }
      try {
        final ok = await auth.authenticate(
          localizedReason: reason,
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
            useErrorDialogs: true,
          ),
        );
        return ok;
      } on PlatformException catch (pe) {
        if (kDebugMode) {
          print('🔐 Biometric-only auth PlatformException: code=${pe.code}, message=${pe.message}');
        }
        // Retry once allowing device credentials as fallback (PIN/Pattern/Password)
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
        } catch (fallbackError) {
          if (kDebugMode) {
            print('🔐 Biometric fallback (device credential) failed: $fallbackError');
          }
          return false;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔐 Biometric auth error: $e');
      }
      return false;
    }
  }
}


