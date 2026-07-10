import 'dart:convert';
import 'dart:math' as math;

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import '../services/mercadopago_service.dart';
import '../services/pix_brcode_service.dart';
import '../services/fcm_service.dart';
import 'notificacao_controller.dart';

class CriarPedidoController {
  final Pool conn;
  final MercadoPagoService _mp;
  final FcmService? fcmService;

  CriarPedidoController(this.conn, this._mp, {this.fcmService});

  // ----------------------------------------------------------------
  // POST /pedidos
  // Body: { id_empresa, itens, endereco_entrega, forma_pagamento,
  //         mp_card_token?, observacao?, troco_para?, codigo_cupom?,
  //         id_endereco? }
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

      final idUsuario = int.tryParse(request.context['userId']?.toString() ?? '');
      if (idUsuario == null) return _json(403, {'error': 'Acesso negado'});

      final idEmpresa = _parseInt(body['id_empresa']);
      if (idEmpresa == null) {
        return _json(400, {'error': 'id_empresa obrigatório'});
      }

      final enderecoEntrega = body['endereco_entrega']?.toString() ?? '';
      final observacao      = body['observacao']?.toString() ?? '';
      final formaPagamento  = body['forma_pagamento']?.toString() ?? '';
      final trocoPara       = _parseDouble(body['troco_para']);
      final codigoCupom     = body['codigo_cupom']?.toString().trim().toUpperCase();
      final idEndereco      = _parseInt(body['id_endereco']);
      final mpCardToken     = body['mp_card_token']?.toString();

      final rawItens = body['itens'];
      if (rawItens == null || rawItens is! List || rawItens.isEmpty) {
        return _json(400, {'error': 'itens obrigatório e não pode ser vazio'});
      }

      final itens = <Map<String, dynamic>>[];
      for (final item in rawItens) {
        if (item is! Map) return _json(400, {'error': 'Cada item deve ser um objeto'});
        final idProduto  = _parseInt(item['id_produto']);
        final quantidade = _parseInt(item['quantidade']);
        if (idProduto == null || quantidade == null) {
          return _json(400, {'error': 'Cada item deve ter id_produto e quantidade'});
        }
        if (quantidade <= 0) return _json(400, {'error': 'quantidade deve ser maior que zero'});

        final adicionaisIds = (item['adicionais'] as List?)
                ?.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
                .where((id) => id > 0)
                .toList() ??
            <int>[];

        itens.add({
          'id_produto':     idProduto,
          'quantidade':     quantidade,
          'observacao':     item['observacao']?.toString() ?? '',
          'adicionais_ids': adicionaisIds,
        });
      }

      // ---- Buscar preços reais do banco ----
      double subtotal = 0.0;
      final itensComPreco = <Map<String, dynamic>>[];

      for (final item in itens) {
        final idProduto  = item['id_produto'] as int;
        final quantidade = item['quantidade'] as int;

        final produtoResult = await conn.execute(
          Sql.named('''
            SELECT preco FROM produtos
            WHERE id_produto = @id AND id_empresa = @id_empresa AND ativo = true
          '''),
          parameters: {'id': idProduto, 'id_empresa': idEmpresa},
        );

        if (produtoResult.isEmpty) {
          return _json(422, {'error': 'Produto $idProduto inválido ou inativo'});
        }

        final precoUnit = _parseDouble(produtoResult.first[0]) ?? 0.0;

        double precoAdicionais = 0.0;
        final adicionaisIds = item['adicionais_ids'] as List<int>;
        if (adicionaisIds.isNotEmpty) {
          final placeholders = adicionaisIds.asMap().entries.map((e) => '@add${e.key}').join(', ');
          final params = <String, dynamic>{};
          for (var i = 0; i < adicionaisIds.length; i++) {
            params['add$i'] = adicionaisIds[i];
          }
          final adicionaisResult = await conn.execute(
            Sql.named('SELECT COALESCE(SUM(preco), 0) FROM produto_adicionais '
                'WHERE id_adicional IN ($placeholders) AND ativo = true'),
            parameters: params,
          );
          precoAdicionais = _parseDouble(adicionaisResult.first[0]) ?? 0.0;
        }

        final precoFinal = precoUnit + precoAdicionais;
        subtotal += precoFinal * quantidade;
        itensComPreco.add({...item, 'preco_unit': precoFinal});
      }

