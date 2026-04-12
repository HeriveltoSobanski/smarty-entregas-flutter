import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/session_store.dart';

class ApiService {
  // URL configurada via --dart-define=API_URL=http://...
  // Padrão: IP local de desenvolvimento
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.1.60:8080',
  );

  // ----------------------------------------------------------------
  // HEADERS
  // ----------------------------------------------------------------

  static Map<String, String> get _publicHeaders => {
        'Content-Type': 'application/json',
      };

  static Map<String, String> get _authHeaders {
    final token = SessionStore.token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ----------------------------------------------------------------
  // AUTH (rotas públicas — sem token)
  // ----------------------------------------------------------------

  static Future<Map<String, dynamic>> login({
    required String email,
    required String senha,
  }) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _publicHeaders,
      body: jsonEncode({'email': email, 'senha': senha}),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 200) return data;
    throw Exception((data['error'] ?? 'Erro ao fazer login').toString());
  }

  static Future<Map<String, dynamic>> registerCliente({
    required String nome,
    required String email,
    required String senha,
    String? cpf,
    String? telefone,
  }) async {
    final body = <String, dynamic>{'nome': nome, 'email': email, 'senha': senha};
    if (cpf != null && cpf.isNotEmpty) body['cpf'] = cpf;
    if (telefone != null && telefone.isNotEmpty) body['telefone'] = telefone;

    final resp = await http.post(
      Uri.parse('$baseUrl/auth/register/cliente'),
      headers: _publicHeaders,
      body: jsonEncode(body),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 201) return data;
    throw Exception((data['error'] ?? 'Erro ao registrar').toString());
  }

  static Future<Map<String, dynamic>> registerMotoboy({
    required String nome,
    required String email,
    required String senha,
    String? cpf,
    String? telefone,
  }) async {
    final body = <String, dynamic>{'nome': nome, 'email': email, 'senha': senha};
    if (cpf != null && cpf.isNotEmpty) body['cpf'] = cpf;
    if (telefone != null && telefone.isNotEmpty) body['telefone'] = telefone;

    final resp = await http.post(
      Uri.parse('$baseUrl/auth/register/motoboy'),
      headers: _publicHeaders,
      body: jsonEncode(body),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 201) return data;
    throw Exception((data['error'] ?? 'Erro ao registrar').toString());
  }

  static Future<Map<String, dynamic>> registerEmpresa({
    required String nome,
    required String email,
    required String senha,
    required String cnpj,
    required String telefone,
  }) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/register/empresa'),
      headers: _publicHeaders,
      body: jsonEncode({
        'nome': nome, 'email': email, 'senha': senha,
        'cnpj': cnpj, 'telefone': telefone,
      }),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 201) return data;
    throw Exception((data['error'] ?? 'Erro ao registrar empresa').toString());
  }

  // ----------------------------------------------------------------
  // CATEGORIAS
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getCategorias() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/produtos/categorias'),
        headers: _authHeaders,
      );
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
        headers: _authHeaders,
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

  static Future<List<Map<String, dynamic>>> getProdutosPublico({
    String? categoria,
  }) async {
    try {
      final uri = categoria != null && categoria.isNotEmpty
          ? Uri.parse(
              '$baseUrl/produtos/publico?categoria=${Uri.encodeComponent(categoria)}')
          : Uri.parse('$baseUrl/produtos/publico');

      final resp = await http.get(uri, headers: _authHeaders);
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
    String?         imagem,
  }) async {
    try {
      final body = <String, dynamic>{
        'id_empresa':   idEmpresa,
        'id_categoria': idCategoria,
        'nome':         nome,
        'descricao':    descricao,
        'preco':        preco,
      };
      if (imagem != null && imagem.isNotEmpty) body['imagem'] = imagem;

      final resp = await http.post(
        Uri.parse('$baseUrl/produtos'),
        headers: _authHeaders,
        body: jsonEncode(body),
      );

      if (resp.statusCode == 201) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao salvar produto';
    } catch (_) {
      return 'Servidor indisponível.';
    }
  }

  static Future<void> deleteProduto(int idProduto) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/produtos/$idProduto'),
        headers: _authHeaders,
      );
    } catch (_) {}
  }

  static Future<void> toggleProdutoAtivo(int idProduto) async {
    try {
      await http.patch(
        Uri.parse('$baseUrl/produtos/$idProduto/ativo'),
        headers: _authHeaders,
      );
    } catch (_) {}
  }

  // ----------------------------------------------------------------
  // BUSCA
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> buscarProdutos(String termo) async {
    try {
      final uri = Uri.parse(
          '$baseUrl/produtos/busca?q=${Uri.encodeComponent(termo)}');
      final resp = await http.get(uri, headers: _authHeaders);
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
  // PEDIDOS — criar / consultar
  // ----------------------------------------------------------------

  static Future<Map<String, dynamic>?> getPedidoDetalhes(int idPedido) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/pedidos/$idPedido/detalhes'),
        headers: _authHeaders,
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['pedido'] as Map<String, dynamic>?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> criarPedido({
    required int idUsuario,
    required int idEmpresa,
    required List<Map<String, dynamic>> itens,
    String enderecoEntrega = '',
    String observacao = '',
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/pedidos'),
        headers: _authHeaders,
        body: jsonEncode({
          'id_usuario':       idUsuario,
          'id_empresa':       idEmpresa,
          'itens':            itens,
          'endereco_entrega': enderecoEntrega,
          'observacao':       observacao,
        }),
      );
      if (resp.statusCode == 201) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao criar pedido';
    } catch (_) {
      return 'Servidor indisponível.';
    }
  }

  static Future<List<Map<String, dynamic>>> getPedidosByCliente(
      int idUsuario) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/pedidos/cliente?id_usuario=$idUsuario'),
        headers: _authHeaders,
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['pedidos'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> atualizarStatusPedido(int idPedido, int idStatus) async {
    try {
      await http.patch(
        Uri.parse('$baseUrl/pedidos/$idPedido/status'),
        headers: _authHeaders,
        body: jsonEncode({'id_status': idStatus}),
      );
    } catch (_) {}
  }

  // ----------------------------------------------------------------
  // EMPRESAS COM PRODUTOS
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getEmpresasComProdutos({
    String? categoria,
  }) async {
    try {
      final uri = categoria != null && categoria.isNotEmpty
          ? Uri.parse(
              '$baseUrl/produtos/empresas?categoria=${Uri.encodeComponent(categoria)}')
          : Uri.parse('$baseUrl/produtos/empresas');
      final resp = await http.get(uri, headers: _authHeaders);
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
  // ADICIONAIS
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getAdicionais(int idProduto) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/produtos/$idProduto/adicionais'),
        headers: _authHeaders,
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['grupos'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<String?> createAdicional({
    required int    idProduto,
    required String grupo,
    required int    maximoGrupo,
    required bool   obrigatorio,
    required String nome,
    required String descricao,
    required double preco,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/produtos/$idProduto/adicionais'),
        headers: _authHeaders,
        body: jsonEncode({
          'grupo':        grupo,
          'maximo_grupo': maximoGrupo,
          'obrigatorio':  obrigatorio,
          'nome':         nome,
          'descricao':    descricao,
          'preco':        preco,
        }),
      );
      if (resp.statusCode == 201) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao salvar adicional';
    } catch (_) {
      return 'Servidor indisponível.';
    }
  }

  static Future<void> deleteAdicional(int idAdicional) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/adicionais/$idAdicional'),
        headers: _authHeaders,
      );
    } catch (_) {}
  }

  // ----------------------------------------------------------------
  // ENDEREÇOS DO CLIENTE
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getEnderecosCliente(
      int idUsuario) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/clientes/$idUsuario/enderecos'),
        headers: _authHeaders,
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['enderecos'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<String?> criarEnderecoCliente({
    required int    idUsuario,
    required String endereco,
    required String apelido,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/clientes/$idUsuario/enderecos'),
        headers: _authHeaders,
        body: jsonEncode({
          'apelido':   apelido,
          'endereco':  endereco,
          'latitude':  latitude,
          'longitude': longitude,
        }),
      );
      if (resp.statusCode == 201) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao salvar endereço';
    } catch (_) {
      return 'Servidor indisponível.';
    }
  }

  static Future<void> deletarEnderecoCliente(int idEndereco) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/clientes/enderecos/$idEndereco'),
        headers: _authHeaders,
      );
    } catch (_) {}
  }

  static Future<void> marcarEnderecoClientePrincipal(int idEndereco) async {
    try {
      await http.patch(
        Uri.parse('$baseUrl/clientes/enderecos/$idEndereco/principal'),
        headers: _authHeaders,
      );
    } catch (_) {}
  }

  // ----------------------------------------------------------------
  // ENDEREÇO DA EMPRESA
  // ----------------------------------------------------------------

  static Future<Map<String, dynamic>?> getEnderecoEmpresa(int idEmpresa) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/empresas/$idEmpresa/endereco'),
        headers: _authHeaders,
      );
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> atualizarEnderecoEmpresa(
      int idEmpresa, String endereco, double lat, double lng) async {
    try {
      final resp = await http.patch(
        Uri.parse('$baseUrl/empresas/$idEmpresa/endereco'),
        headers: _authHeaders,
        body: jsonEncode({
          'endereco':  endereco,
          'latitude':  lat,
          'longitude': lng,
        }),
      );
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao salvar endereço';
    } catch (_) {
      return 'Servidor indisponível.';
    }
  }

  static Future<String?> atualizarFotoEmpresa(
      int idEmpresa, String fotoPerfil) async {
    try {
      final resp = await http.patch(
        Uri.parse('$baseUrl/empresas/$idEmpresa/foto'),
        headers: _authHeaders,
        body: jsonEncode({'foto_perfil': fotoPerfil}),
      );
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao salvar foto';
    } catch (_) {
      return 'Servidor indisponível.';
    }
  }

  // ----------------------------------------------------------------
  // MOTOBOY
  // ----------------------------------------------------------------

  static Future<Map<String, dynamic>> getMotoboyCount() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/motoboys/count'),
        headers: _authHeaders,
      );
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      return {'disponiveis': 0, 'em_rota': 0};
    } catch (_) {
      return {'disponiveis': 0, 'em_rota': 0};
    }
  }

  static Future<void> atualizarMeuStatusMotoboy(
      int idMotoboy, String status) async {
    try {
      await http.patch(
        Uri.parse('$baseUrl/motoboy/meu-status'),
        headers: _authHeaders,
        body: jsonEncode({'id_motoboy': idMotoboy, 'status': status}),
      );
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> getEntregasEmRota(
      int idMotoboy) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/motoboy/em-rota?id_motoboy=$idMotoboy'),
        headers: _authHeaders,
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['pedidos'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> marcarQuasePronto(int idPedido) async {
    try {
      await http.patch(
        Uri.parse('$baseUrl/pedidos/$idPedido/quase-pronto'),
        headers: _authHeaders,
      );
    } catch (_) {}
  }

  static Future<String?> chamarMotoboy(int idPedido) async {
    try {
      final resp = await http.patch(
        Uri.parse('$baseUrl/pedidos/$idPedido/chamar-motoboy'),
        headers: _authHeaders,
      );
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro';
    } catch (_) {
      return 'Servidor indisponível.';
    }
  }

  static Future<void> entregaPropria(int idPedido) async {
    try {
      await http.patch(
        Uri.parse('$baseUrl/pedidos/$idPedido/entrega-propria'),
        headers: _authHeaders,
      );
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> getEntregasDisponiveis() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/motoboy/disponiveis'),
        headers: _authHeaders,
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['pedidos'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getMinhasEntregas(
      int idMotoboy) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/motoboy/minhas?id_motoboy=$idMotoboy'),
        headers: _authHeaders,
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['pedidos'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<String?> aceitarEntrega(
      {required int idPedido, required int idMotoboy}) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/motoboy/aceitar'),
        headers: _authHeaders,
        body: jsonEncode({'id_pedido': idPedido, 'id_motoboy': idMotoboy}),
      );
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao aceitar entrega';
    } catch (_) {
      return 'Servidor indisponível.';
    }
  }

  static Future<void> atualizarStatusMotoboy(
      int idPedido, int idStatus) async {
    try {
      await http.patch(
        Uri.parse('$baseUrl/motoboy/status'),
        headers: _authHeaders,
        body: jsonEncode({'id_pedido': idPedido, 'id_status': idStatus}),
      );
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> getHistoricoMotoboy(int idMotoboy,
      {String? inicio, String? fim}) async {
    try {
      String url = '$baseUrl/motoboy/historico?id_motoboy=$idMotoboy';
      if (inicio != null && fim != null) url += '&inicio=$inicio&fim=$fim';
      final resp = await http.get(Uri.parse(url), headers: _authHeaders);
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  // ----------------------------------------------------------------
  // PEDIDOS — empresa
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getPedidosByEmpresa(
    int idEmpresa, {
    String? inicio,
    String? fim,
  }) async {
    try {
      String url = '$baseUrl/pedidos/empresa?id_empresa=$idEmpresa';
      if (inicio != null && fim != null) url += '&inicio=$inicio&fim=$fim';
      final resp = await http.get(Uri.parse(url), headers: _authHeaders);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['pedidos'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ----------------------------------------------------------------
  // MAPA — rota via proxy do backend (ORS key fica no servidor)
  // ----------------------------------------------------------------

  static Future<Map<String, dynamic>?> getRotaORS({
    required double origemLat,
    required double origemLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/mapa/rota'
        '?origemLat=$origemLat'
        '&origemLng=$origemLng'
        '&destLat=$destLat'
        '&destLng=$destLng',
      );
      final resp = await http.get(uri, headers: _authHeaders);
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
