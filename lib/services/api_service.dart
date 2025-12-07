import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Se no backend você mudou a porta/host, ajuste aqui
  static const String baseUrl = 'http://localhost:8080';

  // ---------------- REGISTRO CLIENTE ----------------
  static Future<String?> registerCliente({
    required String nome,
    required String email,
    required String senha,
    required String cpf,
    String? telefone,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/register/cliente');

      final body = {
        "nome": nome,
        "email": email,
        "senha": senha,
        "cpf": cpf,
      };

      if (telefone != null) {
        body["telefone"] = telefone;
      }

      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return null; // sucesso
      }

      if (resp.body.isNotEmpty) {
        final data = jsonDecode(resp.body);
        return data['error']?.toString() ?? 'Erro ao registrar';
      }

      return 'Erro ao registrar (código ${resp.statusCode})';
    } catch (e) {
      return 'Erro de conexão com o servidor: $e';
    }
  }

  // ---------------- LOGIN ----------------
  static Future<Map<String, dynamic>?> login({
    required String email,
    required String senha,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/login');

      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"email": email, "senha": senha}),
      );

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }

      if (resp.body.isNotEmpty) {
        final data = jsonDecode(resp.body);
        final msg = data['error']?.toString() ?? 'Erro ao fazer login';
        throw Exception(msg);
      }

      throw Exception('Erro ao fazer login (código ${resp.statusCode})');
    } catch (e) {
      throw Exception('Erro de conexão com o servidor: $e');
    }
  }
}
