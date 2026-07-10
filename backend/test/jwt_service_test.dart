import 'dart:convert';
import 'package:backend/services/jwt_service.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

const _secret = 'segredo-de-teste-bem-longo-1234567890';

/// Fabrica um token assinado com [_secret] e um `exp` arbitrário (em epoch
/// segundos), para exercitar cenários de expiração que o generateToken
/// (sempre +7 dias) não permite criar.
String _fabricarToken({required int exp, int sub = 1, String tipo = 'cliente', int tv = 0}) {
  String enc(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final header = enc({'alg': 'HS256', 'typ': 'JWT'});
  final payload = enc({'sub': sub, 'tipo': tipo, 'tv': tv, 'iat': exp - 100, 'exp': exp});
  final sig = base64Url
      .encode(Hmac(sha256, utf8.encode(_secret)).convert(utf8.encode('$header.$payload')).bytes)
      .replaceAll('=', '');
  return '$header.$payload.$sig';
}

int _epochDiasAtras(int dias) =>
    DateTime.now().subtract(Duration(days: dias)).millisecondsSinceEpoch ~/ 1000;

void main() {
  final jwt = JwtService(_secret);

  group('JwtService', () {
    test('round-trip: gera e valida com os mesmos claims', () {
      final token = jwt.generateToken(idUsuario: 42, tipoUsuario: 'cliente');
      final payload = jwt.verifyToken(token);
      expect(payload, isNotNull);
      expect(payload!['sub'], 42);
      expect(payload['tipo'], 'cliente');
    });

    test('inclui o claim tv (token_version); default 0', () {
      final comTv = jwt.verifyToken(
        jwt.generateToken(idUsuario: 1, tipoUsuario: 'cliente', tokenVersion: 3),
      );
      expect(comTv!['tv'], 3);

      final semTv = jwt.verifyToken(
        jwt.generateToken(idUsuario: 1, tipoUsuario: 'cliente'),
      );
      expect(semTv!['tv'], 0);
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

    test('token expirado ha 5 dias: verifyToken recusa, verifyExpiredToken renova', () {
      final token = _fabricarToken(exp: _epochDiasAtras(5), sub: 9, tipo: 'cliente');
      // O gate normal recusa (expirado)...
      expect(jwt.verifyToken(token), isNull);
      // ...mas o refresh aceita, pois esta dentro da janela de 30 dias.
      final payload = jwt.verifyExpiredToken(token);
      expect(payload, isNotNull);
      expect(payload!['sub'], 9);
    });

    test('token expirado ha 40 dias: verifyExpiredToken recusa (fora da janela)', () {
      final token = _fabricarToken(exp: _epochDiasAtras(40));
      expect(jwt.verifyExpiredToken(token), isNull);
    });
  });
}
