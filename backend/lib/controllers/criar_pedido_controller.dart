import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

class CriarPedidoController {
  final Connection conn;

  CriarPedidoController(this.conn);

  // ----------------------------------------------------------------
  // POST /pedidos
  // Body: { id_usuario, id_empresa, itens: [{id_produto, quantidade, preco_unit}] }
  // ----------------------------------------------------------------
  Future<Response> criarPedido(Request request) async {
    try {
      final bodyStr = await request.readAsString();
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(bodyStr) as Map<String, dynamic>;
      } catch (_) {
        return _json(400, {'error': 'Body JSON inválido'});
      }

      // ---- Validação de campos obrigatórios ----
      final idUsuario = _parseInt(body['id_usuario']);
      if (idUsuario == null) {
        return _json(400, {'error': 'id_usuario obrigatório e deve ser inteiro'});
      }

      final idEmpresa = _parseInt(body['id_empresa']);
      if (idEmpresa == null) {
        return _json(400, {'error': 'id_empresa obrigatório e deve ser inteiro'});
      }

      final rawItens = body['itens'];
      if (rawItens == null || rawItens is! List || rawItens.isEmpty) {
        return _json(400, {'error': 'itens obrigatório e não pode ser vazio'});
      }

      final itens = <Map<String, dynamic>>[];
      for (final item in rawItens) {
        if (item is! Map) {
          return _json(400, {'error': 'Cada item deve ser um objeto'});
        }
        final idProduto = _parseInt(item['id_produto']);
        final quantidade = _parseInt(item['quantidade']);
        final precoUnit  = _parseDouble(item['preco_unit']);

        if (idProduto == null || quantidade == null || precoUnit == null) {
          return _json(400, {
            'error': 'Cada item deve ter id_produto (int), quantidade (int) e preco_unit (num)'
          });
        }
        if (quantidade <= 0) {
          return _json(400, {'error': 'quantidade deve ser maior que zero'});
        }

        itens.add({
          'id_produto': idProduto,
          'quantidade': quantidade,
          'preco_unit': precoUnit,
        });
      }

      // ---- Calcular valor total ----
      final valorTotal = itens.fold<double>(
        0.0,
        (acc, item) => acc + (item['preco_unit'] as double) * (item['quantidade'] as int),
      );

      // ---- Inserir pedido (id_status = 1 → 'Criado') ----
      final pedidoResult = await conn.execute(
        Sql.named('''
          INSERT INTO pedidos (id_usuario, id_empresa, id_status, valor_total)
          VALUES (@id_usuario, @id_empresa, 1, @valor_total)
          RETURNING id_pedido
        '''),
        parameters: {
          'id_usuario':  idUsuario,
          'id_empresa':  idEmpresa,
          'valor_total': valorTotal,
        },
      );

      final idPedido = pedidoResult.first[0] as int;

      // ---- Inserir itens do pedido ----
      for (final item in itens) {
        await conn.execute(
          Sql.named('''
            INSERT INTO pedido_itens (id_pedido, id_produto, quantidade, preco_unit)
            VALUES (@id_pedido, @id_produto, @quantidade, @preco_unit)
          '''),
          parameters: {
            'id_pedido':  idPedido,
            'id_produto': item['id_produto'],
            'quantidade': item['quantidade'],
            'preco_unit': item['preco_unit'],
          },
        );
      }

      return _json(201, {'ok': true, 'id_pedido': idPedido});
    } catch (e) {
      return _json(500, {
        'error': 'Erro interno ao criar pedido',
        'details': e.toString(),
      });
    }
  }

  // ----------------------------------------------------------------
  // Helpers
  // ----------------------------------------------------------------
  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Response _json(int status, Map<String, dynamic> body) {
    return Response(
      status,
      body: jsonEncode(body),
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}
