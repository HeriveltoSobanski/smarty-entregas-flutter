import 'dart:convert';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

class DispositivoController {
  final Connection conn;
  DispositivoController(this.conn);

  // POST /dispositivos/fcm-token
  // Body: { id_usuario, fcm_token, plataforma }
  Future<Response> registrarFcmToken(Request request) async {
    try {
      final body      = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final idUsuario = body['id_usuario'] is int
          ? body['id_usuario'] as int
          : int.tryParse(body['id_usuario']?.toString() ?? '');
      final token     = body['fcm_token']?.toString() ?? '';
      final plataforma = body['plataforma']?.toString() ?? 'android';

      if (idUsuario == null || token.isEmpty) {
        return _json(400, {'error': 'id_usuario e fcm_token são obrigatórios'});
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
      return _json(500, {'error': e.toString()});
    }
  }

  Response _json(int status, Map<String, dynamic> body) => Response(
        status,
        body: jsonEncode(body),
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
}
