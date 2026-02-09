import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  // Para Flutter Web, localhost funciona.
  // Se for Android Emulator: use http://10.0.2.2:8080
  // Se for dispositivo físico: use o IP da sua máquina (ex: http://192.168.x.x:8080)
  final String baseUrl = 'http://localhost:8080';

  Future<Map<String, dynamic>> login({
    required String email,
    required String senha,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');

    final res = await http.post(
      url,
      headers: const {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({'email': email, 'senha': senha}),
    );

    // Sempre tenta interpretar como JSON (se não for, estoura com mensagem boa)
    Map<String, dynamic> data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Resposta inválida do servidor (${res.statusCode}): ${res.body}');
    }

    if (res.statusCode == 200) return data;

    // Backend costuma mandar: {"error":"Credenciais inválidas"}
    final msg = (data['error'] ?? data['message'] ?? 'Erro ao logar').toString();
    throw Exception(msg);
  }
}
