import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart' as pc;

// Per-user salt + PIN-derived AES-256 key, AES-GCM encryption.
// The key lives in memory only after unlock; the salt lives in Keystore/Keychain.
class VaultCrypto {
  static const _saltKey = 'vault_salt_b64';
  static const _algorithm = 'AES-256-GCM';
  static const _pbkdf2Iterations = 100000;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  enc.Key? _key;

  bool get isUnlocked => _key != null;

  Future<Uint8List> _ensureSalt() async {
    final existing = await _storage.read(key: _saltKey);
    if (existing != null) return base64Decode(existing);
    final rnd = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => rnd.nextInt(256)),
    );
    await _storage.write(key: _saltKey, value: base64Encode(salt));
    return salt;
  }

  Future<void> unlockWithPin(String pin) async {
    final salt = await _ensureSalt();
    final params = pc.Pbkdf2Parameters(salt, _pbkdf2Iterations, 32);
    final derivator = pc.PBKDF2KeyDerivator(
      pc.HMac(pc.SHA256Digest(), 64),
    )..init(params);
    final derived = derivator.process(
      Uint8List.fromList(utf8.encode(pin)),
    );
    _key = enc.Key(derived);
  }

  void lock() {
    _key = null;
  }

  // Returns {ciphertext, iv, algorithm} — all base64-ready strings.
  ({String ciphertext, String iv, String algorithm}) encrypt(String plaintext) {
    if (_key == null) {
      throw StateError('Vault locked — unlockWithPin() first');
    }
    final iv = enc.IV.fromSecureRandom(12);
    final encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return (
      ciphertext: encrypted.base64,
      iv: iv.base64,
      algorithm: _algorithm,
    );
  }

  String decrypt({required String ciphertext, required String iv}) {
    if (_key == null) {
      throw StateError('Vault locked — unlockWithPin() first');
    }
    final encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.gcm));
    return encrypter.decrypt(
      enc.Encrypted.fromBase64(ciphertext),
      iv: enc.IV.fromBase64(iv),
    );
  }
}