      // ---- Validar adicionais obrigatórios ----
      for (final item in itensComPreco) {
        final idProduto   = item['id_produto'] as int;
        final selectedIds = (item['adicionais_ids'] as List<int>).toSet();

        final gruposResult = await conn.execute(
          Sql.named('''
            SELECT DISTINCT grupo FROM produto_adicionais
            WHERE id_produto = @id AND obrigatorio = true AND ativo = true
          '''),
          parameters: {'id': idProduto},
        );

        for (final grupoRow in gruposResult) {
          final grupo = grupoRow[0]?.toString() ?? '';
          final itensGrupo = await conn.execute(
            Sql.named('''
              SELECT id_adicional FROM produto_adicionais
              WHERE id_produto = @id AND grupo = @grupo AND ativo = true
            '''),
            parameters: {'id': idProduto, 'grupo': grupo},
          );
          final grupoIds = itensGrupo.map((r) => r[0] as int).toSet();
          if (!selectedIds.any(grupoIds.contains)) {
            return _json(422, {'error': 'Selecione uma opção do grupo obrigatório: $grupo'});
          }
        }
      }

      // ---- Taxa de entrega server-side ----
      final empresaResult = await conn.execute(
        Sql.named('SELECT taxa_minima, latitude, longitude FROM empresas WHERE id_empresa = @id'),
        parameters: {'id': idEmpresa},
      );
      if (empresaResult.isEmpty) return _json(422, {'error': 'Empresa não encontrada'});

      final taxaMinima = _parseDouble(empresaResult.first[0]) ?? 7.0;
      final empLat     = _parseDouble(empresaResult.first[1]);
      final empLon     = _parseDouble(empresaResult.first[2]);

      double taxaEntregaFinal = taxaMinima;

      if (idEndereco != null && empLat != null && empLon != null) {
        final endResult = await conn.execute(
          Sql.named('''
            SELECT latitude, longitude FROM usuario_enderecos
            WHERE id_endereco = @id AND id_usuario = @id_usuario
          '''),
          parameters: {'id': idEndereco, 'id_usuario': idUsuario},
        );
        if (endResult.isNotEmpty) {
          final endLat = _parseDouble(endResult.first[0]);
          final endLon = _parseDouble(endResult.first[1]);
          if (endLat != null && endLon != null) {
            taxaEntregaFinal = taxaMinima + _haversineKm(empLat, empLon, endLat, endLon);
          }
        }
      }

      // ---- Validar cupom (sem incrementar ainda) ----
      double desconto = 0.0;
      String? cupomAplicado;
      int? idCupomAplicado;

      if (codigoCupom != null && codigoCupom.isNotEmpty) {
        final cupomResult = await conn.execute(
          Sql.named('''
            SELECT id_cupom, tipo, valor, valor_minimo, usos_maximos, usos_atuais, ativo, valido_ate
            FROM cupons WHERE codigo = @codigo
          '''),
          parameters: {'codigo': codigoCupom},
        );
        if (cupomResult.isEmpty) return _json(422, {'error': 'Cupom inválido'});

        final row         = cupomResult.first;
        final idCupom     = row[0] as int;
        final tipo        = row[1]?.toString() ?? 'percentual';
        final valor       = _parseDouble(row[2]) ?? 0.0;
        final valorMinimo = _parseDouble(row[3]) ?? 0.0;
        final usosMaximos = row[4] as int?;
        final usosAtuais  = row[5] as int? ?? 0;
        final ativo       = row[6] as bool? ?? false;
        final validoAte   = row[7];

        if (!ativo) return _json(422, {'error': 'Cupom inativo'});
        if (validoAte != null) {
          final expira = validoAte is DateTime ? validoAte : DateTime.tryParse(validoAte.toString());
          if (expira != null && expira.isBefore(DateTime.now())) {
            return _json(422, {'error': 'Cupom expirado'});
          }
        }
        if (usosMaximos != null && usosAtuais >= usosMaximos) {
          return _json(422, {'error': 'Cupom esgotado'});
        }
        if (subtotal < valorMinimo) {
          return _json(422, {
            'error': 'Pedido mínimo de R\$ ${valorMinimo.toStringAsFixed(2)} para este cupom',
          });
        }

        desconto = tipo == 'percentual' ? subtotal * (valor / 100) : (valor > subtotal ? subtotal : valor);
        desconto = double.parse(desconto.toStringAsFixed(2));
        cupomAplicado   = codigoCupom;
        idCupomAplicado = idCupom;
      }

