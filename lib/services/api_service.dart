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
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
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
  // BUSCA
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> buscarProdutos(String termo) async {
    try {
      final uri = Uri.parse(
          '$baseUrl/produtos/busca?q=${Uri.encodeComponent(termo)}');
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
  // PEDIDOS — criar
  // ----------------------------------------------------------------

  static Future<Map<String, dynamic>?> getPedidoDetalhes(int idPedido) async {
    try {
      final resp = await http.get(
          Uri.parse('$baseUrl/pedidos/$idPedido/detalhes'));
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
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_usuario':       idUsuario,
          'id_empresa':       idEmpresa,
          'itens':            itens,
          'endereco_entrega': enderecoEntrega,
          'observacao':       observacao,
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

  // ----------------------------------------------------------------
  // PEDIDOS — cliente
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getPedidosByCliente(
      int idUsuario) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/pedidos/cliente?id_usuario=$idUsuario'),
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

  static Future<void> atualizarStatusPedido(
      int idPedido, int idStatus) async {
    try {
      await http.patch(
        Uri.parse('$baseUrl/pedidos/$idPedido/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_status': idStatus}),
      );
    } catch (_) {}
  }

  // ----------------------------------------------------------------
  // EMPRESAS com produtos
  // ----------------------------------------------------------------

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
  // ADICIONAIS
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getAdicionais(int idProduto) async {
    try {
      final resp = await http.get(
          Uri.parse('$baseUrl/produtos/$idProduto/adicionais'));
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
        headers: {'Content-Type': 'application/json'},
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
      await http.delete(Uri.parse('$baseUrl/adicionais/$idAdicional'));
    } catch (_) {}
  }

  // ----------------------------------------------------------------
  // FOTO PERFIL EMPRESA
  // ----------------------------------------------------------------

  // ----------------------------------------------------------------
  // ENDEREÇOS DO CLIENTE
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getEnderecosCliente(
      int idUsuario) async {
    try {
      final resp = await http.get(
          Uri.parse('$baseUrl/clientes/$idUsuario/enderecos'));
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
        headers: {'Content-Type': 'application/json'},
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
          Uri.parse('$baseUrl/clientes/enderecos/$idEndereco'));
    } catch (_) {}
  }

  static Future<void> marcarEnderecoClientePrincipal(int idEndereco) async {
    try {
      await http.patch(
          Uri.parse('$baseUrl/clientes/enderecos/$idEndereco/principal'));
    } catch (_) {}
  }

  // ----------------------------------------------------------------
  // ENDEREÇO DA EMPRESA
  // ----------------------------------------------------------------

  static Future<Map<String, dynamic>?> getEnderecoEmpresa(int idEmpresa) async {
    try {
      final resp = await http.get(
          Uri.parse('$baseUrl/empresas/$idEmpresa/endereco'));
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
        headers: {'Content-Type': 'application/json'},
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
        headers: {'Content-Type': 'application/json'},
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
      final resp = await http.get(Uri.parse('$baseUrl/motoboys/count'));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
      return {'disponiveis': 0, 'em_rota': 0};
    } catch (_) { return {'disponiveis': 0, 'em_rota': 0}; }
  }

  static Future<void> atualizarMeuStatusMotoboy(
      int idMotoboy, String status) async {
    try {
      await http.patch(
        Uri.parse('$baseUrl/motoboy/meu-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_motoboy': idMotoboy, 'status': status}),
      );
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> getEntregasEmRota(int idMotoboy) async {
    try {
      final resp = await http.get(
          Uri.parse('$baseUrl/motoboy/em-rota?id_motoboy=$idMotoboy'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['pedidos'] ?? []);
      }
      return [];
    } catch (_) { return []; }
  }

  static Future<void> marcarQuasePronto(int idPedido) async {
    try {
      await http.patch(Uri.parse('$baseUrl/pedidos/$idPedido/quase-pronto'));
    } catch (_) {}
  }

  static Future<String?> chamarMotoboy(int idPedido) async {
    try {
      final resp = await http.patch(
          Uri.parse('$baseUrl/pedidos/$idPedido/chamar-motoboy'));
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro';
    } catch (_) { return 'Servidor indisponível.'; }
  }

  static Future<void> entregaPropria(int idPedido) async {
    try {
      await http.patch(
          Uri.parse('$baseUrl/pedidos/$idPedido/entrega-propria'));
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> getEntregasDisponiveis() async {
    try {
      final resp = await http.get(Uri.parse('$baseUrl/motoboy/disponiveis'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['pedidos'] ?? []);
      }
      return [];
    } catch (_) { return []; }
  }

  static Future<List<Map<String, dynamic>>> getMinhasEntregas(int idMotoboy) async {
    try {
      final resp = await http.get(
          Uri.parse('$baseUrl/motoboy/minhas?id_motoboy=$idMotoboy'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['pedidos'] ?? []);
      }
      return [];
    } catch (_) { return []; }
  }

  static Future<String?> aceitarEntrega(
      {required int idPedido, required int idMotoboy}) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/motoboy/aceitar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_pedido': idPedido, 'id_motoboy': idMotoboy}),
      );
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao aceitar entrega';
    } catch (_) { return 'Servidor indisponível.'; }
  }

  static Future<void> atualizarStatusMotoboy(
      int idPedido, int idStatus) async {
    try {
      await http.patch(
        Uri.parse('$baseUrl/motoboy/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_pedido': idPedido, 'id_status': idStatus}),
      );
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> getHistoricoMotoboy(
      int idMotoboy, {String? inicio, String? fim}) async {
    try {
      String url = '$baseUrl/motoboy/historico?id_motoboy=$idMotoboy';
      if (inicio != null && fim != null) url += '&inicio=$inicio&fim=$fim';
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      return {};
    } catch (_) { return {}; }
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
