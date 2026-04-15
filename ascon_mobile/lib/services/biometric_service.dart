import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> get isBiometricAvailable async {
    if (kIsWeb) return false;
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      
      if (!canCheck && !isSupported) return false;

      final List<BiometricType> availableBiometrics =
          await _auth.getAvailableBiometrics();
      
      return availableBiometrics.isNotEmpty;
    } on PlatformException catch (e) {
      debugPrint("Biometric Check Error: $e");
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Scan your fingerprint or face to log in',
        // ✅ CORRECT PARAMETER USAGE FOR local_auth v2+
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint("Authentication Error: $e");
      return false;
    }
  }
}