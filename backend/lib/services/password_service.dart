import 'dart:convert';
import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';

/// Gerencia hash e verificação de senhas.
///
/// Formato atual: **bcrypt** (o hash começa com `$2a$`/`$2b$`).
/// Compatível com formatos legados para migração transparente:
///   - `v1:<salt_base64>:<sha256_hex>` (SHA-256 salgado)
///   - texto plano
///
/// Senhas em formato legado são re-hasheadas em bcrypt no próximo login
/// (via [needsUpgrade], usado pelo AuthController).
class PasswordService {
  static const _legacyVersion = 'v1';

  /// Gera o hash bcrypt da senha para armazenar no banco.
  static String hash(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  /// Verifica se a senha bate com o valor armazenado, em qualquer formato.
  static bool verify(String password, String stored) {
    // bcrypt (formato atual)
    if (stored.startsWith(r'$2')) {
      try {
        return BCrypt.checkpw(password, stored);
      } catch (_) {
        return false;
      }
    }
    // Legado: SHA-256 salgado (v1:salt:hash)
    if (stored.startsWith('$_legacyVersion:')) {
      final parts = stored.split(':');
      if (parts.length != 3) return false;
      final salt = parts[1];
      final expectedHash = parts[2];
      return _sha256(password + salt) == expectedHash;
    }
    // Legado: texto plano
    return password == stored;
  }

  /// Retorna true se a senha não está em bcrypt (precisa de upgrade).
  static bool needsUpgrade(String stored) => !stored.startsWith(r'$2');

  static String _sha256(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}
