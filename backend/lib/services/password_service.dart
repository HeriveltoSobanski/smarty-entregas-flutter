import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Gerencia hash e verificação de senhas.
///
/// Formato armazenado: `v1:<salt_base64>:<hash_hex>`
/// Compatível com senhas legadas (texto plano) para migração transparente.
class PasswordService {
  static const _version = 'v1';

  /// Gera o hash da senha para armazenar no banco.
  static String hash(String password) {
    final salt = _generateSalt();
    final hashed = _sha256(password + salt);
    return '$_version:$salt:$hashed';
  }

  /// Verifica se a senha bate com o valor armazenado.
  /// Suporta senhas legadas (texto plano) para migração automática.
  static bool verify(String password, String stored) {
    if (stored.startsWith('$_version:')) {
      final parts = stored.split(':');
      if (parts.length != 3) return false;
      final salt = parts[1];
      final expectedHash = parts[2];
      return _sha256(password + salt) == expectedHash;
    }
    // Senha legada (texto plano) — compara direto
    return password == stored;
  }

  /// Retorna true se a senha está em texto plano (precisa de upgrade).
  static bool needsUpgrade(String stored) => !stored.startsWith('$_version:');

  static String _generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static String _sha256(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}
