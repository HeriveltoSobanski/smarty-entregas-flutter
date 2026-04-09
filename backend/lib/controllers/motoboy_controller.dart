import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

class MotoboyController {
  final Connection conn;

  MotoboyController(this.conn);

  // ----------------------------------------------------------------
  // GET /motoboy/disponiveis
  // Pedidos com status "Em Preparo" (id_status=2) sem motoboy atribuído
  // ----------------------------------------------------------------
  Future<Response> getDisponiveis(Request request) async {
    try {
      final result = await conn.execute(
        Sql.named('''
          SELECT p.id_pedido,
                 e.nome                                     AS empresa,
                 COALESCE(e.endereco, '')                   AS empresa_endereco,
                 sp.nome                                    AS status,
                 p.valor_total,
                 p.criado_em,
                 p.endereco_entrega,
                 COALESCE(p.observacao, '')                 AS observacao,
                 STRING_AGG(pr.nome, ', ' ORDER BY pr.nome) AS itens
          FROM pedidos p
          JOIN empresas e        ON e.id_empresa  = p.id_empresa
          JOIN status_pedidos sp ON sp.id_status  = p.id_status
          LEFT JOIN pedido_itens pitem ON pitem.id_pedido = p.id_pedido
          LEFT JOIN produtos pr        ON pr.id_produto   = pitem.id_produto
          WHERE p.id_status = 6
            AND p.id_motoboy IS NULL
          GROUP BY p.id_pedido, e.nome, e.endereco, sp.nome,
                   p.valor_total, p.criado_em, p.endereco_entrega, p.observacao
          ORDER BY p.criado_em ASC
        '''),
        parameters: {},
      );

      final list = result.map((r) => {
        'id_pedido':         r[0],
        'empresa':           r[1]?.toString() ?? '',
        'empresa_endereco':  r[2]?.toString() ?? '',
        'status':            r[3]?.toString() ?? '',
        'valor_total':       r[4],
        'criado_em':         r[5]?.toString() ?? '',
        'endereco_entrega':  r[6]?.toString() ?? '',
        'observacao':        r[7]?.toString() ?? '',
        'itens':             r[8]?.toString() ?? '',
      }).toList();

      return _json(200, {'pedidos': list});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // GET /motoboys/count
  // Retorna quantos motoboys estão disponíveis e em rota
  // ----------------------------------------------------------------
  Future<Response> getMotoboyCount(Request request) async {
    try {
      final result = await conn.execute(
        Sql.named('''
          SELECT
            COUNT(*) FILTER (WHERE status_motoboy = 'disponivel') AS disponiveis,
            COUNT(*) FILTER (WHERE status_motoboy = 'em_rota')    AS em_rota
          FROM usuarios
          WHERE tipo_usuario = 'motoboy'
        '''),
        parameters: {},
      );
      final r = result.first;
      return _json(200, {
        'disponiveis': r[0],
        'em_rota':     r[1],
      });
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // GET /motoboy/em-rota?id_motoboy=X
  // Entregas que o motoboy está atualmente entregando (status=3)
  // ----------------------------------------------------------------
  Future<Response> getEmRota(Request request) async {
    try {
      final idMotoboy =
          int.tryParse(request.url.queryParameters['id_motoboy'] ?? '');
      if (idMotoboy == null) {
        return _json(400, {'error': 'id_motoboy obrigatório'});
      }
      final result = await conn.execute(
        Sql.named('''
          SELECT p.id_pedido,
                 e.nome AS empresa,
                 COALESCE(e.endereco, '') AS empresa_endereco,
                 sp.nome AS status,
                 p.id_status,
                 p.valor_total,
                 p.criado_em,
                 p.endereco_entrega,
                 COALESCE(p.observacao, '') AS observacao,
                 STRING_AGG(pr.nome, ', ' ORDER BY pr.nome) AS itens
          FROM pedidos p
          JOIN empresas e        ON e.id_empresa  = p.id_empresa
          JOIN status_pedidos sp ON sp.id_status  = p.id_status
          LEFT JOIN pedido_itens pitem ON pitem.id_pedido = p.id_pedido
          LEFT JOIN produtos pr        ON pr.id_produto   = pitem.id_produto
          WHERE p.id_motoboy = @id AND p.id_status = 3
          GROUP BY p.id_pedido, e.nome, e.endereco, sp.nome, p.id_status,
                   p.valor_total, p.criado_em, p.endereco_entrega, p.observacao
          ORDER BY p.criado_em DESC
        '''),
        parameters: {'id': idMotoboy},
      );
      final list = result.map((r) => {
        'id_pedido':         r[0],
        'empresa':           r[1]?.toString() ?? '',
        'empresa_endereco':  r[2]?.toString() ?? '',
        'status':            r[3]?.toString() ?? '',
        'id_status':         r[4],
        'valor_total':       r[5],
        'criado_em':         r[6]?.toString() ?? '',
        'endereco_entrega':  r[7]?.toString() ?? '',
        'observacao':        r[8]?.toString() ?? '',
        'itens':             r[9]?.toString() ?? '',
      }).toList();
      return _json(200, {'pedidos': list});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // PATCH /motoboy/meu-status
  // Body: { id_motoboy, status } — 'disponivel' | 'em_rota' | 'offline'
  // ----------------------------------------------------------------
  Future<Response> atualizarMeuStatus(Request request) async {
    try {
      final bodyStr = await request.readAsString();
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      final idMotoboy = _parseInt(body['id_motoboy']);
      final status    = body['status']?.toString();
      if (idMotoboy == null || status == null) {
        return _json(400, {'error': 'id_motoboy e status obrigatórios'});
      }
      await conn.execute(
        Sql.named('UPDATE usuarios SET status_motoboy = @novo_status WHERE id_usuario = @usuario_id'),
        parameters: {'novo_status': status, 'usuario_id': idMotoboy},
      );
      return _json(200, {'ok': true});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // GET /motoboy/minhas?id_motoboy=X
  // Entregas em andamento do motoboy (status 3 = A Caminho)
  // ----------------------------------------------------------------
  Future<Response> getMinhas(Request request) async {
    try {
      final idMotoboy =
          int.tryParse(request.url.queryParameters['id_motoboy'] ?? '');
      if (idMotoboy == null) {
        return _json(400, {'error': 'id_motoboy obrigatório'});
      }

      final result = await conn.execute(
        Sql.named('''
          SELECT p.id_pedido,
                 e.nome                                     AS empresa,
                 sp.nome                                    AS status,
                 p.id_status,
                 p.valor_total,
                 p.criado_em,
                 p.endereco_entrega,
                 COALESCE(p.observacao, '')                 AS observacao,
                 STRING_AGG(pr.nome, ', ' ORDER BY pr.nome) AS itens
          FROM pedidos p
          JOIN empresas e        ON e.id_empresa  = p.id_empresa
          JOIN status_pedidos sp ON sp.id_status  = p.id_status
          LEFT JOIN pedido_itens pitem ON pitem.id_pedido = p.id_pedido
          LEFT JOIN produtos pr        ON pr.id_produto   = pitem.id_produto
          WHERE p.id_motoboy = @id_motoboy
            AND p.id_status NOT IN (4, 5)
          GROUP BY p.id_pedido, e.nome, sp.nome, p.id_status,
                   p.valor_total, p.criado_em, p.endereco_entrega, p.observacao
          ORDER BY p.criado_em DESC
        '''),
        parameters: {'id_motoboy': idMotoboy},
      );

      final list = result.map((r) => {
        'id_pedido':        r[0],
        'empresa':          r[1]?.toString() ?? '',
        'status':           r[2]?.toString() ?? '',
        'id_status':        r[3],
        'valor_total':      r[4],
        'criado_em':        r[5]?.toString() ?? '',
        'endereco_entrega': r[6]?.toString() ?? '',
        'observacao':       r[7]?.toString() ?? '',
        'itens':            r[8]?.toString() ?? '',
      }).toList();

      return _json(200, {'pedidos': list});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // POST /motoboy/aceitar
  // Body: { id_pedido, id_motoboy }
  // Atribui o motoboy ao pedido e avança para status 3 (A Caminho)
  // ----------------------------------------------------------------
  Future<Response> aceitarEntrega(Request request) async {
    try {
      final bodyStr = await request.readAsString();
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;

      final idPedido  = _parseInt(body['id_pedido']);
      final idMotoboy = _parseInt(body['id_motoboy']);

      if (idPedido == null || idMotoboy == null) {
        return _json(400, {'error': 'id_pedido e id_motoboy obrigatórios'});
      }

      await conn.execute(
        Sql.named('''
          UPDATE pedidos
          SET id_motoboy = @id_motoboy, id_status = 3
          WHERE id_pedido = @id_pedido AND id_motoboy IS NULL
        '''),
        parameters: {'id_motoboy': idMotoboy, 'id_pedido': idPedido},
      );

      return _json(200, {'ok': true});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // PATCH /motoboy/status
  // Body: { id_pedido, id_status }
  // Motoboy avança o status da sua entrega (3→4 entregue, ou 5 cancelar)
  // ----------------------------------------------------------------
  Future<Response> atualizarStatus(Request request) async {
    try {
      final bodyStr = await request.readAsString();
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;

      final idPedido = _parseInt(body['id_pedido']);
      final idStatus = _parseInt(body['id_status']);

      if (idPedido == null || idStatus == null) {
        return _json(400, {'error': 'id_pedido e id_status obrigatórios'});
      }

      await conn.execute(
        Sql.named(
            'UPDATE pedidos SET id_status = @novo_status WHERE id_pedido = @pedido_id'),
        parameters: {'novo_status': idStatus, 'pedido_id': idPedido},
      );

      return _json(200, {'ok': true});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // GET /motoboy/historico?id_motoboy=X&inicio=YYYY-MM-DD&fim=YYYY-MM-DD
  // Entregas concluídas + total ganho (taxa fixa R$5 por entrega)
  // ----------------------------------------------------------------
  Future<Response> getHistorico(Request request) async {
    try {
      final idMotoboy =
          int.tryParse(request.url.queryParameters['id_motoboy'] ?? '');
      if (idMotoboy == null) {
        return _json(400, {'error': 'id_motoboy obrigatório'});
      }

      final inicio = request.url.queryParameters['inicio'];
      final fim    = request.url.queryParameters['fim'];
      final hasFilter = inicio != null &&
          inicio.isNotEmpty &&
          fim != null &&
          fim.isNotEmpty;

      final query = '''
        SELECT p.id_pedido,
               e.nome                                     AS empresa,
               sp.nome                                    AS status,
               p.valor_total,
               p.criado_em,
               p.endereco_entrega,
               STRING_AGG(pr.nome, ', ' ORDER BY pr.nome) AS itens
        FROM pedidos p
        JOIN empresas e        ON e.id_empresa  = p.id_empresa
        JOIN status_pedidos sp ON sp.id_status  = p.id_status
        LEFT JOIN pedido_itens pitem ON pitem.id_pedido = p.id_pedido
        LEFT JOIN produtos pr        ON pr.id_produto   = pitem.id_produto
        WHERE p.id_motoboy = @id_motoboy
          AND p.id_status = 4
          ${hasFilter ? 'AND p.criado_em >= @inicio::timestamp AND p.criado_em < (@fim::date + INTERVAL \'1 day\')' : ''}
        GROUP BY p.id_pedido, e.nome, sp.nome,
                 p.valor_total, p.criado_em, p.endereco_entrega
        ORDER BY p.criado_em DESC
      ''';

      final params = <String, dynamic>{'id_motoboy': idMotoboy};
      if (hasFilter) {
        params['inicio'] = inicio;
        params['fim']    = fim;
      }

      final result =
          await conn.execute(Sql.named(query), parameters: params);

      const taxaPorEntrega = 5.0;

      final list = result.map((r) => {
        'id_pedido':        r[0],
        'empresa':          r[1]?.toString() ?? '',
        'status':           r[2]?.toString() ?? '',
        'valor_total':      r[3],
        'criado_em':        r[4]?.toString() ?? '',
        'endereco_entrega': r[5]?.toString() ?? '',
        'itens':            r[6]?.toString() ?? '',
        'taxa':             taxaPorEntrega,
      }).toList();

      final totalEntregas = list.length;
      final totalGanho    = totalEntregas * taxaPorEntrega;

      return _json(200, {
        'pedidos':         list,
        'total_entregas':  totalEntregas,
        'total_ganho':     totalGanho,
        'taxa_por_entrega': taxaPorEntrega,
      });
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  Response _json(int status, Map<String, dynamic> body) {
    return Response(
      status,
      body: jsonEncode(body),
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}
