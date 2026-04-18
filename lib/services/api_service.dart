import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/session_store.dart';

class ApiService {
  // URL configurada via --dart-define=API_URL=http://...
  // Padrão: IP local de desenvolvimento
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8080',
  );

  // ----------------------------------------------------------------
  // HEADERS
  // ----------------------------------------------------------------

  static Map<String, String> get _publicHeaders => {
        'Content-Type': 'application/json',
        if (!kIsWeb) 'ngrok-skip-browser-warning': 'true',
      };

  static Map<String, String> get _authHeaders {
    final token = SessionStore.token;
    return {
      'Content-Type': 'application/json',
      if (!kIsWeb) 'ngrok-skip-browser-warning': 'true',
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

  static Future<Map<String, dynamic>> loginGoogle(String idToken) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: _publicHeaders,
      body: jsonEncode({'id_token': idToken}),
    );
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 200) return data;
    throw Exception((data['error'] ?? 'Erro ao fazer login com Google').toString());
  }

  static Future<Map<String, dynamic>> loginFacebook(String accessToken) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/facebook'),
      headers: _publicHeaders,
      body: jsonEncode({'access_token': accessToken}),
    );
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 200) return data;
    throw Exception((data['error'] ?? 'Erro ao fazer login com Facebook').toString());
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
    bool            isPizza         = false,
    bool            pizzaMeioAMeio  = false,
    bool            pizzaTresSabores = false,
  }) async {
    try {
      final body = <String, dynamic>{
        'id_empresa':          idEmpresa,
        'id_categoria':        idCategoria,
        'nome':                nome,
        'descricao':           descricao,
        'preco':               preco,
        'is_pizza':            isPizza,
        'pizza_meio_a_meio':   pizzaMeioAMeio,
        'pizza_tres_sabores':  pizzaTresSabores,
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

  static Future<String?> updateProduto({
    required int    idProduto,
    required int    idCategoria,
    required String nome,
    required String descricao,
    required double preco,
    String?         imagem,
    bool            isPizza          = false,
    bool            pizzaMeioAMeio   = false,
    bool            pizzaTresSabores = false,
  }) async {
    try {
      final body = <String, dynamic>{
        'id_categoria':        idCategoria,
        'nome':                nome,
        'descricao':           descricao,
        'preco':               preco,
        'is_pizza':            isPizza,
        'pizza_meio_a_meio':   pizzaMeioAMeio,
        'pizza_tres_sabores':  pizzaTresSabores,
      };
      if (imagem != null && imagem.isNotEmpty) body['imagem'] = imagem;

      final resp = await http.put(
        Uri.parse('$baseUrl/produtos/$idProduto'),
        headers: _authHeaders,
        body: jsonEncode(body),
      );

      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao atualizar produto';
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

  /// Retorna `{'id_pedido': int}` em caso de sucesso,
  /// ou `{'erro': String}` em caso de falha.
  static Future<Map<String, dynamic>> criarPedido({
    required int idUsuario,
    required int idEmpresa,
    required List<Map<String, dynamic>> itens,
    String enderecoEntrega = '',
    String observacao = '',
    String formaPagamento = '',
    double? trocoPara,
    double taxaEntrega = 0.0,
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
          'taxa_entrega':     taxaEntrega,
          if (formaPagamento.isNotEmpty) 'forma_pagamento': formaPagamento,
          if (trocoPara != null) 'troco_para': trocoPara,
        }),
      );
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 201) {
        return {'id_pedido': data['id_pedido'] as int};
      }
      return {'erro': data['error']?.toString() ?? 'Erro ao criar pedido'};
    } catch (_) {
      return {'erro': 'Servidor indisponível.'};
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

  static Future<Map<String, String?>> getFotosEmpresa(int idEmpresa) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/empresas/$idEmpresa/foto'),
        headers: _authHeaders,
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return {
          'foto_perfil': data['foto_perfil']?.toString(),
          'foto_capa': data['foto_capa']?.toString(),
        };
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  static Future<String?> atualizarFotoEmpresa(
      int idEmpresa, {
        String? fotoPerfil,
        String? fotoCapa,
      }) async {
    try {
      final body = <String, dynamic>{};
      if (fotoPerfil != null && fotoPerfil.isNotEmpty) {
        body['foto_perfil'] = fotoPerfil;
      }
      if (fotoCapa != null && fotoCapa.isNotEmpty) {
        body['foto_capa'] = fotoCapa;
      }
      final resp = await http.patch(
        Uri.parse('$baseUrl/empresas/$idEmpresa/foto'),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao salvar foto';
    } catch (_) {
      return 'Servidor indisponível.';
    }
  }

  // ----------------------------------------------------------------
  // CONFIGURAÇÕES DA EMPRESA (taxa mínima + tempo preparo)
  // ----------------------------------------------------------------

  static Future<Map<String, dynamic>?> getConfiguracoes(int idEmpresa) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/empresas/$idEmpresa/configuracoes'),
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

  static Future<String?> atualizarConfiguracoes(
      int idEmpresa, {double? taxaMinima, int? tempoPreparo}) async {
    try {
      final body = <String, dynamic>{};
      if (taxaMinima  != null) body['taxa_minima']   = taxaMinima;
      if (tempoPreparo != null) body['tempo_preparo'] = tempoPreparo;
      final resp = await http.patch(
        Uri.parse('$baseUrl/empresas/$idEmpresa/configuracoes'),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao salvar configurações';
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

  // ----------------------------------------------------------------
  // MOTOBOYS DA EMPRESA
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getMotoboysDaEmpresa(int idEmpresa) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/empresas/$idEmpresa/motoboys'),
        headers: _authHeaders,
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['motoboys'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Busca um motoboy pelo id_usuario para confirmação antes de adicionar à equipe.
  /// Retorna null se não encontrado ou erro.
  static Future<Map<String, dynamic>?> buscarMotoboyPorId(int id) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/motoboys/buscar?id=$id'),
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

  static Future<String?> criarMotoboyEmpresa({
    required int idEmpresa,
    required int idUsuario,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/empresas/$idEmpresa/motoboys'),
        headers: _authHeaders,
        body: jsonEncode({'id_usuario': idUsuario}),
      );
      if (resp.statusCode == 201) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao cadastrar motoboy';
    } catch (_) {
      return 'Servidor indisponível.';
    }
  }

  static Future<void> deletarMotoboyEmpresa(int id) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/empresas/motoboys/$id'),
        headers: _authHeaders,
      );
    } catch (_) {}
  }

  static Future<String?> atribuirMotoboyEmpresa({
    required int idPedido,
    required int idMotoboyEmpresa,
  }) async {
    try {
      final resp = await http.patch(
        Uri.parse('$baseUrl/pedidos/$idPedido/entrega-propria-motoboy'),
        headers: _authHeaders,
        body: jsonEncode({'id_motoboy_empresa': idMotoboyEmpresa}),
      );
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao atribuir motoboy';
    } catch (_) {
      return 'Servidor indisponível.';
    }
  }

  // ----------------------------------------------------------------
  // NOTIFICAÇÕES
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getNotificacoes(int idUsuario) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/notificacoes?id_usuario=$idUsuario'),
        headers: _authHeaders,
      );
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['notificacoes'] ?? []);
    } catch (_) {
      return [];
    }
  }

  static Future<int> getNotificacoesNaoLidas(int idUsuario) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/notificacoes/nao-lidas?id_usuario=$idUsuario'),
        headers: _authHeaders,
      );
      if (resp.statusCode != 200) return 0;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return (data['total'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> marcarNotificacaoLida(int idNotificacao) async {
    try {
      await http.patch(
        Uri.parse('$baseUrl/notificacoes/$idNotificacao/lida'),
        headers: _authHeaders,
      );
    } catch (_) {}
  }

  static Future<void> marcarTodasNotificacoesLidas(int idUsuario) async {
    try {
      await http.patch(
        Uri.parse('$baseUrl/notificacoes/todas-lidas?id_usuario=$idUsuario'),
        headers: _authHeaders,
      );
    } catch (_) {}
  }

  // ----------------------------------------------------------------
  // PERFIL
  // ----------------------------------------------------------------

  /// Retorna { nome, email, telefone } ou null em caso de erro.
  static Future<Map<String, dynamic>?> getPerfil(int idUsuario) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/usuarios/$idUsuario/perfil'),
        headers: _authHeaders,
      );
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Retorna null em sucesso ou mensagem de erro.
  static Future<String?> atualizarPerfil({
    required int     idUsuario,
    String?          nome,
    String?          email,
    String?          telefone,
    String?          novaSenha,
    String?          senhaAtual,
  }) async {
    try {
      final body = <String, dynamic>{
        if (nome      != null) 'nome':       nome,
        if (email     != null) 'email':      email,
        if (telefone  != null) 'telefone':   telefone,
        if (novaSenha != null) 'nova_senha': novaSenha,
        if (senhaAtual!= null) 'senha_atual': senhaAtual,
      };
      final resp = await http.patch(
        Uri.parse('$baseUrl/usuarios/$idUsuario/perfil'),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao atualizar perfil';
    } catch (_) {
      return 'Servidor indisponível.';
    }
  }

  // ----------------------------------------------------------------
  // AVALIAÇÕES
  // ----------------------------------------------------------------

  static Future<String?> enviarAvaliacao({
    required int    idPedido,
    required int    idUsuario,
    required int    idEmpresa,
    required int    notaEmpresa,
    int?            idMotoboy,
    int?            notaMotoboy,
    String?         comentario,
    String?         comentarioEntrega,
    // critérios entregador
    bool?           rapidez,
    bool?           educacao,
    bool?           cuidado,
    // critérios restaurante
    bool?           sabor,
    bool?           embalagem,
    bool?           pedidoCorreto,
  }) async {
    try {
      final body = <String, dynamic>{
        'id_pedido':    idPedido,
        'id_usuario':   idUsuario,
        'id_empresa':   idEmpresa,
        'nota_empresa': notaEmpresa,
        if (idMotoboy          != null) 'id_motoboy':         idMotoboy,
        if (notaMotoboy        != null) 'nota_motoboy':        notaMotoboy,
        if (comentario         != null && comentario.isNotEmpty)         'comentario':         comentario,
        if (comentarioEntrega  != null && comentarioEntrega.isNotEmpty)  'comentario_entrega': comentarioEntrega,
        if (rapidez   != null) 'rapidez':        rapidez,
        if (educacao  != null) 'educacao':        educacao,
        if (cuidado   != null) 'cuidado':         cuidado,
        if (sabor     != null) 'sabor':            sabor,
        if (embalagem != null) 'embalagem':        embalagem,
        if (pedidoCorreto != null) 'pedido_correto': pedidoCorreto,
      };
      final resp = await http.post(
        Uri.parse('$baseUrl/avaliacoes'),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      if (resp.statusCode == 201) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao enviar avaliação';
    } catch (_) {
      return 'Servidor indisponível.';
    }
  }

  /// Retorna {'avaliado': bool, ...} ou null em caso de erro.
  static Future<Map<String, dynamic>?> verificarAvaliacao({
    required int idPedido,
    required int idUsuario,
  }) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/pedidos/$idPedido/avaliacao?id_usuario=$idUsuario'),
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

  // ----------------------------------------------------------------
  // PIZZA — sabores por empresa
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getPizzaSabores(int idEmpresa) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/empresas/$idEmpresa/pizza/sabores'),
        headers: _authHeaders,
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['sabores'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<String?> createPizzaSabor({
    required int    idEmpresa,
    required String nome,
    required String descricao,
    required double preco,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/empresas/$idEmpresa/pizza/sabores'),
        headers: _authHeaders,
        body: jsonEncode({'nome': nome, 'descricao': descricao, 'preco': preco}),
      );
      if (resp.statusCode == 201) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao salvar sabor';
    } catch (_) {
      return 'Servidor indisponível.';
    }
  }

  static Future<String?> updatePizzaSabor({
    required int     idSabor,
    String?          nome,
    String?          descricao,
    double?          preco,
    bool?            ativo,
  }) async {
    try {
      final body = <String, dynamic>{
        if (nome      != null) 'nome':      nome,
        if (descricao != null) 'descricao': descricao,
        if (preco     != null) 'preco':     preco,
        if (ativo     != null) 'ativo':     ativo,
      };
      final resp = await http.patch(
        Uri.parse('$baseUrl/pizza/sabores/$idSabor'),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao atualizar sabor';
    } catch (_) {
      return 'Servidor indisponível.';
    }
  }

  static Future<void> deletePizzaSabor(int idSabor) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/pizza/sabores/$idSabor'),
        headers: _authHeaders,
      );
    } catch (_) {}
  }

  // ----------------------------------------------------------------
  // RECUPERAÇÃO DE SENHA
  // ----------------------------------------------------------------

  /// Verifica se o código de recuperação é válido.
  /// Retorna null em caso de sucesso ou mensagem de erro.
  static Future<String?> verifyCode({
    required String email,
    required String codigo,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/auth/verificar-codigo'),
        headers: _publicHeaders,
        body: jsonEncode({'email': email, 'codigo': codigo}),
      );
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body);
      return data['error']?.toString() ?? 'Código inválido.';
    } catch (_) {
      return 'Servidor indisponível.';
    }
  }

  /// Envia código de recuperação para o e-mail informado.
  /// Retorna null em caso de sucesso ou mensagem de erro.
  static Future<String?> forgotPassword({required String email}) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/auth/esqueci-senha'),
        headers: _publicHeaders,
        body: jsonEncode({'email': email}),
      );
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body);
      return data['error']?.toString() ?? 'Erro ao enviar código.';
    } catch (_) {
      return 'Servidor indisponível.';
    }
  }

  /// Redefine a senha usando o código recebido por e-mail.
  /// Retorna null em caso de sucesso ou mensagem de erro.
  static Future<String?> resetPassword({
    required String email,
    required String codigo,
    required String novaSenha,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/auth/redefinir-senha'),
        headers: _publicHeaders,
        body: jsonEncode({
          'email':     email,
          'codigo':    codigo,
          'nova_senha': novaSenha,
        }),
      );
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body);
      return data['error']?.toString() ?? 'Erro ao redefinir senha.';
    } catch (_) {
      return 'Servidor indisponível.';
    }
  }
}
