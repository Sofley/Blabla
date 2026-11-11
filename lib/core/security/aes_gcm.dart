import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// AES-256-GCM helpers. Sealed format: nonce (12 B) | ciphertext | MAC (16 B).
/// Pure-Dart implementation so it behaves the same on every platform and in
/// tests.
class AesGcmBox {
  AesGcmBox._();

  static final _algo = AesGcm.with256bits();

  static Uint8List randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }

  static Future<Uint8List> seal(
    List<int> plain,
    List<int> key, {
    List<int> aad = const [],
  }) async {
    final box = await _algo.encrypt(
      plain,
      secretKey: SecretKey(key),
      nonce: randomBytes(12),
      aad: aad,
    );
    return box.concatenation();
  }

  /// Throws [SecretBoxAuthenticationError] when the key is wrong or the
  /// data was changed.
  static Future<Uint8List> open(
    List<int> sealed,
    List<int> key, {
    List<int> aad = const [],
  }) async {
    final box = SecretBox.fromConcatenation(
      sealed,
      nonceLength: 12,
      macLength: 16,
      copy: false,
    );
    final plain = await _algo.decrypt(box, secretKey: SecretKey(key), aad: aad);
    return Uint8List.fromList(plain);
  }
}
