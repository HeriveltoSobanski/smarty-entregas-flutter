import 'dart:convert';
import 'package:http/http.dart' as http;

class MercadoPagoService {
  final String _accessToken;
  static const _baseUrl = 'https://api.mercadopago.com';

  MercadoPagoService(this._accessToken);

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
        'X-Idempotency-Key': DateTime.now().millisecondsSinceEpoch.toString(),
      };

  /// Cria pagamento PIX. Retorna {qr_code, qr_code_base64, id_pagamento}.
  Future<Map<String, dynamic>> criarPagamentoPix({
    required double valor,
    required String descricao,
    required String emailPagador,
    required int idPedido,
  }) async {
    final body = jsonEncode({
      'transaction_amount': valor,
      'description': descricao,
      'payment_method_id': 'pix',
      'payer': {'email': emailPagador},
      'external_reference': 'pedido_$idPedido',
    });

    final resp = await http.post(
      Uri.parse('$_baseUrl/v1/payments'),
      headers: _headers,
      body: body,
    ).timeout(const Duration(seconds: 20));

    final data = jsonDecode(resp.body) as Map<String, dynamic>;

    if (resp.statusCode != 201) {
      throw Exception('MP PIX erro ${resp.statusCode}: ${data['message'] ?? resp.body}');
    }

    final txData = data['point_of_interaction']?['transaction_data'];
    return {
      'id_pagamento_mp': data['id']?.toString() ?? '',
      'status_pagamento': data['status'] ?? 'pending',
      'qr_code_pix': txData?['qr_code'] ?? '',
      'qr_code_base64': txData?['qr_code_base64'] ?? '',
    };
  }

  /// Cria pagamento com cartão usando token gerado pelo Flutter.
  /// Retorna {id_pagamento_mp, status_pagamento, status_detail}.
  Future<Map<String, dynamic>> criarPagamentoCartao({
    required double valor,
    required String token,
    required String emailPagador,
    required String descricao,
    required int idPedido,
    int parcelas = 1,
  }) async {
    final body = jsonEncode({
      'transaction_amount': valor,
      'token': token,
      'description': descricao,
      'installments': parcelas,
      'payer': {'email': emailPagador},
      'external_reference': 'pedido_$idPedido',
    });

    final resp = await http.post(
      Uri.parse('$_baseUrl/v1/payments'),
      headers: _headers,
      body: body,
    ).timeout(const Duration(seconds: 20));

    final data = jsonDecode(resp.body) as Map<String, dynamic>;

    if (resp.statusCode != 201) {
      throw Exception('MP Cartão erro ${resp.statusCode}: ${data['message'] ?? resp.body}');
    }

    return {
      'id_pagamento_mp': data['id']?.toString() ?? '',
      'status_pagamento': data['status'] ?? 'pending',
      'status_detail': data['status_detail'] ?? '',
    };
  }

  /// Consulta status de um pagamento pelo ID do MP.
  Future<Map<String, dynamic>> consultarPagamento(String idPagamentoMp) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/v1/payments/$idPagamentoMp'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw Exception('MP consulta erro ${resp.statusCode}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return {
      'id_pagamento_mp': data['id']?.toString() ?? '',
      'status_pagamento': data['status'] ?? 'pending',
      'status_detail': data['status_detail'] ?? '',
    };
  }
}
