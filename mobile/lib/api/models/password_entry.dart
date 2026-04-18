// Raw server-side shape (ciphertext + iv, base64). The client decrypts to reveal
// the plaintext secret in memory only.
class PasswordEntry {
  final String id;
  final String platform;
  final String label;
  final String ciphertext;
  final String iv;
  final String? algorithm;

  PasswordEntry({
    required this.id,
    required this.platform,
    required this.label,
    required this.ciphertext,
    required this.iv,
    this.algorithm,
  });

  factory PasswordEntry.fromJson(Map<String, dynamic> j) => PasswordEntry(
        id: j['_id'] as String,
        platform: j['platform'] as String,
        label: j['label'] as String,
        ciphertext: j['ciphertext'] as String,
        iv: j['iv'] as String,
        algorithm: j['algorithm'] as String?,
      );

  Map<String, dynamic> toCreateJson() => {
        'platform': platform,
        'label': label,
        'ciphertext': ciphertext,
        'iv': iv,
        if (algorithm != null) 'algorithm': algorithm,
      };
}
