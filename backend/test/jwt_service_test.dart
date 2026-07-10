import 'package:backend/services/jwt_service.dart';
import 'package:test/test.dart';

void main() {
  final jwt = JwtService('segredo-de-teste-bem-longo-1234567890');

  group('JwtService', () {
    test('round-trip: gera e valida com os mesmos claims', () {
      final token = jwt.generateToken(idUsuario: 42, tipoUsuario: 'cliente');
      final payload = jwt.verifyToken(token);
      expect(payload, isNotNull);
      expect(payload!['sub'], 42);
      expect(payload['tipo'], 'cliente');
    });

    test('inclui id_empresa quando != 0 e omite quando 0', () {
      final comEmpresa = jwt.verifyToken(
        jwt.generateToken(idUsuario: 1, tipoUsuario: 'empresa', idEmpresa: 7),
      );
      expect(comEmpresa!['id_empresa'], 7);

      final semEmpresa = jwt.verifyToken(
        jwt.generateToken(idUsuario: 1, tipoUsuario: 'empresa', idEmpresa: 0),
      );
      expect(semEmpresa!.containsKey('id_empresa'), isFalse);
    });

    test('rejeita token assinado com outro segredo', () {
      final outro = JwtService('outro-segredo-completamente-diferente-000');
      final token = outro.generateToken(idUsuario: 1, tipoUsuario: 'cliente');
      expect(jwt.verifyToken(token), isNull);
    });

    test('rejeita token com assinatura adulterada', () {
      final token = jwt.generateToken(idUsuario: 1, tipoUsuario: 'cliente');
      final parts = token.split('.');
      expect(jwt.verifyToken('${parts[0]}.${parts[1]}.assinaturaerrada'), isNull);
    });

    test('rejeita token malformado', () {
      expect(jwt.verifyToken('semponto'), isNull);
      expect(jwt.verifyToken(''), isNull);
    });

    test('verifyExpiredToken aceita assinatura valida e rejeita adulterada', () {
      final token = jwt.generateToken(idUsuario: 5, tipoUsuario: 'motoboy');
      expect(jwt.verifyExpiredToken(token), isNotNull);
      final parts = token.split('.');
      expect(jwt.verifyExpiredToken('${parts[0]}.${parts[1]}.x'), isNull);
    });
  });
}
