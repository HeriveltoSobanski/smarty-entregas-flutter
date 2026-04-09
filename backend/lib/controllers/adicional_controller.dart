import 'dart:convert';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

class AdicionalController {
  final Connection conn;
  AdicionalController(this.conn);

  // ----------------------------------------------------------------
  // GET /produtos/:id/adicionais
  // ----------------------------------------------------------------
  Future<Response> getAdicionais(Request request, String id) async {
    try {
      final idProduto = int.tryParse(id);
      if (idProduto == null) return _json(400, {'error': 'id inválido'});

      final result = await conn.execute(
        Sql.named('''
          SELECT id_adicional, grupo, maximo_grupo, obrigatorio,
                 nome, descricao, preco
          FROM produto_adicionais
          WHERE id_produto = @id AND ativo = true
          ORDER BY grupo, id_adicional
        '''),
        parameters: {'id': idProduto},
      );

      // Agrupa por grupo
      final Map<String, Map<String, dynamic>> grupoMap = {};
      for (final r in result) {
        final grupo = r[1]?.toString() ?? 'Adicionais';
        grupoMap.putIfAbsent(grupo, () => {
          'grupo':       grupo,
          'maximo_grupo': r[2],
          'obrigatorio': r[3],
          'itens':       <Map<String, dynamic>>[],
        });
        (grupoMap[grupo]!['itens'] as List).add({
          'id_adicional': r[0],
          'nome':         r[4]?.toString() ?? '',
          'descricao':    r[5]?.toString() ?? '',
          'preco':        r[6],
        });
      }

      return _json(200, {'grupos': grupoMap.values.toList()});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // POST /produtos/:id/adicionais
  // Body: { grupo, maximo_grupo, obrigatorio, nome, descricao, preco }
  // ----------------------------------------------------------------
  Future<Response> createAdicional(Request request, String id) async {
    try {
      final idProduto = int.tryParse(id);
      if (idProduto == null) return _json(400, {'error': 'id inválido'});

      final body = await request.readAsString();
      final data = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;

      final grupo       = (data['grupo'] ?? 'Adicionais').toString().trim();
      final maximoGrupo = data['maximo_grupo'] is int
          ? data['maximo_grupo'] as int
          : int.tryParse(data['maximo_grupo']?.toString() ?? '3') ?? 3;
      final obrigatorio = data['obrigatorio'] == true;
      final nome        = (data['nome'] ?? '').toString().trim();
      final descricao   = (data['descricao'] ?? '').toString().trim();
      final preco       = data['preco'] is num
          ? (data['preco'] as num).toDouble()
          : double.tryParse(
                  data['preco']?.toString().replaceAll(',', '.') ?? '0') ??
              0.0;

      if (nome.isEmpty) {
        return _json(400, {'error': 'nome é obrigatório'});
      }

      final result = await conn.execute(
        Sql.named('''
          INSERT INTO produto_adicionais
            (id_produto, grupo, maximo_grupo, obrigatorio, nome, descricao, preco, ativo)
          VALUES
            (@id_produto, @grupo, @maximo_grupo, @obrigatorio, @nome, @descricao, @preco, true)
          RETURNING id_adicional
        '''),
        parameters: {
          'id_produto':   idProduto,
          'grupo':        grupo,
          'maximo_grupo': maximoGrupo,
          'obrigatorio':  obrigatorio,
          'nome':         nome,
          'descricao':    descricao,
          'preco':        preco,
        },
      );

      return _json(201, {'ok': true, 'id_adicional': result.first[0]});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // DELETE /adicionais/:id
  // ----------------------------------------------------------------
  Future<Response> deleteAdicional(Request request, String id) async {
    try {
      final idAdicional = int.tryParse(id);
      if (idAdicional == null) return _json(400, {'error': 'id inválido'});

      await conn.execute(
        Sql.named('DELETE FROM produto_adicionais WHERE id_adicional = @id'),
        parameters: {'id': idAdicional},
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