      final valorTotal    = double.parse((subtotal - desconto).toStringAsFixed(2));
      final valorCobranca = valorTotal + taxaEntregaFinal;

      // ---- Validações específicas de pagamento (antes de qualquer escrita) ----
      if ((formaPagamento == 'cartao_credito' || formaPagamento == 'cartao_debito') &&
          (mpCardToken == null || mpCardToken.isEmpty)) {
        return _json(400, {'error': 'mp_card_token obrigatório para pagamento com cartão'});
      }

      // PIX: valida a chave do restaurante ANTES de criar o pedido,
      // evitando pedido órfão quando a empresa não tem chave cadastrada.
      String chavePix      = '';
      String nomeEmpresa   = 'Empresa';
      String cidadeEmpresa = '';
      if (formaPagamento == 'pix') {
        final empresaPix = await conn.execute(
          Sql.named('SELECT chave_pix, nome, cidade FROM empresas WHERE id_empresa = @id'),
          parameters: {'id': idEmpresa},
        );
        chavePix = empresaPix.isNotEmpty ? (empresaPix.first[0]?.toString() ?? '') : '';
        if (chavePix.isEmpty) {
          return _json(422, {
            'error': 'Este restaurante ainda não cadastrou sua chave PIX. '
                'Entre em contato com o restaurante para mais informações.',
          });
        }
        nomeEmpresa   = empresaPix.first[1]?.toString() ?? 'Empresa';
        cidadeEmpresa = empresaPix.first[2]?.toString() ?? '';
      }

      // ---- Email do usuário (necessário para o MP) ----
      final usuarioResult = await conn.execute(
        Sql.named('SELECT email FROM usuarios WHERE id_usuario = @id'),
        parameters: {'id': idUsuario},
      );
      final emailUsuario = usuarioResult.isNotEmpty ? (usuarioResult.first[0]?.toString() ?? '') : '';

