import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:8080';

  // ----------------------------------------------------------------
  // AUTH
  // ----------------------------------------------------------------

  static Future<Map<String, dynamic>> login({
    required String email,
    required String senha,
  }) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'senha': senha}),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 200) return data;
    throw Exception((data['error'] ?? 'Erro ao fazer login').toString());
  }

  static Future<String?> registerCliente({
    required String nome,
    required String email,
    required String senha,
    String? cpf,
    String? telefone,
  }) async {
    try {
      final body = <String, dynamic>{
        'nome': nome, 'email': email, 'senha': senha,
      };
      if (cpf != null && cpf.isNotEmpty) body['cpf'] = cpf;
      if (telefone != null && telefone.isNotEmpty) body['telefone'] = telefone;

      final resp = await http.post(
        Uri.parse('$baseUrl/auth/register/cliente'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) return null;
      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['error']?.toString() ?? 'Erro ao registrar';
      } catch (_) {
        return 'Erro ${resp.statusCode}: ${resp.body}';
      }
    } catch (e) {
      return 'Servidor indisponível. Verifique se o backend está rodando.';
    }
  }

  static Future<String?> registerMotoboy({
    required String nome,
    required String email,
    required String senha,
    String? cpf,
    String? telefone,
  }) async {
    try {
      final body = <String, dynamic>{
        'nome': nome, 'email': email, 'senha': senha,
      };
      if (cpf != null && cpf.isNotEmpty) body['cpf'] = cpf;
      if (telefone != null && telefone.isNotEmpty) body['telefone'] = telefone;

      final resp = await http.post(
        Uri.parse('$baseUrl/auth/register/motoboy'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) return null;
      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['error']?.toString() ?? 'Erro ao registrar';
      } catch (_) {
        return 'Erro ${resp.statusCode}: ${resp.body}';
      }
    } catch (e) {
      return 'Servidor indisponível. Verifique se o backend está rodando.';
    }
  }

  static Future<String?> registerEmpresa({
    required String nome,
    required String email,
    required String senha,
    required String cnpj,
    required String telefone,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/auth/register/empresa'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': nome, 'email': email, 'senha': senha,
          'cnpj': cnpj, 'telefone': telefone,
        }),
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) return null;
      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['error']?.toString() ?? 'Erro ao registrar empresa';
      } catch (_) {
        return 'Erro ${resp.statusCode}: ${resp.body}';
      }
    } catch (e) {
      return 'Servidor indisponível. Verifique se o backend está rodando.';
    }
  }

  // ----------------------------------------------------------------
  // CATEGORIAS
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getCategorias() async {
    try {
      final resp = await http.get(Uri.parse('$baseUrl/produtos/categorias'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['categorias'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ----------------------------------------------------------------
  // PRODUTOS — empresa
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getProdutosByEmpresa(
      int idEmpresa) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/produtos/empresa?id_empresa=$idEmpresa'),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['produtos'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// [categoria] = 'Lanches', 'Pizzas', etc. (opcional)
  static Future<List<Map<String, dynamic>>> getProdutosPublico({
    String? categoria,
  }) async {
    try {
      final uri = categoria != null && categoria.isNotEmpty
          ? Uri.parse(
              '$baseUrl/produtos/publico?categoria=${Uri.encodeComponent(categoria)}')
          : Uri.parse('$baseUrl/produtos/publico');

      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['produtos'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<String?> createProduto({
    required int    idEmpresa,
    required int    idCategoria,
    required String nome,
    required String descricao,
    required double preco,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/produtos'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_empresa':   idEmpresa,
          'id_categoria': idCategoria,
          'nome':         nome,
          'descricao':    descricao,
          'preco':        preco,
        }),
      );

      if (resp.statusCode == 201) return null;
      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final err = data['error']?.toString() ?? 'Erro ${resp.statusCode}';
        final det = data['details']?.toString() ?? '';
        return det.isNotEmpty ? '$err: $det' : err;
      } catch (_) {
        return 'Erro ${resp.statusCode}: ${resp.body}';
      }
    } catch (e) {
      return 'Servidor indisponível. Verifique se o backend está rodando.';
    }
  }

  static Future<void> deleteProduto(int idProduto) async {
    try {
      await http.delete(Uri.parse('$baseUrl/produtos/$idProduto'));
    } catch (_) {}
  }

  static Future<void> toggleProdutoAtivo(int idProduto) async {
    try {
      await http.patch(Uri.parse('$baseUrl/produtos/$idProduto/ativo'));
    } catch (_) {}
  }

  // ----------------------------------------------------------------
  // PEDIDOS — criar
  // ----------------------------------------------------------------

  static Future<String?> criarPedido({
    required int idUsuario,
    required int idEmpresa,
    required List<Map<String, dynamic>> itens, // [{id_produto, quantidade, preco_unit}]
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/pedidos'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_usuario': idUsuario,
          'id_empresa': idEmpresa,
          'itens': itens,
        }),
      );
      if (resp.statusCode == 201) return null;
      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final err = data['error']?.toString() ?? 'Erro ao criar pedido';
        final det = data['details']?.toString() ?? '';
        return det.isNotEmpty ? '$err: $det' : err;
      } catch (_) {
        return 'Erro ${resp.statusCode}: ${resp.body}';
      }
    } catch (e) {
      return 'Servidor indisponível.';
    }
  }

  /// Retorna lista de empresas que têm produtos ativos,
  /// com seus produtos agrupados. Filtro opcional por categoria.
  static Future<List<Map<String, dynamic>>> getEmpresasComProdutos({
    String? categoria,
  }) async {
    try {
      final uri = categoria != null && categoria.isNotEmpty
          ? Uri.parse(
              '$baseUrl/produtos/empresas?categoria=${Uri.encodeComponent(categoria)}')
          : Uri.parse('$baseUrl/produtos/empresas');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['empresas'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ----------------------------------------------------------------
  // PEDIDOS — empresa
  // ----------------------------------------------------------------

  /// [inicio] e [fim] no formato 'YYYY-MM-DD' (opcional)
  static Future<List<Map<String, dynamic>>> getPedidosByEmpresa(
    int idEmpresa, {
    String? inicio,
    String? fim,
  }) async {
    try {
      String url = '$baseUrl/pedidos/empresa?id_empresa=$idEmpresa';
      if (inicio != null && fim != null) {
        url += '&inicio=$inicio&fim=$fim';
      }
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['pedidos'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
