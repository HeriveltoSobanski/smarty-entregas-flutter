import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

class ProdutoController {
  final Connection conn;

  ProdutoController(this.conn);

  // ----------------------------------------------------------------
  // GET /produtos/categorias
  // ----------------------------------------------------------------
  Future<Response> getCategorias(Request request) async {
    try {
      await conn.execute(
        Sql.named('''
          INSERT INTO categorias (nome)
          VALUES ('Lanches'),('Almoços'),('Sobremesas'),('Pizzas'),('Bebidas')
          ON CONFLICT (nome) DO NOTHING
        '''),
        parameters: {},
      );

      final result = await conn.execute(
        Sql.named('SELECT id_categoria, nome FROM categorias ORDER BY nome'),
        parameters: {},
      );

      final list = result
          .map((r) => {'id_categoria': r[0], 'nome': r[1]?.toString()})
          .toList();

      return _json(200, {'categorias': list});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // GET /produtos/empresa?id_empresa=X
  // Lista todos os produtos da empresa (ativo e inativo)
  // ----------------------------------------------------------------
  Future<Response> getProdutosByEmpresa(Request request) async {
    try {
      final idEmpresa =
          int.tryParse(request.url.queryParameters['id_empresa'] ?? '');
      if (idEmpresa == null) {
        return _json(400, {'error': 'id_empresa obrigatório'});
      }

      final result = await conn.execute(
        Sql.named('''
          SELECT p.id_produto, p.nome, p.descricao, p.preco, p.ativo,
                 c.nome AS categoria_nome, p.id_categoria,
                 p.criado_em, p.imagem
          FROM produtos p
          LEFT JOIN categorias c ON c.id_categoria = p.id_categoria
          WHERE p.id_empresa = @id_empresa
          ORDER BY p.criado_em DESC
        '''),
        parameters: {'id_empresa': idEmpresa},
      );

      final list = result.map((r) => {
        'id_produto':     r[0],
        'nome':           r[1]?.toString(),
        'descricao':      r[2]?.toString() ?? '',
        'preco':          r[3],
        'ativo':          r[4],
        'categoria_nome': r[5]?.toString() ?? '',
        'id_categoria':   r[6],
        'criado_em':      r[7]?.toString(),
        'imagem':         r[8]?.toString(),
      }).toList();

      return _json(200, {'produtos': list});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // GET /produtos/publico?categoria=Lanches
  // Lista produtos ativos públicos, opcionalmente filtrado por categoria
  // ----------------------------------------------------------------
  Future<Response> getProdutosPublico(Request request) async {
    try {
      final categoria = request.url.queryParameters['categoria'];

      final query = categoria != null && categoria.isNotEmpty
          ? '''
            SELECT p.id_produto, p.nome, p.descricao, p.preco,
                   c.nome AS categoria_nome, u.nome AS empresa_nome
            FROM produtos p
            JOIN categorias c ON c.id_categoria = p.id_categoria
            JOIN empresas e   ON e.id_empresa   = p.id_empresa
            JOIN usuarios u   ON u.id_usuario   = e.id_usuario
            WHERE p.ativo = true
              AND LOWER(c.nome) = LOWER(@categoria)
            ORDER BY p.preco ASC
          '''
          : '''
            SELECT p.id_produto, p.nome, p.descricao, p.preco,
                   c.nome AS categoria_nome, u.nome AS empresa_nome
            FROM produtos p
            LEFT JOIN categorias c ON c.id_categoria = p.id_categoria
            JOIN empresas e        ON e.id_empresa   = p.id_empresa
            JOIN usuarios u        ON u.id_usuario   = e.id_usuario
            WHERE p.ativo = true
            ORDER BY p.preco ASC
          ''';

      final params = categoria != null && categoria.isNotEmpty
          ? {'categoria': categoria}
          : <String, dynamic>{};

      final result = await conn.execute(Sql.named(query), parameters: params);

      final list = result.map((r) => {
        'id_produto':     r[0],
        'nome':           r[1]?.toString(),
        'descricao':      r[2]?.toString() ?? '',
        'preco':          r[3],
        'categoria_nome': r[4]?.toString() ?? '',
        'empresa_nome':   r[5]?.toString() ?? '',
      }).toList();

      return _json(200, {'produtos': list});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // POST /produtos
  // ----------------------------------------------------------------
  Future<Response> createProduto(Request request) async {
    try {
      final body = await request.readAsString();
      final data = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;

      final idEmpresa   = data['id_empresa'] is int
          ? data['id_empresa'] as int
          : int.tryParse(data['id_empresa']?.toString() ?? '');
      final idCategoria = data['id_categoria'] is int
          ? data['id_categoria'] as int
          : int.tryParse(data['id_categoria']?.toString() ?? '');
      final nome      = (data['nome'] ?? '').toString().trim();
      final descricao = (data['descricao'] ?? '').toString().trim();
      final preco     = data['preco'] is num
          ? (data['preco'] as num).toDouble()
          : double.tryParse(
                  data['preco']?.toString().replaceAll(',', '.') ?? '0') ??
              0.0;
      final imagem    = data['imagem']?.toString();

      if (idEmpresa == null || idCategoria == null ||
          nome.isEmpty || preco <= 0) {
        return _json(400, {
          'error': 'id_empresa, id_categoria, nome e preco são obrigatórios'
        });
      }

      final result = await conn.execute(
        Sql.named('''
          INSERT INTO produtos
            (id_empresa, id_categoria, nome, descricao, preco, imagem, ativo, criado_em, atualizado_em)
          VALUES
            (@id_empresa, @id_categoria, @nome, @descricao, @preco, @imagem, true, now(), now())
          RETURNING id_produto
        '''),
        parameters: {
          'id_empresa':   idEmpresa,
          'id_categoria': idCategoria,
          'nome':         nome,
          'descricao':    descricao,
          'preco':        preco,
          'imagem':       imagem,
        },
      );

      return _json(201, {'ok': true, 'id_produto': result.first[0]});
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('uq_produtos_empresa_nome')) {
        return _json(409, {'error': 'Já existe um produto com este nome nesta empresa'});
      }
      return _json(500, {'error': 'Erro ao criar produto', 'details': msg});
    }
  }

  // ----------------------------------------------------------------
  // DELETE /produtos/:id
  // ----------------------------------------------------------------
  Future<Response> deleteProduto(Request request, String id) async {
    try {
      final idProduto = int.tryParse(id);
      if (idProduto == null) return _json(400, {'error': 'id inválido'});

      await conn.execute(
        Sql.named('DELETE FROM produtos WHERE id_produto = @id'),
        parameters: {'id': idProduto},
      );

      return _json(200, {'ok': true});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // PATCH /produtos/:id/ativo
  // ----------------------------------------------------------------
  Future<Response> toggleAtivo(Request request, String id) async {
    try {
      final idProduto = int.tryParse(id);
      if (idProduto == null) return _json(400, {'error': 'id inválido'});

      await conn.execute(
        Sql.named('''
          UPDATE produtos
          SET ativo = NOT ativo, atualizado_em = now()
          WHERE id_produto = @id
        '''),
        parameters: {'id': idProduto},
      );

      return _json(200, {'ok': true});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // GET /produtos/empresas?categoria=X
  // Retorna empresas agrupadas com seus produtos ativos
  // ----------------------------------------------------------------
  Future<Response> getEmpresasComProdutos(Request request) async {
    try {
      final categoria = request.url.queryParameters['categoria'];

      final query = categoria != null && categoria.isNotEmpty
          ? '''
            SELECT e.id_empresa, u.nome AS empresa_nome,
                   p.id_produto, p.nome AS produto_nome, p.descricao,
                   p.preco, c.nome AS categoria_nome, p.imagem,
                   e.foto_perfil
            FROM empresas e
            JOIN usuarios u   ON u.id_usuario   = e.id_usuario
            JOIN produtos p   ON p.id_empresa   = e.id_empresa
            JOIN categorias c ON c.id_categoria = p.id_categoria
            WHERE p.ativo = true
              AND LOWER(c.nome) = LOWER(@categoria)
            ORDER BY e.id_empresa, p.preco ASC
          '''
          : '''
            SELECT e.id_empresa, u.nome AS empresa_nome,
                   p.id_produto, p.nome AS produto_nome, p.descricao,
                   p.preco, c.nome AS categoria_nome, p.imagem,
                   e.foto_perfil
            FROM empresas e
            JOIN usuarios u   ON u.id_usuario   = e.id_usuario
            JOIN produtos p   ON p.id_empresa   = e.id_empresa
            JOIN categorias c ON c.id_categoria = p.id_categoria
            WHERE p.ativo = true
            ORDER BY e.id_empresa, p.preco ASC
          ''';

      final params = categoria != null && categoria.isNotEmpty
          ? {'categoria': categoria}
          : <String, dynamic>{};

      final result = await conn.execute(Sql.named(query), parameters: params);

      // Agrupa produtos por empresa
      final Map<int, Map<String, dynamic>> empresaMap = {};
      for (final r in result) {
        final idEmpresa   = r[0] as int;
        final empresaNome = r[1]?.toString() ?? '';
        final idProduto   = r[2];
        final produtoNome = r[3]?.toString() ?? '';
        final descricao   = r[4]?.toString() ?? '';
        final preco       = r[5];
        final catNome     = r[6]?.toString() ?? '';
        final imagem      = r[7]?.toString();
        final fotoPerfil  = r[8]?.toString();

        empresaMap.putIfAbsent(idEmpresa, () => {
          'id_empresa':   idEmpresa,
          'nome':         empresaNome,
          'foto_perfil':  fotoPerfil,
          'produtos':     <Map<String, dynamic>>[],
        });

        (empresaMap[idEmpresa]!['produtos'] as List).add({
          'id_produto':     idProduto,
          'nome':           produtoNome,
          'descricao':      descricao,
          'preco':          preco,
          'categoria_nome': catNome,
          'imagem':         imagem,
        });
      }

      return _json(200, {'empresas': empresaMap.values.toList()});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  // ----------------------------------------------------------------
  // GET /produtos/busca?q=<termo>
  // Busca produtos ativos por nome do produto ou nome da empresa
  // ----------------------------------------------------------------
  Future<Response> buscarProdutos(Request request) async {
    try {
      final q = (request.url.queryParameters['q'] ?? '').trim();
      if (q.isEmpty) {
        return _json(400, {'error': 'Parâmetro q obrigatório'});
      }

      final result = await conn.execute(
        Sql.named('''
          SELECT e.id_empresa, u.nome AS empresa_nome,
                 p.id_produto, p.nome AS produto_nome, p.descricao,
                 p.preco, c.nome AS categoria_nome, p.imagem,
                 e.foto_perfil
          FROM empresas e
          JOIN usuarios u   ON u.id_usuario   = e.id_usuario
          JOIN produtos p   ON p.id_empresa   = e.id_empresa
          LEFT JOIN categorias c ON c.id_categoria = p.id_categoria
          WHERE p.ativo = true
            AND (
              LOWER(p.nome)  ILIKE '%' || LOWER(@q) || '%'
              OR LOWER(u.nome) ILIKE '%' || LOWER(@q) || '%'
            )
          ORDER BY e.id_empresa, p.preco ASC
        '''),
        parameters: {'q': q},
      );

      final Map<int, Map<String, dynamic>> empresaMap = {};
      for (final r in result) {
        final idEmpresa   = r[0] as int;
        final empresaNome = r[1]?.toString() ?? '';
        final idProduto   = r[2];
        final produtoNome = r[3]?.toString() ?? '';
        final descricao   = r[4]?.toString() ?? '';
        final preco       = r[5];
        final catNome     = r[6]?.toString() ?? '';
        final imagem      = r[7]?.toString();
        final fotoPerfil  = r[8]?.toString();

        empresaMap.putIfAbsent(idEmpresa, () => {
          'id_empresa':  idEmpresa,
          'nome':        empresaNome,
          'foto_perfil': fotoPerfil,
          'produtos':    <Map<String, dynamic>>[],
        });

        (empresaMap[idEmpresa]!['produtos'] as List).add({
          'id_produto':     idProduto,
          'nome':           produtoNome,
          'descricao':      descricao,
          'preco':          preco,
          'categoria_nome': catNome,
          'imagem':         imagem,
        });
      }

      return _json(200, {'empresas': empresaMap.values.toList()});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  }

  Response _json(int status, Map<String, dynamic> body) {
    return Response(
      status,
      body: jsonEncode(body),
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}
