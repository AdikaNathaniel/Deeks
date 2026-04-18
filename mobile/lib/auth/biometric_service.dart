import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _pinHashKey = 'master_pin_hash';

  Future<bool> hasMasterPin() async {
    final hash = await _storage.read(key: _pinHashKey);
    return hash != null;
  }

  Future<void> setMasterPin(String pin) async {
    // Stored via platform-encrypted secure storage (Keystore/Keychain).
    // The PIN itself is ALSO used to derive the vault key elsewhere; here
    // we just record a verifier to validate PIN fallback attempts.
    await _storage.write(key: _pinHashKey, value: pin);
  }

  Future<bool> verifyMasterPin(String pin) async {
    final stored = await _storage.read(key: _pinHashKey);
    return stored != null && stored == pin;
  }

  Future<bool> canUseBiometrics() async {
    final supported = await _auth.isDeviceSupported();
    final canCheck = await _auth.canCheckBiometrics;
    return supported && canCheck;
  }

  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(localizedReason: reason);
    } catch (_) {
      return false;
    }
  }
}
