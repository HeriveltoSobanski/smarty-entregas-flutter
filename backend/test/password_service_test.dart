import 'dart:convert';
import 'package:backend/services/password_service.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

void main() {
  group('PasswordService', () {
    test('bcrypt: hash gera formato \$2 e verifica corretamente', () {
      final hash = PasswordService.hash('senhaForte123');
      expect(hash.startsWith(r'$2'), isTrue);
      expect(PasswordService.verify('senhaForte123', hash), isTrue);
      expect(PasswordService.verify('senhaErrada', hash), isFalse);
    });

    test('needsUpgrade: false para bcrypt, true para legado', () {
      expect(PasswordService.needsUpgrade(PasswordService.hash('x')), isFalse);
      expect(PasswordService.needsUpgrade('texto-plano'), isTrue);
      expect(PasswordService.needsUpgrade('v1:salt:abc'), isTrue);
    });

    test('legado v1 (sha256 salgado) verifica corretamente', () {
      const senha = 'minhaSenha';
      const salt = 'saltAleatorio';
      final digest = sha256.convert(utf8.encode(senha + salt)).toString();
      final stored = 'v1:$salt:$digest';
      expect(PasswordService.verify(senha, stored), isTrue);
      expect(PasswordService.verify('outra', stored), isFalse);
    });

    test('legado texto plano verifica corretamente', () {
      expect(PasswordService.verify('123456', '123456'), isTrue);
      expect(PasswordService.verify('123456', 'outrasenha'), isFalse);
    });
  });
}
