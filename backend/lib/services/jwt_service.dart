import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Serviço JWT simples baseado em HMAC-SHA256.
/// Token válido por 7 dias.
class JwtService {
  final String _secret;
  static const _expDays = 7;

  JwtService(this._secret);

  /// Gera um token JWT assinado.
  String generateToken({
    required int idUsuario,
    required String tipoUsuario,
    int? idEmpresa,
  }) {
    final header = _encode({'alg': 'HS256', 'typ': 'JWT'});
    final exp =
        DateTime.now().add(const Duration(days: _expDays)).millisecondsSinceEpoch ~/
            1000;
    final payload = _encode({
      'sub': idUsuario,
      'tipo': tipoUsuario,
      if (idEmpresa != null && idEmpresa != 0) 'id_empresa': idEmpresa,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp': exp,
    });
    final signature = _sign('$header.$payload');
    return '$header.$payload.$signature';
  }

  /// Valida o token e retorna o payload, ou null se inválido/expirado.
  Map<String, dynamic>? verifyToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final expectedSig = _sign('${parts[0]}.${parts[1]}');
      if (expectedSig != parts[2]) return null;

      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;

      final exp = payload['exp'] as int?;
      if (exp == null ||
          DateTime.now().millisecondsSinceEpoch ~/ 1000 > exp) {
        return null;
      }

      return payload;
    } catch (_) {
      return null;
    }
  }

  String _encode(Map<String, dynamic> data) =>
      base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');

  String _sign(String data) {
    final key = utf8.encode(_secret);
    final bytes = utf8.encode(data);
    final digest = Hmac(sha256, key).convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
}
