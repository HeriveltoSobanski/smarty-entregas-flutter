import 'dart:convert';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import '../services/log_service.dart';

class DispositivoController {
  final Pool conn;
  DispositivoController(this.conn);

  // POST /dispositivos/fcm-token
  // Body: { fcm_token, plataforma }
  Future<Response> registrarFcmToken(Request request) async {
    try {
      final ctxId     = request.context['userId'];
      final idUsuario = ctxId is int ? ctxId : int.tryParse(ctxId?.toString() ?? '');
      if (idUsuario == null) {
        return _json(401, {'error': 'Não autenticado'});
      }

      final body       = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final token      = body['fcm_token']?.toString() ?? '';
      final plataforma = body['plataforma']?.toString() ?? 'android';

      if (token.isEmpty) {
        return _json(400, {'error': 'fcm_token é obrigatório'});
      }

      // Upsert: mesmo token → atualiza usuário e timestamp
      await conn.execute(
        Sql.named('''
          INSERT INTO dispositivos_fcm (id_usuario, fcm_token, plataforma)
          VALUES (@id_usuario, @token, @plataforma)
          ON CONFLICT (fcm_token)
          DO UPDATE SET
            id_usuario   = EXCLUDED.id_usuario,
            plataforma   = EXCLUDED.plataforma,
            atualizado_em = NOW()
        '''),
        parameters: {
          'id_usuario':  idUsuario,
          'token':       token,
          'plataforma':  plataforma,
        },
      );

      return _json(200, {'ok': true});
    } catch (e) {
      Log.error('Dispositivo', e); return _json(500, {'error': 'Erro interno do servidor'});
    }
  }

  Response _json(int status, Map<String, dynamic> body) => Response(
        status,
        body: jsonEncode(body),
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
}
