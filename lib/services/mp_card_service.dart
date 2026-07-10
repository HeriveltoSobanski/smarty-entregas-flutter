import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Tokeniza dados do cartão via Mercado Pago usando a Public Key.
/// O token gerado é enviado ao backend para processar o pagamento.
class MpCardService {
  static const _publicKey = String.fromEnvironment(
    'MP_PUBLIC_KEY',
    defaultValue: 'TEST-2409b6bf-8b29-4076-929a-41c95d6407b2',
  );

  static Future<Map<String, dynamic>> tokenizarCartao({
    required String numero,
    required String mesExpiracao,
    required String anoExpiracao,
    required String cvv,
    required String nomePortador,
    required String cpf,
  }) async {
    // Impede que um build de produção cobre no ambiente de testes do MP.
    if (kReleaseMode && _publicKey.startsWith('TEST-')) {
      throw Exception(
        'Pagamento com cartão não configurado para produção. '
        'Rebuilde com --dart-define=MP_PUBLIC_KEY=APP_USR-...',
      );
    }

    final body = jsonEncode({
      'card_number':      numero.replaceAll(' ', ''),
      'expiration_month': int.parse(mesExpiracao),
      'expiration_year':  int.parse(anoExpiracao),
      'security_code':    cvv,
      'cardholder': {
        'name': nomePortador.toUpperCase(),
        'identification': {'type': 'CPF', 'number': cpf.replaceAll(RegExp(r'\D'), '')},
      },
    });

    final resp = await http.post(
      Uri.parse('https://api.mercadopago.com/v1/card_tokens'),
      headers: {
        'Content-Type': 'application/json',
        'X-Public-Key': _publicKey,
      },
      body: body,
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;

    if (resp.statusCode != 201) {
      throw Exception(data['message'] ?? 'Erro ao tokenizar cartão');
    }

    return {
      'token': data['id']?.toString() ?? '',
      'bin':   data['first_six_digits']?.toString() ?? '',
    };
  }
}
