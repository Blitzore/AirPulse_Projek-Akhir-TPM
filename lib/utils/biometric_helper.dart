import 'package:local_auth/local_auth.dart';

/// Wrapper untuk autentikasi biometrik (sidik jari/wajah).
class BiometricHelper {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> hasBiometrics() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Scan sidik jari Anda untuk login ke AirPulse',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
