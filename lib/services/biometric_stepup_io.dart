import 'package:local_auth/local_auth.dart';

class BiometricStepUp {
  static Future<bool> authenticate({String reason = 'Confirm your identity'}) async {
    try {
      final auth = LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics;
      final supported = await auth.isDeviceSupported();
      if (!canCheck || !supported) return false;
      final ok = await auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      return ok;
    } catch (_) {
      return false;
    }
  }
}


