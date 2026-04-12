import 'package:shared_preferences/shared_preferences.dart';

/// Persiste e recupera dados de sessão entre reinicializações do app.
class AuthStorage {
  static const _keyToken       = 'auth_token';
  static const _keyIdUsuario   = 'auth_id_usuario';
  static const _keyEmail       = 'auth_email';
  static const _keyNome        = 'auth_nome';
  static const _keyTipo        = 'auth_tipo_usuario';
  static const _keyIdEmpresa   = 'auth_id_empresa';

  static Future<void> save({
    required String token,
    required int    idUsuario,
    required String email,
    required String nome,
    required String tipoUsuario,
    int?            idEmpresa,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken,     token);
    await prefs.setInt   (_keyIdUsuario, idUsuario);
    await prefs.setString(_keyEmail,     email);
    await prefs.setString(_keyNome,      nome);
    await prefs.setString(_keyTipo,      tipoUsuario);
    if (idEmpresa != null) {
      await prefs.setInt(_keyIdEmpresa, idEmpresa);
    } else {
      await prefs.remove(_keyIdEmpresa);
    }
  }

  static Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    if (token == null) return null;
    return {
      'token':       token,
      'idUsuario':   prefs.getInt(_keyIdUsuario) ?? 0,
      'email':       prefs.getString(_keyEmail)  ?? '',
      'nome':        prefs.getString(_keyNome)   ?? '',
      'tipoUsuario': prefs.getString(_keyTipo)   ?? 'cliente',
      'idEmpresa':   prefs.getInt(_keyIdEmpresa),
    };
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyIdUsuario);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyNome);
    await prefs.remove(_keyTipo);
    await prefs.remove(_keyIdEmpresa);
  }
}
