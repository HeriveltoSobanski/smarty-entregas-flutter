import 'dart:convert';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

class ClienteEnderecoController {
  final Connection conn;
  ClienteEnderecoController(this.conn);

  // ----------------------------------------------------------------
  // GET /clientes/:id/enderecos
  // Lista todos os endereços do cliente
  // ----------------------------------------------------------------
  Future<Response> listar(Request request, String id) async {
    try {
      final idUsuario = int.tryParse(id);
      if (idUsuario == null) return _json(400, {'error': 'id inválido'});

      final result = await conn.execute(
        Sql.named('''
          SELECT id_endereco, apelido, endereco, latitude, longitude, principal
          FROM usuario_enderecos
          WHERE id_usuario = @id
          ORDER BY principal DESC, id_endereco ASC
        '''),
        parameters: {'id': idUsuario},
      );

      final list = result.map((r) => {
        'id_endereco': r[0],
        'apelido':     r[1]?.toString() ?? '',
        'endereco':    r[2]?.toString() ?? '',
        'latitude':    r[3],
        'longitude':   r[4],
        'principal':   r[5] as bool? ?? false,
      }).toList();

      return _json(200, {'enderecos': list});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // POST /clientes/:id/enderecos
  // Body: { apelido, endereco, latitude, longitude }
  // ----------------------------------------------------------------
  Future<Response> criar(Request request, String id) async {
    try {
      final idUsuario = int.tryParse(id);
      if (idUsuario == null) return _json(400, {'error': 'id inválido'});

      final bodyStr = await request.readAsString();
      final data = bodyStr.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(bodyStr) as Map<String, dynamic>;

      final apelido  = (data['apelido'] ?? '').toString().trim();
      final endereco = (data['endereco'] ?? '').toString().trim();
      final latitude  = data['latitude']  is num ? (data['latitude']  as num).toDouble() : null;
      final longitude = data['longitude'] is num ? (data['longitude'] as num).toDouble() : null;

      if (endereco.isEmpty) {
        return _json(400, {'error': 'endereco é obrigatório'});
      }

      // Se for o primeiro endereço, já marca como principal
      final countResult = await conn.execute(
        Sql.named('SELECT COUNT(*) FROM usuario_enderecos WHERE id_usuario = @id'),
        parameters: {'id': idUsuario},
      );
      final isPrincipal = (countResult.first[0] as num?)?.toInt() == 0;

      final result = await conn.execute(
        Sql.named('''
          INSERT INTO usuario_enderecos (id_usuario, apelido, endereco, latitude, longitude, principal)
          VALUES (@id_usuario, @apelido, @endereco, @lat, @lng, @principal)
          RETURNING id_endereco
        '''),
        parameters: {
          'id_usuario': idUsuario,
          'apelido':    apelido.isEmpty ? 'Casa' : apelido,
          'endereco':   endereco,
          'lat':        latitude,
          'lng':        longitude,
          'principal':  isPrincipal,
        },
      );

      return _json(201, {'ok': true, 'id_endereco': result.first[0], 'principal': isPrincipal});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // DELETE /clientes/enderecos/:id
  // ----------------------------------------------------------------
  Future<Response> deletar(Request request, String id) async {
    try {
      final idEndereco = int.tryParse(id);
      if (idEndereco == null) return _json(400, {'error': 'id inválido'});

      // Se era o principal, promove o próximo
      final check = await conn.execute(
        Sql.named('SELECT id_usuario, principal FROM usuario_enderecos WHERE id_endereco = @id'),
        parameters: {'id': idEndereco},
      );
      if (check.isEmpty) return _json(404, {'error': 'Endereço não encontrado'});

      final idUsuario  = check.first[0] as int;
      final eraPrincipal = check.first[1] as bool? ?? false;

      await conn.execute(
        Sql.named('DELETE FROM usuario_enderecos WHERE id_endereco = @id'),
        parameters: {'id': idEndereco},
      );

      // Promove outro como principal se necessário
      if (eraPrincipal) {
        await conn.execute(
          Sql.named('''
            UPDATE usuario_enderecos SET principal = true
            WHERE id_endereco = (
              SELECT id_endereco FROM usuario_enderecos
              WHERE id_usuario = @id_usuario
              ORDER BY id_endereco ASC LIMIT 1
            )
          '''),
          parameters: {'id_usuario': idUsuario},
        );
      }

      return _json(200, {'ok': true});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // PATCH /clientes/enderecos/:id/principal
  // Marca o endereço como principal (desmarca os outros do mesmo usuário)
  // ----------------------------------------------------------------
  Future<Response> marcarPrincipal(Request request, String id) async {
    try {
      final idEndereco = int.tryParse(id);
      if (idEndereco == null) return _json(400, {'error': 'id inválido'});

      final check = await conn.execute(
        Sql.named('SELECT id_usuario FROM usuario_enderecos WHERE id_endereco = @id'),
        parameters: {'id': idEndereco},
      );
      if (check.isEmpty) return _json(404, {'error': 'Endereço não encontrado'});

      final idUsuario = check.first[0] as int;

      // Desmarca todos
      await conn.execute(
        Sql.named('UPDATE usuario_enderecos SET principal = false WHERE id_usuario = @uid'),
        parameters: {'uid': idUsuario},
      );
      // Marca o escolhido
      await conn.execute(
        Sql.named('UPDATE usuario_enderecos SET principal = true WHERE id_endereco = @id'),
        parameters: {'id': idEndereco},
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
