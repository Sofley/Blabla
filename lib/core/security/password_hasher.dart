import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// PBKDF2-HMAC-SHA256 hashing for passwords, PIN codes and patterns.
class PasswordHasher {
  const PasswordHasher({this.iterations = 40000});

  final int iterations;

  static String newSalt() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  /// Runs in a background isolate (on mobile) so the UI never freezes.
  Future<String> hash(String secret, String salt) =>
      compute(_entry, (secret, salt, iterations));

  static String _entry((String, String, int) a) => pbkdf2(a.$1, a.$2, a.$3);

  Future<bool> verify(String secret, String salt, String expected) async {
    final actual = await hash(secret, salt);
    return _constantTimeEquals(actual, expected);
  }

  static String pbkdf2(String secret, String salt, int iterations) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    final saltBytes = utf8.encode(salt);
    // Single block (32 bytes) is enough for SHA-256 output length.
    var u = hmac.convert(Uint8List.fromList([...saltBytes, 0, 0, 0, 1])).bytes;
    final out = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return base64Url.encode(out);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
