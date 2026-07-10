import 'dart:convert';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import '../services/fcm_service.dart';

class NotificacaoController {
  final Pool conn;
  NotificacaoController(this.conn);

  // ----------------------------------------------------------------
  // GET /notificacoes?id_usuario=X
  // ----------------------------------------------------------------
  Future<Response> listar(Request request) async {
    try {
      final idUsuario = int.tryParse(request.context['userId']?.toString() ?? '');
      if (idUsuario == null) return _json(403, {'error': 'Acesso negado'});

      final result = await conn.execute(
        Sql.named('''
          SELECT id, titulo, corpo, tipo, lida, id_pedido,
                 criado_em
          FROM notificacoes
          WHERE id_usuario = @id_usuario
          ORDER BY criado_em DESC
          LIMIT 50
        '''),
        parameters: {'id_usuario': idUsuario},
      );

      final list = result.map((r) => {
        'id':        r[0],
        'titulo':    r[1]?.toString() ?? '',
        'corpo':     r[2]?.toString() ?? '',
        'tipo':      r[3]?.toString() ?? '',
        'lida':      r[4] as bool? ?? false,
        'id_pedido': r[5],
        'criado_em': r[6]?.toString() ?? '',
      }).toList();

      return _json(200, {'notificacoes': list});
    } catch (e) {
      print('Erro 500: $e'); return _json(500, {'error': 'Erro interno do servidor'});
    }
  }

  // ----------------------------------------------------------------
  // GET /notificacoes/nao-lidas?id_usuario=X
  // ----------------------------------------------------------------
  Future<Response> contarNaoLidas(Request request) async {
    try {
      final idUsuario = int.tryParse(request.context['userId']?.toString() ?? '');
      if (idUsuario == null) return _json(403, {'error': 'Acesso negado'});

      final result = await conn.execute(
        Sql.named('''
          SELECT COUNT(*) FROM notificacoes
          WHERE id_usuario = @id_usuario AND lida = false
        '''),
        parameters: {'id_usuario': idUsuario},
      );

      final count = result.first[0] is int
          ? result.first[0] as int
          : int.tryParse(result.first[0]?.toString() ?? '0') ?? 0;

      return _json(200, {'total': count});
    } catch (e) {
      print('Erro 500: $e'); return _json(500, {'error': 'Erro interno do servidor'});
    }
  }

  // ----------------------------------------------------------------
  // PATCH /notificacoes/:id/lida
  // ----------------------------------------------------------------
  Future<Response> marcarLida(Request request, String id) async {
    try {
      final idNotif = int.tryParse(id);
      if (idNotif == null) return _json(400, {'error': 'id inválido'});

      await conn.execute(
        Sql.named('UPDATE notificacoes SET lida = true WHERE id = @id'),
        parameters: {'id': idNotif},
      );
      return _json(200, {'ok': true});
    } catch (e) {
      print('Erro 500: $e'); return _json(500, {'error': 'Erro interno do servidor'});
    }
  }

  // ----------------------------------------------------------------
  // PATCH /notificacoes/todas-lidas?id_usuario=X
  // ----------------------------------------------------------------
  Future<Response> marcarTodasLidas(Request request) async {
    try {
      final idUsuario = int.tryParse(request.context['userId']?.toString() ?? '');
      if (idUsuario == null) return _json(403, {'error': 'Acesso negado'});

      await conn.execute(
        Sql.named('''
          UPDATE notificacoes SET lida = true
          WHERE id_usuario = @id_usuario AND lida = false
        '''),
        parameters: {'id_usuario': idUsuario},
      );
      return _json(200, {'ok': true});
    } catch (e) {
      print('Erro 500: $e'); return _json(500, {'error': 'Erro interno do servidor'});
    }
  }

  // ----------------------------------------------------------------
  // Helper estático reutilizado pelos outros controllers
  // ----------------------------------------------------------------
  static Future<void> criar({
    required Pool conn,
    required int    idUsuario,
    required String titulo,
    required String corpo,
    String          tipo     = 'status_pedido',
    int?            idPedido,
    FcmService?     fcmService,
  }) async {
    try {
      await conn.execute(
        Sql.named('''
          INSERT INTO notificacoes (id_usuario, titulo, corpo, tipo, id_pedido)
          VALUES (@id_usuario, @titulo, @corpo, @tipo, @id_pedido)
        '''),
        parameters: {
          'id_usuario': idUsuario,
          'titulo':     titulo,
          'corpo':      corpo,
          'tipo':       tipo,
          'id_pedido':  idPedido,
        },
      );
    } catch (_) {
      // Notificação não pode derrubar a operação principal
    }

    // Envia push independentemente do resultado do INSERT
    await fcmService?.enviarParaUsuario(
      conn:      conn,
      idUsuario: idUsuario,
      titulo:    titulo,
      corpo:     corpo,
      data:      idPedido != null ? {'id_pedido': idPedido.toString()} : null,
    );
  }

  Response _json(int status, Map<String, dynamic> body) => Response(
        status,
        body: jsonEncode(body),
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
}
