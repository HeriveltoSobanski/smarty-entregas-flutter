import 'dart:convert';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

class AvaliacaoController {
  final Connection conn;
  AvaliacaoController(this.conn);

  // ----------------------------------------------------------------
  // POST /avaliacoes
  // ----------------------------------------------------------------
  Future<Response> criar(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final idPedido    = _int(body['id_pedido']);
      final idUsuario   = _int(body['id_usuario']);
      final idEmpresa   = _int(body['id_empresa']);
      final notaEmpresa = _int(body['nota_empresa']);

      if (idPedido == null || idUsuario == null ||
          idEmpresa == null || notaEmpresa == null) {
        return _json(400, {'error': 'id_pedido, id_usuario, id_empresa e nota_empresa são obrigatórios'});
      }
      if (notaEmpresa < 1 || notaEmpresa > 5) {
        return _json(400, {'error': 'nota_empresa deve ser entre 1 e 5'});
      }

      final idMotoboy         = _int(body['id_motoboy']);
      final notaMotoboy       = _int(body['nota_motoboy']);
      final comentario        = body['comentario']?.toString().trim();
      final comentarioEntrega = body['comentario_entrega']?.toString().trim();

      // Critérios entregador
      final rapidez   = body['rapidez']   as bool?;
      final educacao  = body['educacao']  as bool?;
      final cuidado   = body['cuidado']   as bool?;
      // Critérios restaurante
      final sabor          = body['sabor']          as bool?;
      final embalagem      = body['embalagem']      as bool?;
      final pedidoCorreto  = body['pedido_correto'] as bool?;

      if (notaMotoboy != null && (notaMotoboy < 1 || notaMotoboy > 5)) {
        return _json(400, {'error': 'nota_motoboy deve ser entre 1 e 5'});
      }

      // Verifica duplicata
      final existe = await conn.execute(
        Sql.named('''
          SELECT id_avaliacao FROM avaliacoes
          WHERE id_pedido = @id_pedido AND id_usuario = @id_usuario
        '''),
        parameters: {'id_pedido': idPedido, 'id_usuario': idUsuario},
      );
      if (existe.isNotEmpty) {
        return _json(409, {'error': 'Você já avaliou este pedido.'});
      }

      await conn.execute(
        Sql.named('''
          INSERT INTO avaliacoes
            (id_pedido, id_usuario, id_empresa, id_motoboy,
             nota_empresa, nota_motoboy, comentario, comentario_entrega,
             rapidez, educacao, cuidado,
             sabor, embalagem, pedido_correto)
          VALUES
            (@id_pedido, @id_usuario, @id_empresa, @id_motoboy,
             @nota_empresa, @nota_motoboy, @comentario, @comentario_entrega,
             @rapidez, @educacao, @cuidado,
             @sabor, @embalagem, @pedido_correto)
        '''),
        parameters: {
          'id_pedido':          idPedido,
          'id_usuario':         idUsuario,
          'id_empresa':         idEmpresa,
          'id_motoboy':         idMotoboy,
          'nota_empresa':       notaEmpresa,
          'nota_motoboy':       notaMotoboy,
          'comentario':         comentario,
          'comentario_entrega': comentarioEntrega,
          'rapidez':            rapidez,
          'educacao':           educacao,
          'cuidado':            cuidado,
          'sabor':              sabor,
          'embalagem':          embalagem,
          'pedido_correto':     pedidoCorreto,
        },
      );

      return _json(201, {'ok': true});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // GET /pedidos/:id/avaliacao
  // ----------------------------------------------------------------
  Future<Response> verificar(Request request, String id) async {
    try {
      final idPedido  = int.tryParse(id);
      final idUsuario = int.tryParse(
          request.url.queryParameters['id_usuario'] ?? '');

      if (idPedido == null || idUsuario == null) {
        return _json(400, {'error': 'Parâmetros inválidos'});
      }

      final result = await conn.execute(
        Sql.named('''
          SELECT id_avaliacao, nota_empresa, nota_motoboy, comentario
          FROM avaliacoes
          WHERE id_pedido = @id_pedido AND id_usuario = @id_usuario
          LIMIT 1
        '''),
        parameters: {'id_pedido': idPedido, 'id_usuario': idUsuario},
      );

      if (result.isEmpty) return _json(200, {'avaliado': false});

      final r = result.first;
      return _json(200, {
        'avaliado':     true,
        'nota_empresa': r[1],
        'nota_motoboy': r[2],
        'comentario':   r[3]?.toString(),
      });
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // GET /empresas/:id/avaliacao
  // ----------------------------------------------------------------
  Future<Response> getEmpresa(Request request, String id) async {
    try {
      final idEmpresa = int.tryParse(id);
      if (idEmpresa == null) return _json(400, {'error': 'id inválido'});

      final result = await conn.execute(
        Sql.named('''
          SELECT
            ROUND(AVG(nota_empresa)::numeric, 1) AS media,
            COUNT(*)                              AS total
          FROM avaliacoes
          WHERE id_empresa = @id
        '''),
        parameters: {'id': idEmpresa},
      );

      final r     = result.first;
      final media = double.tryParse(r[0]?.toString() ?? '0') ?? 0.0;
      final total = r[1] is int ? r[1] as int
          : int.tryParse(r[1]?.toString() ?? '0') ?? 0;

      return _json(200, {'media': media, 'total': total});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  Response _json(int status, Map<String, dynamic> body) => Response(
        status,
        body: jsonEncode(body),
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
}
