import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

class CriarPedidoController {
  final Connection conn;

  CriarPedidoController(this.conn);

  // ----------------------------------------------------------------
  // POST /pedidos
  // Body: { id_usuario, id_empresa, itens: [{id_produto, quantidade, preco_unit, adicionais?: [int]}] }
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
      // id_usuario sempre vem do JWT — ignora o body para evitar spoofing
      final idUsuario = int.tryParse(request.context['userId']?.toString() ?? '');
      if (idUsuario == null) {
        return _json(403, {'error': 'Acesso negado'});
      }

      final idEmpresa = _parseInt(body['id_empresa']);
      if (idEmpresa == null) {
        return _json(400, {'error': 'id_empresa obrigatório e deve ser inteiro'});
      }

      final enderecoEntrega = body['endereco_entrega']?.toString() ?? '';
      final observacao      = body['observacao']?.toString() ?? '';
      final formaPagamento  = body['forma_pagamento']?.toString() ?? '';
      final trocoPara       = _parseDouble(body['troco_para']);
      final taxaEntrega     = _parseDouble(body['taxa_entrega']) ?? 0.0;
      final codigoCupom     = body['codigo_cupom']?.toString().trim().toUpperCase();

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

        final adicionaisIds = (item['adicionais'] as List?)
            ?.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
            .where((id) => id > 0)
            .toList() ?? <int>[];

        itens.add({
          'id_produto': idProduto,
          'quantidade': quantidade,
          'preco_unit': precoUnit,
          'observacao': item['observacao']?.toString() ?? '',
          'adicionais_ids': adicionaisIds,
        });
      }

      // ---- Validar adicionais obrigatórios ----
      for (final item in itens) {
        final idProduto    = item['id_produto'] as int;
        final selectedIds  = ((item['adicionais_ids'] as List<int>)).toSet();

        final gruposResult = await conn.execute(
          Sql.named('''
            SELECT DISTINCT grupo
            FROM produto_adicionais
            WHERE id_produto = @id AND obrigatorio = true AND ativo = true
          '''),
          parameters: {'id': idProduto},
        );

        for (final grupoRow in gruposResult) {
          final grupo = grupoRow[0]?.toString() ?? '';
          final itensGrupo = await conn.execute(
            Sql.named('''
              SELECT id_adicional
              FROM produto_adicionais
              WHERE id_produto = @id AND grupo = @grupo AND ativo = true
            '''),
            parameters: {'id': idProduto, 'grupo': grupo},
          );
          final grupoIds = itensGrupo.map((r) => r[0] as int).toSet();
          if (!selectedIds.any(grupoIds.contains)) {
            return _json(422, {
              'error': 'Selecione uma opção do grupo obrigatório: $grupo',
            });
          }
        }
      }

      // ---- Calcular valor total ----
      final subtotal = itens.fold<double>(
        0.0,
        (acc, item) => acc + (item['preco_unit'] as double) * (item['quantidade'] as int),
      );

      // ---- Validar e aplicar cupom (se informado) ----
      double desconto = 0.0;
      String? cupomAplicado;

      if (codigoCupom != null && codigoCupom.isNotEmpty) {
        final cupomResult = await conn.execute(
          Sql.named('''
            SELECT id_cupom, tipo, valor, valor_minimo, usos_maximos, usos_atuais, ativo, valido_ate
            FROM cupons WHERE codigo = @codigo
          '''),
          parameters: {'codigo': codigoCupom},
        );

        if (cupomResult.isEmpty) {
          return _json(422, {'error': 'Cupom inválido'});
        }

        final row          = cupomResult.first;
        final idCupom      = row[0] as int;
        final tipo         = row[1]?.toString() ?? 'percentual';
        final valor        = _parseDouble(row[2]) ?? 0.0;
        final valorMinimo  = _parseDouble(row[3]) ?? 0.0;
        final usosMaximos  = row[4] as int?;
        final usosAtuais   = row[5] as int? ?? 0;
        final ativo        = row[6] as bool? ?? false;
        final validoAte    = row[7];

        if (!ativo) return _json(422, {'error': 'Cupom inativo'});

        if (validoAte != null) {
          final expira = validoAte is DateTime
              ? validoAte
              : DateTime.tryParse(validoAte.toString());
          if (expira != null && expira.isBefore(DateTime.now())) {
            return _json(422, {'error': 'Cupom expirado'});
          }
        }

        if (usosMaximos != null && usosAtuais >= usosMaximos) {
          return _json(422, {'error': 'Cupom esgotado'});
        }

        if (subtotal < valorMinimo) {
          return _json(422, {
            'error': 'Pedido mínimo de R\$ ${valorMinimo.toStringAsFixed(2)} para usar este cupom',
          });
        }

        desconto = tipo == 'percentual'
            ? subtotal * (valor / 100)
            : (valor > subtotal ? subtotal : valor);
        desconto = double.parse(desconto.toStringAsFixed(2));
        cupomAplicado = codigoCupom;

        await conn.execute(
          Sql.named('UPDATE cupons SET usos_atuais = usos_atuais + 1 WHERE id_cupom = @id'),
          parameters: {'id': idCupom},
        );
      }

      final valorTotal = subtotal - desconto;

      // ---- Inserir pedido (id_status = 1 → 'Aguardando') ----
      final pedidoResult = await conn.execute(
        Sql.named('''
          INSERT INTO pedidos
            (id_usuario, id_empresa, id_status, total,
             endereco_entrega, observacao, forma_pagamento, troco_para, taxa_entrega,
             codigo_cupom, desconto)
          VALUES
            (@id_usuario, @id_empresa, 1, @total,
             @endereco_entrega, @observacao, @forma_pagamento, @troco_para, @taxa_entrega,
             @codigo_cupom, @desconto)
          RETURNING id_pedido
        '''),
        parameters: {
          'id_usuario':       idUsuario,
          'id_empresa':       idEmpresa,
          'total':            valorTotal,
          'endereco_entrega': enderecoEntrega,
          'observacao':       observacao,
          'forma_pagamento':  formaPagamento.isNotEmpty ? formaPagamento : null,
          'troco_para':       trocoPara,
          'taxa_entrega':     taxaEntrega,
          'codigo_cupom':     cupomAplicado,
          'desconto':         desconto,
        },
      );

      final idPedido = pedidoResult.first[0] as int;

      // ---- Inserir itens do pedido ----
      for (final item in itens) {
        await conn.execute(
          Sql.named('''
            INSERT INTO pedido_itens (id_pedido, id_produto, quantidade, preco_unit, observacao)
            VALUES (@id_pedido, @id_produto, @quantidade, @preco_unit, @observacao)
          '''),
          parameters: {
            'id_pedido':  idPedido,
            'id_produto': item['id_produto'],
            'quantidade': item['quantidade'],
            'preco_unit': item['preco_unit'],
            'observacao': item['observacao'],
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
