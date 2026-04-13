import 'dart:convert';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

/// Gerencia motoboys vinculados a uma empresa específica.
/// Tabela: empresa_motoboys (id, id_empresa, id_usuario, ativo)
class EmpresaMotoboyController {
  final Connection conn;
  EmpresaMotoboyController(this.conn);

  // GET /motoboys/buscar?id=X
  // Retorna dados de um motoboy pelo id_usuario (para o modal de cadastro)
  Future<Response> buscarPorId(Request request) async {
    try {
      final id = int.tryParse(request.url.queryParameters['id'] ?? '');
      if (id == null) return _json(400, {'error': 'id obrigatório'});

      final result = await conn.execute(
        Sql.named('''
          SELECT id_usuario, nome, telefone
          FROM usuarios
          WHERE id_usuario = @id AND tipo_usuario = 'motoboy'
          LIMIT 1
        '''),
        parameters: {'id': id},
      );

      if (result.isEmpty) {
        return _json(404, {'error': 'Motoboy não encontrado'});
      }
      final r = result.first;
      return _json(200, {
        'id':       r[0],
        'nome':     r[1]?.toString() ?? '',
        'telefone': r[2]?.toString() ?? '',
      });
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // GET /empresas/:id/motoboys
  Future<Response> listar(Request request, String id) async {
    try {
      final idEmpresa = int.tryParse(id);
      if (idEmpresa == null) return _json(400, {'error': 'id inválido'});

      final result = await conn.execute(
        Sql.named('''
          SELECT em.id_motoboy_empresa,
                 COALESCE(u.nome,     em.nome)     AS nome,
                 COALESCE(u.telefone, em.telefone) AS telefone,
                 em.ativo,
                 em.id_usuario,
                 COALESCE(u.status_motoboy, 'offline') AS status_motoboy
          FROM empresa_motoboys em
          LEFT JOIN usuarios u ON u.id_usuario = em.id_usuario
          WHERE em.id_empresa = @id
          ORDER BY COALESCE(u.nome, em.nome) ASC
        '''),
        parameters: {'id': idEmpresa},
      );

      final lista = result.map((r) => {
        'id':             r[0],
        'nome':           r[1]?.toString() ?? '',
        'telefone':       r[2]?.toString() ?? '',
        'ativo':          r[3] as bool? ?? true,
        'id_usuario':     r[4],
        'status_motoboy': r[5]?.toString() ?? 'offline',
      }).toList();

      return _json(200, {'motoboys': lista});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // POST /empresas/:id/motoboys — { id_usuario: X }
  Future<Response> criar(Request request, String id) async {
    try {
      final idEmpresa = int.tryParse(id);
      if (idEmpresa == null) return _json(400, {'error': 'id inválido'});

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final idUsuario = body['id_usuario'] is int
          ? body['id_usuario'] as int
          : int.tryParse(body['id_usuario']?.toString() ?? '');

      if (idUsuario == null) return _json(400, {'error': 'id_usuario é obrigatório'});

      // Verifica se é motoboy válido
      final check = await conn.execute(
        Sql.named('''
          SELECT id_usuario FROM usuarios
          WHERE id_usuario = @id AND tipo_usuario = 'motoboy'
        '''),
        parameters: {'id': idUsuario},
      );
      if (check.isEmpty) return _json(404, {'error': 'Motoboy não encontrado. Verifique o ID.'});

      // Verifica se já está na equipe
      final already = await conn.execute(
        Sql.named('''
          SELECT id_motoboy_empresa FROM empresa_motoboys
          WHERE id_empresa = @emp AND id_usuario = @usr
        '''),
        parameters: {'emp': idEmpresa, 'usr': idUsuario},
      );
      if (already.isNotEmpty) return _json(409, {'error': 'Este motoboy já está na sua equipe.'});

      final result = await conn.execute(
        Sql.named('''
          INSERT INTO empresa_motoboys (id_empresa, id_usuario)
          VALUES (@id_empresa, @id_usuario)
          RETURNING id_motoboy_empresa
        '''),
        parameters: {'id_empresa': idEmpresa, 'id_usuario': idUsuario},
      );

      return _json(201, {'ok': true, 'id': result.first[0]});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // DELETE /empresas/motoboys/:id
  Future<Response> deletar(Request request, String id) async {
    try {
      final idMotoboy = int.tryParse(id);
      if (idMotoboy == null) return _json(400, {'error': 'id inválido'});

      await conn.execute(
        Sql.named('DELETE FROM empresa_motoboys WHERE id_motoboy_empresa = @id'),
        parameters: {'id': idMotoboy},
      );
      return _json(200, {'ok': true});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // PATCH /pedidos/:id/entrega-propria-motoboy — { id_motoboy_empresa }
  // Vincula motoboy da empresa ao pedido via id_motoboy real e avança para status 3
  Future<Response> atribuirMotoboy(Request request, String idPedido) async {
    try {
      final pedidoId = int.tryParse(idPedido);
      if (pedidoId == null) return _json(400, {'error': 'id inválido'});

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final idMotoboyEmpresa = body['id_motoboy_empresa'] is int
          ? body['id_motoboy_empresa'] as int
          : int.tryParse(body['id_motoboy_empresa']?.toString() ?? '');

      if (idMotoboyEmpresa == null) {
        return _json(400, {'error': 'id_motoboy_empresa obrigatório'});
      }

      // Busca o id_usuario real do motoboy
      final motoboyResult = await conn.execute(
        Sql.named('''
          SELECT em.id_usuario, u.nome, u.telefone
          FROM empresa_motoboys em
          JOIN usuarios u ON u.id_usuario = em.id_usuario
          WHERE em.id_motoboy_empresa = @id
        '''),
        parameters: {'id': idMotoboyEmpresa},
      );
      if (motoboyResult.isEmpty) return _json(404, {'error': 'Motoboy não encontrado'});

      final idUsuario = motoboyResult.first[0] as int;
      final nome      = motoboyResult.first[1]?.toString() ?? '';
      final telefone  = motoboyResult.first[2]?.toString() ?? '';

      // Atualiza pedido: tipo_entrega='propria', status=3, id_motoboy = id real
      await conn.execute(
        Sql.named('''
          UPDATE pedidos
          SET tipo_entrega = 'propria',
              id_status    = 3,
              id_motoboy   = @id_motoboy
          WHERE id_pedido = @pedido_id
        '''),
        parameters: {'pedido_id': pedidoId, 'id_motoboy': idUsuario},
      );

      return _json(200, {'ok': true, 'motoboy_nome': nome, 'motoboy_telefone': telefone});
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
