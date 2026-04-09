import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

class PedidoController {
  final Connection conn;

  PedidoController(this.conn);

  // ----------------------------------------------------------------
  // GET /pedidos/empresa?id_empresa=X&inicio=YYYY-MM-DD&fim=YYYY-MM-DD
  // ----------------------------------------------------------------
  Future<Response> getPedidosByEmpresa(Request request) async {
    try {
      final idEmpresa =
          int.tryParse(request.url.queryParameters['id_empresa'] ?? '');
      if (idEmpresa == null) {
        return _json(400, {'error': 'id_empresa obrigatório'});
      }

      final inicio = request.url.queryParameters['inicio'];
      final fim    = request.url.queryParameters['fim'];

      final hasFilter = inicio != null &&
          inicio.isNotEmpty &&
          fim != null &&
          fim.isNotEmpty;

      final query = '''
        SELECT p.id_pedido,
               u.nome                                    AS cliente,
               sp.nome                                   AS status,
               p.valor_total,
               p.criado_em,
               STRING_AGG(pr.nome, ', ' ORDER BY pr.nome) AS itens,
               p.id_status,
               COALESCE(p.quase_pronto, false)            AS quase_pronto,
               COALESCE(p.tipo_entrega, '')               AS tipo_entrega
        FROM pedidos p
        JOIN usuarios u     ON u.id_usuario  = p.id_usuario
        JOIN status_pedidos sp ON sp.id_status = p.id_status
        LEFT JOIN pedido_itens pitem ON pitem.id_pedido  = p.id_pedido
        LEFT JOIN produtos pr       ON pr.id_produto     = pitem.id_produto
        WHERE p.id_empresa = @id_empresa
          ${hasFilter ? 'AND p.criado_em >= @inicio::timestamp AND p.criado_em < (@fim::date + INTERVAL \'1 day\')' : ''}
        GROUP BY p.id_pedido, u.nome, sp.nome, p.valor_total, p.criado_em,
                 p.id_status, p.quase_pronto, p.tipo_entrega
        ORDER BY p.criado_em DESC
      ''';

      final params = <String, dynamic>{'id_empresa': idEmpresa};
      if (hasFilter) {
        params['inicio'] = inicio;
        params['fim']    = fim;
      }

      final result =
          await conn.execute(Sql.named(query), parameters: params);

      final list = result.map((r) => {
        'id_pedido':    r[0],
        'cliente':      r[1]?.toString() ?? '',
        'status':       r[2]?.toString() ?? '',
        'valor_total':  r[3],
        'criado_em':    r[4]?.toString() ?? '',
        'itens':        r[5]?.toString() ?? '',
        'id_status':    r[6],
        'quase_pronto': r[7] as bool? ?? false,
        'tipo_entrega': r[8]?.toString() ?? '',
      }).toList();

      return _json(200, {'pedidos': list});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // GET /pedidos/:id/detalhes
  // Retorna pedido completo com itens, adicionais, cliente, endereço
  // ----------------------------------------------------------------
  Future<Response> getPedidoDetalhes(Request request, String id) async {
    try {
      final idPedido = int.tryParse(id);
      if (idPedido == null) return _json(400, {'error': 'id inválido'});

      // Pedido base
      final pedResult = await conn.execute(
        Sql.named('''
          SELECT p.id_pedido, p.id_status, sp.nome AS status,
                 p.valor_total, p.criado_em,
                 u.nome AS cliente, u.email AS cliente_email,
                 u.telefone AS cliente_telefone,
                 p.endereco_entrega, p.observacao,
                 COALESCE(p.quase_pronto, false) AS quase_pronto,
                 COALESCE(p.tipo_entrega, '')    AS tipo_entrega
          FROM pedidos p
          JOIN usuarios u        ON u.id_usuario  = p.id_usuario
          JOIN status_pedidos sp ON sp.id_status  = p.id_status
          WHERE p.id_pedido = @pedido_id
          LIMIT 1
        '''),
        parameters: {'pedido_id': idPedido},
      );

      if (pedResult.isEmpty) return _json(404, {'error': 'Pedido não encontrado'});
      final r = pedResult.first;

      // Itens
      final itensResult = await conn.execute(
        Sql.named('''
          SELECT pr.nome AS produto, pi.quantidade, pi.preco_unit,
                 COALESCE(pi.observacao, '') AS observacao
          FROM pedido_itens pi
          JOIN produtos pr ON pr.id_produto = pi.id_produto
          WHERE pi.id_pedido = @pedido_id
        '''),
        parameters: {'pedido_id': idPedido},
      );

      final itens = itensResult.map((i) => {
        'produto':    i[0]?.toString() ?? '',
        'quantidade': i[1],
        'preco_unit': i[2],
        'observacao': i[3]?.toString() ?? '',
      }).toList();

      return _json(200, {
        'pedido': {
          'id_pedido':        r[0],
          'id_status':        r[1],
          'status':           r[2]?.toString() ?? '',
          'valor_total':      r[3],
          'criado_em':        r[4]?.toString() ?? '',
          'cliente':          r[5]?.toString() ?? '',
          'cliente_email':    r[6]?.toString() ?? '',
          'cliente_telefone': r[7]?.toString() ?? '',
          'endereco_entrega': r[8]?.toString() ?? '',
          'observacao':       r[9]?.toString() ?? '',
          'quase_pronto':     r[10] as bool? ?? false,
          'tipo_entrega':     r[11]?.toString() ?? '',
          'itens':            itens,
        }
      });
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // GET /pedidos/cliente?id_usuario=X
  // ----------------------------------------------------------------
  Future<Response> getPedidosByCliente(Request request) async {
    try {
      final idUsuario =
          int.tryParse(request.url.queryParameters['id_usuario'] ?? '');
      if (idUsuario == null) {
        return _json(400, {'error': 'id_usuario obrigatório'});
      }

      final result = await conn.execute(
        Sql.named('''
          SELECT p.id_pedido,
                 e.nome                                    AS empresa,
                 sp.nome                                   AS status,
                 p.valor_total,
                 p.criado_em,
                 STRING_AGG(pr.nome, ', ' ORDER BY pr.nome) AS itens,
                 p.id_status,
                 COALESCE(p.quase_pronto, false)            AS quase_pronto
          FROM pedidos p
          JOIN empresas e       ON e.id_empresa  = p.id_empresa
          JOIN status_pedidos sp ON sp.id_status = p.id_status
          LEFT JOIN pedido_itens pitem ON pitem.id_pedido = p.id_pedido
          LEFT JOIN produtos pr        ON pr.id_produto   = pitem.id_produto
          WHERE p.id_usuario = @id_usuario
          GROUP BY p.id_pedido, e.nome, sp.nome, p.valor_total, p.criado_em,
                   p.id_status, p.quase_pronto
          ORDER BY p.criado_em DESC
        '''),
        parameters: {'id_usuario': idUsuario},
      );

      final list = result.map((r) => {
        'id_pedido':    r[0],
        'empresa':      r[1]?.toString() ?? '',
        'status':       r[2]?.toString() ?? '',
        'valor_total':  r[3],
        'criado_em':    r[4]?.toString() ?? '',
        'itens':        r[5]?.toString() ?? '',
        'id_status':    r[6],
        'quase_pronto': r[7] as bool? ?? false,
      }).toList();

      return _json(200, {'pedidos': list});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // PATCH /pedidos/:id/status
  // Body: { id_status: int }
  // ----------------------------------------------------------------
  Future<Response> atualizarStatus(Request request, String id) async {
    try {
      final idPedido = int.tryParse(id);
      if (idPedido == null) return _json(400, {'error': 'id inválido'});

      final bodyStr = await request.readAsString();
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      final idStatus = body['id_status'];
      if (idStatus == null) return _json(400, {'error': 'id_status obrigatório'});

      final novoStatus = idStatus is int ? idStatus : int.tryParse(idStatus.toString());
      if (novoStatus == null) return _json(400, {'error': 'id_status deve ser inteiro'});

      await conn.execute(
        Sql.named('UPDATE pedidos SET id_status = @novo_status WHERE id_pedido = @pedido_id'),
        parameters: {'novo_status': novoStatus, 'pedido_id': idPedido},
      );

      return _json(200, {'ok': true});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // PATCH /pedidos/:id/quase-pronto
  // Marca quase_pronto=true e avisa cliente
  // ----------------------------------------------------------------
  Future<Response> marcarQuasePronto(Request request, String id) async {
    try {
      final idPedido = int.tryParse(id);
      if (idPedido == null) return _json(400, {'error': 'id inválido'});
      await conn.execute(
        Sql.named('UPDATE pedidos SET quase_pronto = true WHERE id_pedido = @pedido_id'),
        parameters: {'pedido_id': idPedido},
      );
      return _json(200, {'ok': true});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // PATCH /pedidos/:id/chamar-motoboy
  // tipo_entrega='motoboy', avança para status 6 (Aguardando Motoboy)
  // ----------------------------------------------------------------
  Future<Response> chamarMotoboy(Request request, String id) async {
    try {
      final idPedido = int.tryParse(id);
      if (idPedido == null) return _json(400, {'error': 'id inválido'});
      await conn.execute(
        Sql.named('''
          UPDATE pedidos
          SET tipo_entrega = 'motoboy', id_status = 6
          WHERE id_pedido = @pedido_id
        '''),
        parameters: {'pedido_id': idPedido},
      );
      return _json(200, {'ok': true});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // PATCH /pedidos/:id/entrega-propria
  // tipo_entrega='propria', avança para status 3 (A Caminho)
  // ----------------------------------------------------------------
  Future<Response> entregaPropria(Request request, String id) async {
    try {
      final idPedido = int.tryParse(id);
      if (idPedido == null) return _json(400, {'error': 'id inválido'});
      await conn.execute(
        Sql.named('''
          UPDATE pedidos
          SET tipo_entrega = 'propria', id_status = 3
          WHERE id_pedido = @pedido_id
        '''),
        parameters: {'pedido_id': idPedido},
      );
      return _json(200, {'ok': true});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  Response _json(int status, Map<String, dynamic> body) {
    return Response(
      status,
      body: jsonEncode(body),
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}
