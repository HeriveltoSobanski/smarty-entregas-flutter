import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthService {
  // Configure via: --dart-define=AUTH_URL=https://api.example.com
  // Dev local (Flutter Web): http://localhost:8080
  // Android Emulator:        http://10.0.2.2:8080
  // Dispositivo físico:      http://<IP-da-máquina>:8080
  static const String baseUrl = String.fromEnvironment(
    'AUTH_URL',
    defaultValue: 'http://localhost:8080',
  );

  AuthService() {
    if (kReleaseMode && !baseUrl.startsWith('https://')) {
      throw StateError(
        'AUTH_URL deve usar HTTPS em produção. '
        'Passe --dart-define=AUTH_URL=https://... no build. '
        'Recebido: $baseUrl',
      );
    }
  }

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
