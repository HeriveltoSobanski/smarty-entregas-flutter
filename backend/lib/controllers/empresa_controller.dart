import 'dart:convert';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

class EmpresaController {
  final Connection conn;
  EmpresaController(this.conn);

  // ----------------------------------------------------------------
  // PATCH /empresas/:id/foto
  // Body: { foto_perfil: "data:image/jpeg;base64,..." }
  // ----------------------------------------------------------------
  Future<Response> atualizarFoto(Request request, String id) async {
    try {
      final idEmpresa = int.tryParse(id);
      if (idEmpresa == null) return _json(400, {'error': 'id inválido'});

      final body = await request.readAsString();
      final data = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;

      final foto = data['foto_perfil']?.toString();
      if (foto == null || foto.isEmpty) {
        return _json(400, {'error': 'foto_perfil é obrigatório'});
      }

      await conn.execute(
        Sql.named('''
          UPDATE empresas
          SET foto_perfil = @foto
          WHERE id_empresa = @id
        '''),
        parameters: {'foto': foto, 'id': idEmpresa},
      );

      return _json(200, {'ok': true});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // GET /empresas/:id/foto
  // ----------------------------------------------------------------
  Future<Response> getFoto(Request request, String id) async {
    try {
      final idEmpresa = int.tryParse(id);
      if (idEmpresa == null) return _json(400, {'error': 'id inválido'});

      final result = await conn.execute(
        Sql.named('SELECT foto_perfil FROM empresas WHERE id_empresa = @id'),
        parameters: {'id': idEmpresa},
      );

      if (result.isEmpty) return _json(404, {'error': 'Empresa não encontrada'});

      return _json(200, {'foto_perfil': result.first[0]?.toString()});
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
