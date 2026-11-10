import 'package:b2b_contracts/core/security/password_hasher.dart';

/// Fast, synchronous hasher for tests (no isolate, few iterations).
class FastHasher extends PasswordHasher {
  const FastHasher() : super(iterations: 10);

  @override
  Future<String> hash(String secret, String salt) =>
      Future.value(PasswordHasher.pbkdf2(secret, salt, iterations));
}
