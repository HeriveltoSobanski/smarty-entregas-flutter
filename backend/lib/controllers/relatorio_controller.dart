import 'dart:convert';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

class RelatorioController {
  final Pool conn;
  RelatorioController(this.conn);

  // GET /empresas/relatorio?inicio=YYYY-MM-DD&fim=YYYY-MM-DD
  Future<Response> getRelatorio(Request request) async {
    try {
      final idEmpresa = int.tryParse(request.context['idEmpresa']?.toString() ?? '');
      if (idEmpresa == null) return _json(403, {'error': 'Acesso negado'});

      final now = DateTime.now();
      final inicioParam = request.url.queryParameters['inicio'];
      final fimParam    = request.url.queryParameters['fim'];

      final inicio = (inicioParam != null && inicioParam.isNotEmpty)
          ? inicioParam
          : '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      final fim = (fimParam != null && fimParam.isNotEmpty)
          ? fimParam
          : '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Resumo geral (excluindo cancelados: id_status = 5)
      final resumoResult = await conn.execute(
        Sql.named("""
          SELECT
            COUNT(*) FILTER (WHERE id_status != 5)                      AS total_pedidos,
            COUNT(*) FILTER (WHERE id_status  = 5)                      AS pedidos_cancelados,
            COALESCE(SUM(total) FILTER (WHERE id_status != 5), 0) AS total_faturado,
            COALESCE(AVG(total) FILTER (WHERE id_status != 5), 0) AS ticket_medio
          FROM pedidos
          WHERE id_empresa = @id
            AND criado_em >= @inicio::date
            AND criado_em <  (@fim::date + INTERVAL '1 day')
        """),
        parameters: {'id': idEmpresa, 'inicio': inicio, 'fim': fim},
      );

      final r = resumoResult.isNotEmpty ? resumoResult.first : null;
      final resumo = {
        'total_pedidos':      r != null ? (r[0] as num?)?.toInt()    ?? 0   : 0,
        'pedidos_cancelados': r != null ? (r[1] as num?)?.toInt()    ?? 0   : 0,
        'total_faturado':     r != null ? (r[2] as num?)?.toDouble() ?? 0.0 : 0.0,
        'ticket_medio':       r != null ? (r[3] as num?)?.toDouble() ?? 0.0 : 0.0,
      };

      // Por forma de pagamento
      final pagResult = await conn.execute(
        Sql.named("""
          SELECT
            COALESCE(forma_pagamento, 'Não informado') AS forma,
            COUNT(*)                                   AS qtd,
            COALESCE(SUM(total), 0)              AS total
          FROM pedidos
          WHERE id_empresa = @id
            AND id_status != 5
            AND criado_em >= @inicio::date
            AND criado_em <  (@fim::date + INTERVAL '1 day')
          GROUP BY forma_pagamento
          ORDER BY total DESC
        """),
        parameters: {'id': idEmpresa, 'inicio': inicio, 'fim': fim},
      );

      final porPagamento = pagResult.map((row) => {
        'forma': row[0]?.toString() ?? 'Não informado',
        'qtd':   (row[1] as num?)?.toInt()    ?? 0,
        'total': (row[2] as num?)?.toDouble() ?? 0.0,
      }).toList();

      // Top 5 produtos mais vendidos
      final prodResult = await conn.execute(
        Sql.named("""
          SELECT
            pr.nome,
            SUM(pi.quantidade)                 AS qtd,
            SUM(pi.quantidade * pi.preco_unit) AS total
          FROM pedido_itens pi
          JOIN produtos pr ON pr.id_produto = pi.id_produto
          JOIN pedidos   p  ON p.id_pedido  = pi.id_pedido
          WHERE p.id_empresa = @id
            AND p.id_status  != 5
            AND p.criado_em  >= @inicio::date
            AND p.criado_em  <  (@fim::date + INTERVAL '1 day')
          GROUP BY pr.nome
          ORDER BY qtd DESC
          LIMIT 5
        """),
        parameters: {'id': idEmpresa, 'inicio': inicio, 'fim': fim},
      );

      final topProdutos = prodResult.map((row) => {
        'nome':  row[0]?.toString() ?? '',
        'qtd':   (row[1] as num?)?.toInt()    ?? 0,
        'total': (row[2] as num?)?.toDouble() ?? 0.0,
      }).toList();

      // Faturamento por dia (do mais recente ao mais antigo)
      final diaResult = await conn.execute(
        Sql.named("""
          SELECT
            DATE(criado_em)               AS dia,
            COUNT(*)                      AS pedidos,
            COALESCE(SUM(total), 0) AS total
          FROM pedidos
          WHERE id_empresa = @id
            AND id_status  != 5
            AND criado_em  >= @inicio::date
            AND criado_em  <  (@fim::date + INTERVAL '1 day')
          GROUP BY DATE(criado_em)
          ORDER BY dia DESC
        """),
        parameters: {'id': idEmpresa, 'inicio': inicio, 'fim': fim},
      );

      final porDia = diaResult.map((row) => {
        'dia':     row[0]?.toString().split(' ').first ?? '',
        'pedidos': (row[1] as num?)?.toInt()    ?? 0,
        'total':   (row[2] as num?)?.toDouble() ?? 0.0,
      }).toList();

      return _json(200, {
        'periodo':       {'inicio': inicio, 'fim': fim},
        'resumo':        resumo,
        'por_pagamento': porPagamento,
        'top_produtos':  topProdutos,
        'por_dia':       porDia,
      });
    } catch (e) {
      return _json(500, {'error': 'Erro ao gerar relatório: $e'});
    }
  }

  Response _json(int status, Map<String, dynamic> body) => Response(
        status,
        body: jsonEncode(body),
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
}
