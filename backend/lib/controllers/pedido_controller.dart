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
               STRING_AGG(pr.nome, ', ' ORDER BY pr.nome) AS itens
        FROM pedidos p
        JOIN usuarios u     ON u.id_usuario  = p.id_usuario
        JOIN status_pedidos sp ON sp.id_status = p.id_status
        LEFT JOIN pedido_itens pitem ON pitem.id_pedido  = p.id_pedido
        LEFT JOIN produtos pr       ON pr.id_produto     = pitem.id_produto
        WHERE p.id_empresa = @id_empresa
          ${hasFilter ? 'AND p.criado_em >= @inicio::timestamp AND p.criado_em < (@fim::date + INTERVAL \'1 day\')' : ''}
        GROUP BY p.id_pedido, u.nome, sp.nome, p.valor_total, p.criado_em
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
        'id_pedido':   r[0],
        'cliente':     r[1]?.toString() ?? '',
        'status':      r[2]?.toString() ?? '',
        'valor_total': r[3],
        'criado_em':   r[4]?.toString() ?? '',
        'itens':       r[5]?.toString() ?? '',
      }).toList();

      return _json(200, {'pedidos': list});
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
