import 'dart:convert';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import '../services/log_service.dart';

class PizzaController {
  final Pool conn;
  PizzaController(this.conn);

  // ----------------------------------------------------------------
  // GET /produtos/:id/pizza/sabores
  // ----------------------------------------------------------------
  Future<Response> getSabores(Request request, String id) async {
    try {
      final idProduto = int.tryParse(id);
      if (idProduto == null) return _json(400, {'error': 'id invalido'});

      final result = await conn.execute(
        Sql.named('''
          SELECT id_sabor, nome, descricao, preco, ativo
          FROM pizza_sabores
          WHERE id_produto = @id
          ORDER BY nome ASC
        '''),
        parameters: {'id': idProduto},
      );

      final list = result.map((r) => {
        'id_sabor':  r[0],
        'nome':      r[1]?.toString() ?? '',
        'descricao': r[2]?.toString() ?? '',
        'preco':     r[3] is num ? (r[3] as num).toDouble() : double.tryParse(r[3]?.toString() ?? '') ?? 0.0,
        'ativo':     r[4] as bool? ?? true,
      }).toList();

      return _json(200, {'sabores': list});
    } catch (e) {
      Log.error('Pizza', e); return _json(500, {'error': 'Erro interno do servidor'});
    }
  }

  // ----------------------------------------------------------------
  // POST /produtos/:id/pizza/sabores
  // Body: { nome, descricao?, preco }
  // ----------------------------------------------------------------
  Future<Response> createSabor(Request request, String id) async {
    try {
      final idProduto = int.tryParse(id);
      if (idProduto == null) return _json(400, {'error': 'id invalido'});

      final body = await request.readAsString();
      final data = body.isEmpty ? <String, dynamic>{} : jsonDecode(body) as Map<String, dynamic>;

      final nome      = data['nome']?.toString().trim() ?? '';
      final descricao = data['descricao']?.toString().trim() ?? '';
      final preco     = data['preco'] is num
          ? (data['preco'] as num).toDouble()
          : double.tryParse(data['preco']?.toString() ?? '') ?? 0.0;

      if (nome.isEmpty) return _json(400, {'error': 'nome e obrigatorio'});

      final result = await conn.execute(
        Sql.named('''
          INSERT INTO pizza_sabores (id_produto, nome, descricao, preco)
          VALUES (@id_produto, @nome, @descricao, @preco)
          RETURNING id_sabor
        '''),
        parameters: {
          'id_produto': idProduto,
          'nome':       nome,
          'descricao':  descricao,
          'preco':      preco,
        },
      );

      return _json(201, {'ok': true, 'id_sabor': result.first[0]});
    } catch (e) {
      Log.error('Pizza', e); return _json(500, {'error': 'Erro interno do servidor'});
    }
  }

  // ----------------------------------------------------------------
  // PATCH /pizza/sabores/:id
  // Body: { nome?, descricao?, preco?, ativo? }
  // ----------------------------------------------------------------
  Future<Response> updateSabor(Request request, String id) async {
    try {
      final idSabor = int.tryParse(id);
      if (idSabor == null) return _json(400, {'error': 'id invalido'});

      final body = await request.readAsString();
      final data = body.isEmpty ? <String, dynamic>{} : jsonDecode(body) as Map<String, dynamic>;

      final sets   = <String>[];
      final params = <String, dynamic>{'id': idSabor};

      if (data.containsKey('nome')) {
        sets.add('nome = @nome');
        params['nome'] = data['nome']?.toString().trim();
      }
      if (data.containsKey('descricao')) {
        sets.add('descricao = @descricao');
        params['descricao'] = data['descricao']?.toString().trim();
      }
      if (data.containsKey('preco')) {
        final preco = data['preco'] is num
            ? (data['preco'] as num).toDouble()
            : double.tryParse(data['preco']?.toString() ?? '') ?? 0.0;
        sets.add('preco = @preco');
        params['preco'] = preco;
      }
      if (data.containsKey('ativo')) {
        sets.add('ativo = @ativo');
        params['ativo'] = data['ativo'] as bool? ?? true;
      }

      if (sets.isEmpty) return _json(400, {'error': 'Nenhum campo para atualizar'});

      await conn.execute(
        Sql.named('UPDATE pizza_sabores SET ${sets.join(', ')} WHERE id_sabor = @id'),
        parameters: params,
      );

      return _json(200, {'ok': true});
    } catch (e) {
      Log.error('Pizza', e); return _json(500, {'error': 'Erro interno do servidor'});
    }
  }

  // ----------------------------------------------------------------
  // DELETE /pizza/sabores/:id
  // ----------------------------------------------------------------
  Future<Response> deleteSabor(Request request, String id) async {
    try {
      final idSabor = int.tryParse(id);
      if (idSabor == null) return _json(400, {'error': 'id invalido'});

      await conn.execute(
        Sql.named('DELETE FROM pizza_sabores WHERE id_sabor = @id'),
        parameters: {'id': idSabor},
      );

      return _json(200, {'ok': true});
    } catch (e) {
      Log.error('Pizza', e); return _json(500, {'error': 'Erro interno do servidor'});
    }
  }

  Response _json(int status, Map<String, dynamic> body) => Response(
        status,
        body: jsonEncode(body),
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
}