      // Insere pedido + itens + incremento de cupom na MESMA transação.
      // Nada é persistido se qualquer passo falhar.
      Future<int> inserirPedido(TxSession s, String statusPagamento) async {
        final pedidoResult = await s.execute(
          Sql.named('''
            INSERT INTO pedidos
              (id_usuario, id_empresa, id_status, total,
               endereco_entrega, observacao, forma_pagamento, troco_para, taxa_entrega,
               codigo_cupom, desconto, status_pagamento)
            VALUES
              (@id_usuario, @id_empresa, 1, @total,
               @endereco_entrega, @observacao, @forma_pagamento, @troco_para, @taxa_entrega,
               @codigo_cupom, @desconto, @status_pagamento)
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
            'taxa_entrega':     taxaEntregaFinal,
            'codigo_cupom':     cupomAplicado,
            'desconto':         desconto,
            'status_pagamento': statusPagamento,
          },
        );
        final novoId = pedidoResult.first[0] as int;

        for (final item in itensComPreco) {
          await s.execute(
            Sql.named('''
              INSERT INTO pedido_itens (id_pedido, id_produto, quantidade, preco_unit, observacao)
              VALUES (@id_pedido, @id_produto, @quantidade, @preco_unit, @observacao)
            '''),
            parameters: {
              'id_pedido':  novoId,
              'id_produto': item['id_produto'],
              'quantidade': item['quantidade'],
              'preco_unit': item['preco_unit'],
              'observacao': item['observacao'],
            },
          );
        }

        if (idCupomAplicado != null) {
          // Incremento atômico: só consome se ainda houver usos disponíveis.
          // Evita ultrapassar usos_maximos em pedidos concorrentes.
          final cupomUpd = await s.execute(
            Sql.named('''
              UPDATE cupons SET usos_atuais = usos_atuais + 1
              WHERE id_cupom = @id
                AND (usos_maximos IS NULL OR usos_atuais < usos_maximos)
            '''),
            parameters: {'id': idCupomAplicado},
          );
          if (cupomUpd.affectedRows == 0) {
            // Esgotou entre a validação e o commit; desfaz a transação.
            throw _CupomEsgotadoException();
          }
        }

        return novoId;
      }

      // ---- DINHEIRO ----
      if (formaPagamento == 'dinheiro') {
        final taxaSmartySobrePedido = double.parse((valorTotal * 0.10).toStringAsFixed(2));
        final taxaSmartyEntrega     = double.parse((taxaEntregaFinal * 0.10).toStringAsFixed(2));
        final debitoEmpresa         = taxaSmartySobrePedido + taxaSmartyEntrega + taxaEntregaFinal;

        int idPedido = 0;
        await conn.runTx((s) async {
          idPedido = await inserirPedido(s, 'aprovado');
          // Débito condicional: não deixa o caixa da empresa ficar negativo.
          final saldoUpd = await s.execute(
            Sql.named('UPDATE empresas SET saldo = saldo - @debito '
                'WHERE id_empresa = @id AND saldo >= @debito'),
            parameters: {'debito': debitoEmpresa, 'id': idEmpresa},
          );
          if (saldoUpd.affectedRows == 0) {
            throw _SaldoInsuficienteException();
          }
          await s.execute(
            Sql.named('''
              INSERT INTO empresa_transacoes (id_empresa, tipo, valor, descricao, id_pedido)
              VALUES (@id_empresa, 'debito', @valor, @descricao, @id_pedido)
            '''),
            parameters: {
              'id_empresa': idEmpresa,
              'valor':      debitoEmpresa,
              'descricao':  'Taxa Smarty + entrega - Pedido #$idPedido',
              'id_pedido':  idPedido,
            },
          );
        });

        await _notificarNovoPedido(idEmpresa, idPedido);
        return _json(201, {
          'ok':               true,
          'id_pedido':        idPedido,
          'forma_pagamento':  'dinheiro',
          'status_pagamento': 'aprovado',
        });
      }

      // ---- PIX ----
      if (formaPagamento == 'pix') {
        int    idPedido = 0;
        String brCode   = '';
        await conn.runTx((s) async {
          idPedido = await inserirPedido(s, 'pending');
          brCode = PixBrCodeService.gerarPayload(
            chavePix:      chavePix,
            valor:         valorCobranca,
            nomeRecebedor: nomeEmpresa,
            cidade:        cidadeEmpresa,
            idPedido:      idPedido,
          );
          await s.execute(
            Sql.named('UPDATE pedidos SET qr_code_pix = @qr WHERE id_pedido = @id'),
            parameters: {'qr': brCode, 'id': idPedido},
          );
        });

        await _notificarNovoPedido(idEmpresa, idPedido);
        return _json(201, {
          'ok':              true,
          'id_pedido':       idPedido,
          'forma_pagamento': 'pix',
          'qr_code_pix':     brCode,
          'qr_code_base64':  '',
          'id_pagamento_mp': '',
        });
      }

      // ---- CARTÃO ----
      // Pedido é criado como 'pending'; a cobrança externa (MP) ocorre após
      // o commit. Se recusar/falhar, marcamos 'rejected' e devolvemos o cupom.
      if (formaPagamento == 'cartao_credito' || formaPagamento == 'cartao_debito') {
        int idPedido = 0;
        await conn.runTx((s) async {
          idPedido = await inserirPedido(s, 'pending');
        });

        Map<String, dynamic> mpResult;
        try {
          mpResult = await _mp.criarPagamentoCartao(
            valor:        valorCobranca,
            token:        mpCardToken!,
            emailPagador: emailUsuario.isNotEmpty ? emailUsuario : 'cliente@smartyentregas.com',
            descricao:    'Pedido #$idPedido - Smarty Entregas',
            idPedido:     idPedido,
          );
        } catch (_) {
          await conn.execute(
            Sql.named("UPDATE pedidos SET status_pagamento = 'rejected' WHERE id_pedido = @id"),
            parameters: {'id': idPedido},
          );
          await _devolverCupom(idCupomAplicado);
          return _json(502, {'error': 'Falha ao processar o pagamento. Tente novamente.'});
        }

        final statusMp = mpResult['status_pagamento'] as String;
        await conn.execute(
          Sql.named('''
            UPDATE pedidos SET id_pagamento_mp = @id_mp, status_pagamento = @status
            WHERE id_pedido = @id
          '''),
          parameters: {'id_mp': mpResult['id_pagamento_mp'], 'status': statusMp, 'id': idPedido},
        );

        if (statusMp == 'rejected') {
          await _devolverCupom(idCupomAplicado);
          return _json(422, {
            'error': 'Pagamento recusado. Verifique os dados do cartão.',
            'status_detail': mpResult['status_detail'],
          });
        }

        await _notificarNovoPedido(idEmpresa, idPedido);
        return _json(201, {
          'ok':               true,
          'id_pedido':        idPedido,
          'forma_pagamento':  formaPagamento,
          'status_pagamento': statusMp,
          'id_pagamento_mp':  mpResult['id_pagamento_mp'],
        });
      }

      // Forma de pagamento não reconhecida
      return _json(400, {'error': 'Forma de pagamento inválida: $formaPagamento'});
    } on _CupomEsgotadoException {
      return _json(422, {'error': 'Cupom esgotado'});
    } on _SaldoInsuficienteException {
      return _json(422, {
        'error': 'Este restaurante está temporariamente indisponível para '
            'pagamento em dinheiro. Escolha outra forma de pagamento.',
      });
    } catch (e) {
      return _json(500, {'error': 'Erro interno ao criar pedido'});
    }
  }

  // ----------------------------------------------------------------
  // Helpers
  // ----------------------------------------------------------------

  /// Notifica o restaurante sobre um novo pedido (best-effort).
  /// Chamado só após o pedido ser efetivamente persistido.
  Future<void> _notificarNovoPedido(int idEmpresa, int idPedido) async {
    try {
      final empresaUserResult = await conn.execute(
        Sql.named('SELECT id_usuario FROM empresas WHERE id_empresa = @id'),
        parameters: {'id': idEmpresa},
      );
      if (empresaUserResult.isNotEmpty) {
        final idUsuarioEmpresa = empresaUserResult.first[0];
        final uid = idUsuarioEmpresa is int
            ? idUsuarioEmpresa
            : int.tryParse(idUsuarioEmpresa?.toString() ?? '');
        if (uid != null) {
          await NotificacaoController.criar(
            conn:       conn,
            idUsuario:  uid,
            titulo:     'Novo pedido recebido! 🛒',
            corpo:      'Pedido #$idPedido chegou. Toque para ver os detalhes.',
            tipo:       'novo_pedido',
            idPedido:   idPedido,
            fcmService: fcmService,
          );
        }
      }
    } catch (_) {}
  }

  /// Devolve um uso de cupom quando o pagamento não se concretiza.
  Future<void> _devolverCupom(int? idCupom) async {
    if (idCupom == null) return;
    try {
      await conn.execute(
        Sql.named('UPDATE cupons SET usos_atuais = GREATEST(usos_atuais - 1, 0) WHERE id_cupom = @id'),
        parameters: {'id': idCupom},
      );
    } catch (_) {}
  }

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

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.pow(math.sin(dLon / 2), 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Response _json(int status, Map<String, dynamic> body) => Response(
        status,
        body: jsonEncode(body),
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
}

/// Sinaliza que o cupom esgotou entre a validação e o commit do pedido.
/// Usada para abortar a transação e responder 422 sem persistir o pedido.
class _CupomEsgotadoException implements Exception {}

/// Sinaliza que o caixa da empresa não cobre o débito de um pedido em dinheiro.
/// Aborta a transação sem deixar o saldo negativo.
class _SaldoInsuficienteException implements Exception {}
