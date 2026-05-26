import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../presentation/navigation/app_routes.dart';
import '../core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../data/session_store.dart';
import '../data/auth_storage.dart';
import '../data/cache_store.dart';
import 'push_notification_service.dart';

class ApiService {
  // ----------------------------------------------------------------
  // TOKEN HELPERS
  // ----------------------------------------------------------------

  static bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }
      final decoded = utf8.decode(base64.decode(payload));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = map['exp'] as int?;
      if (exp == null) return false;
      return DateTime.now()
          .isAfter(DateTime.fromMillisecondsSinceEpoch(exp * 1000));
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return true;
    }
  }

  // Previne múltiplas tentativas de refresh simultâneas
  static bool _refreshing = false;

  static Future<bool> _tryRefresh() async {
    if (_refreshing) return false;
    _refreshing = true;
    try {
      final token = SessionStore.token;
      if (token == null) return false;
      final resp = await _client
          .post(
            Uri.parse('$baseUrl/auth/refresh'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              if (!kIsWeb) 'ngrok-skip-browser-warning': 'true',
            },
          )
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final newToken = data['token'] as String?;
        if (newToken != null) {
          SessionStore.token = newToken;
          await AuthStorage.save(
            token:       newToken,
            idUsuario:   SessionStore.idUsuario!,
            email:       SessionStore.email!,
            nome:        SessionStore.nome!,
            tipoUsuario: SessionStore.tipoUsuario!,
            idEmpresa:   SessionStore.idEmpresa,
          );
          return true;
        }
      }
      return false;
    } catch (e, st) {
      AppLogger.e('ApiService.refresh', e, st);
      return false;
    } finally {
      _refreshing = false;
    }
  }

  static Future<void> _handleUnauthorized() async {
    final refreshed = await _tryRefresh();
    if (refreshed) return;

    await SessionStore.logout();
    final nav = PushNotificationService.navigatorKey.currentState;
    if (nav == null) return;

    // Dialog antes de redirecionar
    final ctx = nav.overlay?.context;
    if (ctx != null && ctx.mounted) {
      await showDialog<void>(
        context: ctx,
        barrierDismissible: false,
        builder: (ctx2) => AlertDialog(
          title: const Text('Sessão expirada'),
          content: const Text('Faça login novamente para continuar.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx2).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

    nav.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  static const _timeout = Duration(seconds: 30);

  // Wrappers que checam expiração antes e 401 depois.
  static Future<http.Response> _get(Uri uri) async {
    final token = SessionStore.token;
    if (token != null && _isTokenExpired(token)) {
      final refreshed = await _tryRefresh();
      if (!refreshed) {
        await _handleUnauthorized();
        throw Exception('Sessão expirada');
      }
    }
    try {
      final resp = await _client
          .get(uri, headers: _authHeaders)
          .timeout(_timeout);
      if (resp.statusCode == 401) await _handleUnauthorized();
      return resp;
    } on SocketException {
      throw const OfflineException();
    } on TimeoutException {
      throw const TimeoutApiException();
    }
  }

  static Future<http.Response> _post(Uri uri, {Object? body}) async {
    final token = SessionStore.token;
    if (token != null && _isTokenExpired(token)) {
      final refreshed = await _tryRefresh();
      if (!refreshed) {
        await _handleUnauthorized();
        throw Exception('Sessão expirada');
      }
    }
    try {
      final resp = await _client
          .post(uri, headers: _authHeaders, body: body)
          .timeout(_timeout);
      if (resp.statusCode == 401) await _handleUnauthorized();
      return resp;
    } on SocketException {
      throw const OfflineException();
    } on TimeoutException {
      throw const TimeoutApiException();
    }
  }

  static Future<http.Response> _put(Uri uri, {Object? body}) async {
    final token = SessionStore.token;
    if (token != null && _isTokenExpired(token)) {
      final refreshed = await _tryRefresh();
      if (!refreshed) {
        await _handleUnauthorized();
        throw Exception('Sessão expirada');
      }
    }
    try {
      final resp = await _client
          .put(uri, headers: _authHeaders, body: body)
          .timeout(_timeout);
      if (resp.statusCode == 401) await _handleUnauthorized();
      return resp;
    } on SocketException {
      throw const OfflineException();
    } on TimeoutException {
      throw const TimeoutApiException();
    }
  }

  static Future<http.Response> _patch(Uri uri, {Object? body}) async {
    final token = SessionStore.token;
    if (token != null && _isTokenExpired(token)) {
      final refreshed = await _tryRefresh();
      if (!refreshed) {
        await _handleUnauthorized();
        throw Exception('Sessão expirada');
      }
    }
    try {
      final resp = await _client
          .patch(uri, headers: _authHeaders, body: body)
          .timeout(_timeout);
      if (resp.statusCode == 401) await _handleUnauthorized();
      return resp;
    } on SocketException {
      throw const OfflineException();
    } on TimeoutException {
      throw const TimeoutApiException();
    }
  }

  static Future<http.Response> _delete(Uri uri) async {
    final token = SessionStore.token;
    if (token != null && _isTokenExpired(token)) {
      final refreshed = await _tryRefresh();
      if (!refreshed) {
        await _handleUnauthorized();
        throw Exception('Sessão expirada');
      }
    }
    try {
      final resp = await _client
          .delete(uri, headers: _authHeaders)
          .timeout(_timeout);
      if (resp.statusCode == 401) await _handleUnauthorized();
      return resp;
    } on SocketException {
      throw const OfflineException();
    } on TimeoutException {
      throw const TimeoutApiException();
    }
  }


  static final _client = http.Client();

  // Configure via: --dart-define=API_URL=https://api.example.com
  // Dev local: http://localhost:8081 (padrão, somente para debug)
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8081',
  );

  // Lançado na primeira chamada em builds de produção com URL insegura.
  // ignore: unused_field
  static final _securityCheck = () {
    if (kReleaseMode && !baseUrl.startsWith('https://')) {
      throw StateError(
        'API_URL deve usar HTTPS em produção. '
        'Passe --dart-define=API_URL=https://... no build. '
        'Recebido: $baseUrl',
      );
    }
    return true;
  }();

  static Map<String, dynamic> _safeJson(http.Response resp, String fallback) {
    try {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return {'error': '$fallback (${resp.statusCode})'};
    }
  }

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

    final data = _safeJson(resp, 'Erro ao fazer login');
    if (resp.statusCode == 200) return data;
    throw Exception((data['error'] ?? 'Erro ao fazer login').toString());
  }

  static Future<Map<String, dynamic>> loginGoogle(String idToken) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: _publicHeaders,
      body: jsonEncode({'id_token': idToken}),
    );
    final data = _safeJson(resp, 'Erro ao fazer login com Google');
    if (resp.statusCode == 200) return data;
    throw Exception((data['error'] ?? 'Erro ao fazer login com Google').toString());
  }

  static Future<Map<String, dynamic>> loginFacebook(String accessToken) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/facebook'),
      headers: _publicHeaders,
      body: jsonEncode({'access_token': accessToken}),
    );
    final data = _safeJson(resp, 'Erro ao fazer login com Facebook');
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

    final data = _safeJson(resp, 'Erro ao registrar');
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

    final data = _safeJson(resp, 'Erro ao registrar');
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

    final data = _safeJson(resp, 'Erro ao registrar empresa');
    if (resp.statusCode == 201) return data;
    throw Exception((data['error'] ?? 'Erro ao registrar empresa').toString());
  }

  // ----------------------------------------------------------------
  // CATEGORIAS
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getCategorias() async {
    try {
      final resp = await _get(Uri.parse('$baseUrl/produtos/categorias'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['categorias'] ?? []);
      }
      return [];
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return [];
    }
  }

  // ----------------------------------------------------------------
  // PRODUTOS — empresa
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getProdutosByEmpresa(
      int idEmpresa) async {
    try {
      final resp = await _get(Uri.parse('$baseUrl/produtos/empresa?id_empresa=$idEmpresa'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['produtos'] ?? []);
      }
      return [];
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>?> getProdutosPublico({
    String? categoria,
  }) async {
    try {
      final uri = categoria != null && categoria.isNotEmpty
          ? Uri.parse(
              '$baseUrl/produtos/publico?categoria=${Uri.encodeComponent(categoria)}')
          : Uri.parse('$baseUrl/produtos/publico');

      final resp = await _get(uri);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['produtos'] ?? []);
      }
      return null;
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return null;
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

      final resp = await _post(Uri.parse('$baseUrl/produtos'), body: jsonEncode(body));

      if (resp.statusCode == 201) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao salvar produto';
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
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

      final resp = await _put(Uri.parse('$baseUrl/produtos/$idProduto'), body: jsonEncode(body));

      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao atualizar produto';
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return 'Servidor indisponível.';
    }
  }

  static Future<void> deleteProduto(int idProduto) async {
    try {
      await _delete(Uri.parse('$baseUrl/produtos/$idProduto'));
    } catch (e, st) { AppLogger.e('ApiService', e, st); }
  }

  static Future<void> toggleProdutoAtivo(int idProduto) async {
    try {
      await _patch(Uri.parse('$baseUrl/produtos/$idProduto/ativo'));
    } catch (e, st) { AppLogger.e('ApiService', e, st); }
  }

  // ----------------------------------------------------------------
  // BUSCA
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> buscarProdutos(String termo) async {
    try {
      final uri = Uri.parse(
          '$baseUrl/produtos/busca?q=${Uri.encodeComponent(termo)}');
      final resp = await _get(uri);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['empresas'] ?? []);
      }
      return [];
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return [];
    }
  }

  // ----------------------------------------------------------------
  // PEDIDOS — criar / consultar
  // ----------------------------------------------------------------

  static Future<Map<String, dynamic>?> getPedidoDetalhes(int idPedido) async {
    try {
      final resp = await _get(Uri.parse('$baseUrl/pedidos/$idPedido/detalhes'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['pedido'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return null;
    }
  }

  /// Valida um cupom. Retorna `{'ok': true, 'desconto': double, ...}` ou `{'erro': String}`.
  static Future<Map<String, dynamic>> validarCupom({
    required String codigo,
    required double valorPedido,
  }) async {
    try {
      final resp = await _post(
        Uri.parse('$baseUrl/cupons/validar'),
        body: jsonEncode({'codigo': codigo, 'valor_pedido': valorPedido}),
      );
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 200) return data;
      return {'erro': data['error']?.toString() ?? 'Cupom inválido'};
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return {'erro': 'Servidor indisponível.'};
    }
  }

  /// Retorna mapa com dados do pedido criado, incluindo dados de PIX se aplicável.
  /// Em caso de falha retorna `{'erro': String}`.
  static Future<Map<String, dynamic>> criarPedido({
    required int idUsuario,
    required int idEmpresa,
    required List<Map<String, dynamic>> itens,
    String enderecoEntrega = '',
    String observacao = '',
    String formaPagamento = '',
    double? trocoPara,
    String? codigoCupom,
    int? idEndereco,
    String? mpCardToken,
  }) async {
    try {
      final resp = await _post(Uri.parse('$baseUrl/pedidos'), body: jsonEncode({
          'id_usuario':       idUsuario,
          'id_empresa':       idEmpresa,
          'itens':            itens,
          'endereco_entrega': enderecoEntrega,
          'observacao':       observacao,
          if (idEndereco != null) 'id_endereco': idEndereco,
          if (formaPagamento.isNotEmpty) 'forma_pagamento': formaPagamento,
          if (trocoPara != null) 'troco_para': trocoPara,
          if (codigoCupom != null && codigoCupom.isNotEmpty) 'codigo_cupom': codigoCupom,
          if (mpCardToken != null && mpCardToken.isNotEmpty) 'mp_card_token': mpCardToken,
        }));
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 201) return data;
      return {'erro': data['error']?.toString() ?? 'Erro ao criar pedido'};
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return {'erro': 'Servidor indisponível.'};
    }
  }

  static Future<Map<String, dynamic>> consultarPagamentoPedido(int idPedido) async {
    try {
      final resp = await _get(Uri.parse('$baseUrl/pedidos/$idPedido/pagamento'));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
      return {'status_pagamento': 'pending'};
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return {'status_pagamento': 'pending'};
    }
  }

  static Future<Map<String, dynamic>> getSaldoEmpresa(int idEmpresa) async {
    try {
      final resp = await _get(Uri.parse('$baseUrl/empresas/$idEmpresa/saldo'));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
      return {'saldo': 0.0};
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return {'saldo': 0.0};
    }
  }

  static Future<Map<String, dynamic>> depositarSaldoEmpresa(int idEmpresa, double valor) async {
    try {
      final resp = await _post(
        Uri.parse('$baseUrl/empresas/$idEmpresa/depositar'),
        body: jsonEncode({'valor': valor}),
      );
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 201) return data;
      return {'erro': data['error']?.toString() ?? 'Erro ao gerar PIX'};
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return {'erro': 'Servidor indisponível.'};
    }
  }

  static Future<({List<Map<String, dynamic>> pedidos, bool temMais, bool fromCache})>
      getPedidosByCliente(int idUsuario,
          {int pagina = 1, int limite = 20}) async {
    const cacheKey = 'pedidos_cliente_p1';
    try {
      final resp = await _get(Uri.parse(
          '$baseUrl/pedidos/cliente?pagina=$pagina&limite=$limite'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final lista = List<Map<String, dynamic>>.from(data['pedidos'] ?? []);
        if (pagina == 1) await CacheStore.save(cacheKey, lista);
        return (
          pedidos: lista,
          temMais: data['tem_mais'] as bool? ?? false,
          fromCache: false,
        );
      }
    } catch (e, st) { AppLogger.e('ApiService', e, st); }

    if (pagina == 1) {
      final cached = await CacheStore.load<List>(cacheKey);
      if (cached != null) {
        return (
          pedidos: cached.cast<Map<String, dynamic>>(),
          temMais: false,
          fromCache: true,
        );
      }
    }
    return (pedidos: <Map<String, dynamic>>[], temMais: false, fromCache: false);
  }

  static Future<void> atualizarStatusPedido(int idPedido, int idStatus) async {
    try {
      await _patch(Uri.parse('$baseUrl/pedidos/$idPedido/status'), body: jsonEncode({'id_status': idStatus}));
    } catch (e, st) { AppLogger.e('ApiService', e, st); }
  }

  // ----------------------------------------------------------------
  // EMPRESAS COM PRODUTOS
  // ----------------------------------------------------------------

  static Future<({List<Map<String, dynamic>> empresas, bool fromCache})>
      getEmpresasComProdutos({String? categoria}) async {
    final cacheKey = 'empresas_${categoria ?? 'todos'}';
    try {
      final uri = categoria != null && categoria.isNotEmpty
          ? Uri.parse(
              '$baseUrl/produtos/empresas?categoria=${Uri.encodeComponent(categoria)}')
          : Uri.parse('$baseUrl/produtos/empresas');
      final resp = await _get(uri);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final lista = List<Map<String, dynamic>>.from(data['empresas'] ?? []);
        await CacheStore.save(cacheKey, lista);
        return (empresas: lista, fromCache: false);
      }
    } catch (e, st) { AppLogger.e('ApiService', e, st); }

    final cached = await CacheStore.load<List>(cacheKey);
    if (cached != null) {
      return (
        empresas: cached.cast<Map<String, dynamic>>(),
        fromCache: true,
      );
    }
    return (empresas: <Map<String, dynamic>>[], fromCache: false);
  }

  // ----------------------------------------------------------------
  // ADICIONAIS
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getAdicionais(int idProduto) async {
    try {
      final resp = await _get(Uri.parse('$baseUrl/produtos/$idProduto/adicionais'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['grupos'] ?? []);
      }
      return [];
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
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
      final resp = await _post(Uri.parse('$baseUrl/produtos/$idProduto/adicionais'), body: jsonEncode({
          'grupo':        grupo,
          'maximo_grupo': maximoGrupo,
          'obrigatorio':  obrigatorio,
          'nome':         nome,
          'descricao':    descricao,
          'preco':        preco,
        }));
      if (resp.statusCode == 201) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao salvar adicional';
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return 'Servidor indisponível.';
    }
  }

  static Future<void> deleteAdicional(int idAdicional) async {
    try {
      await _delete(Uri.parse('$baseUrl/adicionais/$idAdicional'));
    } catch (e, st) { AppLogger.e('ApiService', e, st); }
  }

  // ----------------------------------------------------------------
  // ENDEREÇOS DO CLIENTE
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>?> getEnderecosCliente(
      int idUsuario) async {
    try {
      final resp = await _get(Uri.parse('$baseUrl/clientes/$idUsuario/enderecos'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['enderecos'] ?? []);
      }
      return null;
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return null;
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
      final resp = await _post(Uri.parse('$baseUrl/clientes/$idUsuario/enderecos'), body: jsonEncode({
          'apelido':   apelido,
          'endereco':  endereco,
          'latitude':  latitude,
          'longitude': longitude,
        }));
      if (resp.statusCode == 201) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao salvar endereço';
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return 'Servidor indisponível.';
    }
  }

  static Future<void> deletarEnderecoCliente(int idEndereco) async {
    try {
      await _delete(Uri.parse('$baseUrl/clientes/enderecos/$idEndereco'));
    } catch (e, st) { AppLogger.e('ApiService', e, st); }
  }

  static Future<void> marcarEnderecoClientePrincipal(int idEndereco) async {
    try {
      await _patch(Uri.parse('$baseUrl/clientes/enderecos/$idEndereco/principal'));
    } catch (e, st) { AppLogger.e('ApiService', e, st); }
  }

  // ----------------------------------------------------------------
  // ENDEREÇO DA EMPRESA
  // ----------------------------------------------------------------

  static Future<Map<String, dynamic>?> getEnderecoEmpresa(int idEmpresa) async {
    try {
      final resp = await _get(Uri.parse('$baseUrl/empresas/$idEmpresa/endereco'));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return null;
    }
  }

  static Future<String?> atualizarEnderecoEmpresa(
      int idEmpresa, String endereco, double lat, double lng) async {
    try {
      final resp = await _patch(Uri.parse('$baseUrl/empresas/$idEmpresa/endereco'), body: jsonEncode({
          'endereco':  endereco,
          'latitude':  lat,
          'longitude': lng,
        }));
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao salvar endereço';
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return 'Servidor indisponível.';
    }
  }

  static Future<Map<String, String?>> getFotosEmpresa(int idEmpresa) async {
    try {
      final resp = await _get(Uri.parse('$baseUrl/empresas/$idEmpresa/foto'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return {
          'foto_perfil': data['foto_perfil']?.toString(),
          'foto_capa': data['foto_capa']?.toString(),
        };
      }
      return {};
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
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
      final resp = await _patch(Uri.parse('$baseUrl/empresas/$idEmpresa/foto'), body: jsonEncode(body));
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao salvar foto';
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return 'Servidor indisponível.';
    }
  }

  // ----------------------------------------------------------------
  // CONFIGURAÇÕES DA EMPRESA (taxa mínima + tempo preparo)
  // ----------------------------------------------------------------

  static Future<Map<String, dynamic>?> getConfiguracoes(int idEmpresa) async {
    try {
      final resp = await _get(Uri.parse('$baseUrl/empresas/$idEmpresa/configuracoes'));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return null;
    }
  }

  static Future<String?> atualizarConfiguracoes(
      int idEmpresa, {double? taxaMinima, int? tempoPreparo}) async {
    try {
      final body = <String, dynamic>{};
      if (taxaMinima  != null) body['taxa_minima']   = taxaMinima;
      if (tempoPreparo != null) body['tempo_preparo'] = tempoPreparo;
      final resp = await _patch(Uri.parse('$baseUrl/empresas/$idEmpresa/configuracoes'), body: jsonEncode(body));
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao salvar configurações';
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return 'Servidor indisponível.';
    }
  }

  // ----------------------------------------------------------------
  // MOTOBOY
  // ----------------------------------------------------------------

  static Future<Map<String, dynamic>> getMotoboyCount() async {
    try {
      final resp = await _get(Uri.parse('$baseUrl/motoboys/count'));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      return {'disponiveis': 0, 'em_rota': 0};
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return {'disponiveis': 0, 'em_rota': 0};
    }
  }

  static Future<void> atualizarMeuStatusMotoboy(
      int idMotoboy, String status) async {
    try {
      await _patch(Uri.parse('$baseUrl/motoboy/meu-status'), body: jsonEncode({'id_motoboy': idMotoboy, 'status': status}));
    } catch (e, st) { AppLogger.e('ApiService', e, st); }
  }

  static Future<List<Map<String, dynamic>>> getEntregasEmRota(
      int idMotoboy) async {
    try {
      final resp = await _get(Uri.parse('$baseUrl/motoboy/em-rota?id_motoboy=$idMotoboy'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['pedidos'] ?? []);
      }
      return [];
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return [];
    }
  }

  static Future<void> marcarQuasePronto(int idPedido) async {
    try {
      await _patch(Uri.parse('$baseUrl/pedidos/$idPedido/quase-pronto'));
    } catch (e, st) { AppLogger.e('ApiService', e, st); }
  }

  static Future<String?> chamarMotoboy(int idPedido) async {
    try {
      final resp = await _patch(Uri.parse('$baseUrl/pedidos/$idPedido/chamar-motoboy'));
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro';
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return 'Servidor indisponível.';
    }
  }

  static Future<void> entregaPropria(int idPedido) async {
    try {
      await _patch(Uri.parse('$baseUrl/pedidos/$idPedido/entrega-propria'));
    } catch (e, st) { AppLogger.e('ApiService', e, st); }
  }

  static Future<List<Map<String, dynamic>>> getEntregasDisponiveis() async {
    try {
      final resp = await _get(Uri.parse('$baseUrl/motoboy/disponiveis'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['pedidos'] ?? []);
      }
      return [];
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getMinhasEntregas(
      int idMotoboy) async {
    try {
      final resp = await _get(Uri.parse('$baseUrl/motoboy/minhas?id_motoboy=$idMotoboy'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['pedidos'] ?? []);
      }
      return [];
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return [];
    }
  }

  static Future<String?> aceitarEntrega(
      {required int idPedido, required int idMotoboy}) async {
    try {
      final resp = await _post(Uri.parse('$baseUrl/motoboy/aceitar'), body: jsonEncode({'id_pedido': idPedido, 'id_motoboy': idMotoboy}));
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao aceitar entrega';
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return 'Servidor indisponível.';
    }
  }

  static Future<void> atualizarStatusMotoboy(
      int idPedido, int idStatus) async {
    try {
      await _patch(Uri.parse('$baseUrl/motoboy/status'), body: jsonEncode({'id_pedido': idPedido, 'id_status': idStatus}));
    } catch (e, st) { AppLogger.e('ApiService', e, st); }
  }

  static Future<Map<String, dynamic>> getHistoricoMotoboy(int idMotoboy,
      {String? inicio, String? fim}) async {
    try {
      String url = '$baseUrl/motoboy/historico?id_motoboy=$idMotoboy';
      if (inicio != null && fim != null) url += '&inicio=$inicio&fim=$fim';
      final resp = await _get(Uri.parse(url));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      return {};
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
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
      String url = '$baseUrl/pedidos/empresa';
      if (inicio != null && fim != null) url += '?inicio=$inicio&fim=$fim';
      final resp = await _get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['pedidos'] ?? []);
      }
      return [];
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return [];
    }
  }

  // ----------------------------------------------------------------
  // RELATÓRIO FINANCEIRO — empresa
  // ----------------------------------------------------------------

  static Future<Map<String, dynamic>?> getRelatorioFinanceiro({
    String? inicio,
    String? fim,
  }) async {
    try {
      String url = '$baseUrl/empresas/relatorio';
      if (inicio != null && fim != null) url += '?inicio=$inicio&fim=$fim';
      final resp = await _get(Uri.parse(url));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return null;
    }
  }

  // ----------------------------------------------------------------
  // MAPA — rota via proxy do backend (Mapbox token fica no servidor)
  // ----------------------------------------------------------------

  static Future<Map<String, dynamic>?> getRota({
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
      final resp = await _get(uri);
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return null;
    }
  }

  // ----------------------------------------------------------------
  // MOTOBOYS DA EMPRESA
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getMotoboysDaEmpresa(int idEmpresa) async {
    try {
      final resp = await _get(Uri.parse('$baseUrl/empresas/$idEmpresa/motoboys'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['motoboys'] ?? []);
      }
      return [];
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return [];
    }
  }

  /// Busca um motoboy pelo id_usuario para confirmação antes de adicionar à equipe.
  /// Retorna null se não encontrado ou erro.
  static Future<Map<String, dynamic>?> buscarMotoboyPorId(int id) async {
    try {
      final resp = await _get(Uri.parse('$baseUrl/motoboys/buscar?id=$id'));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return null;
    }
  }

  static Future<String?> criarMotoboyEmpresa({
    required int idEmpresa,
    required int idUsuario,
  }) async {
    try {
      final resp = await _post(Uri.parse('$baseUrl/empresas/$idEmpresa/motoboys'), body: jsonEncode({'id_usuario': idUsuario}));
      if (resp.statusCode == 201) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao cadastrar motoboy';
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return 'Servidor indisponível.';
    }
  }

  static Future<void> deletarMotoboyEmpresa(int id) async {
    try {
      await _delete(Uri.parse('$baseUrl/empresas/motoboys/$id'));
    } catch (e, st) { AppLogger.e('ApiService', e, st); }
  }

  static Future<String?> atribuirMotoboyEmpresa({
    required int idPedido,
    required int idMotoboyEmpresa,
  }) async {
    try {
      final resp = await _patch(Uri.parse('$baseUrl/pedidos/$idPedido/entrega-propria-motoboy'), body: jsonEncode({'id_motoboy_empresa': idMotoboyEmpresa}));
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao atribuir motoboy';
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return 'Servidor indisponível.';
    }
  }

  // ----------------------------------------------------------------
  // NOTIFICAÇÕES
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>?> getNotificacoes(int idUsuario) async {
    try {
      final resp = await _get(Uri.parse('$baseUrl/notificacoes?id_usuario=$idUsuario'));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['notificacoes'] ?? []);
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return null;
    }
  }

  static Future<int> getNotificacoesNaoLidas(int idUsuario) async {
    try {
      final resp = await _get(Uri.parse('$baseUrl/notificacoes/nao-lidas?id_usuario=$idUsuario'));
      if (resp.statusCode != 200) return 0;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return (data['total'] as num?)?.toInt() ?? 0;
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return 0;
    }
  }

  static Future<void> marcarNotificacaoLida(int idNotificacao) async {
    try {
      await _patch(Uri.parse('$baseUrl/notificacoes/$idNotificacao/lida'));
    } catch (e, st) { AppLogger.e('ApiService', e, st); }
  }

  static Future<void> marcarTodasNotificacoesLidas(int idUsuario) async {
    try {
      await _patch(Uri.parse('$baseUrl/notificacoes/todas-lidas?id_usuario=$idUsuario'));
    } catch (e, st) { AppLogger.e('ApiService', e, st); }
  }

  // ----------------------------------------------------------------
  // PERFIL
  // ----------------------------------------------------------------

  /// Retorna { nome, email, telefone } ou null em caso de erro.
  static Future<Map<String, dynamic>?> getPerfil(int idUsuario) async {
    try {
      final resp = await _get(Uri.parse('$baseUrl/usuarios/$idUsuario/perfil'));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
      return null;
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
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
      final resp = await _patch(Uri.parse('$baseUrl/usuarios/$idUsuario/perfil'), body: jsonEncode(body));
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao atualizar perfil';
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
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
      final resp = await _post(Uri.parse('$baseUrl/avaliacoes'), body: jsonEncode(body));
      if (resp.statusCode == 201) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao enviar avaliação';
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return 'Servidor indisponível.';
    }
  }

  /// Retorna {'avaliado': bool, ...} ou null em caso de erro.
  static Future<Map<String, dynamic>?> verificarAvaliacao({
    required int idPedido,
    required int idUsuario,
  }) async {
    try {
      final resp = await _get(Uri.parse('$baseUrl/pedidos/$idPedido/avaliacao?id_usuario=$idUsuario'));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return null;
    }
  }

  // ----------------------------------------------------------------
  // PIZZA — sabores por empresa
  // ----------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getPizzaSabores(int idProduto) async {
    try {
      final resp = await _get(Uri.parse('$baseUrl/produtos/$idProduto/pizza/sabores'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['sabores'] ?? []);
      }
      return [];
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return [];
    }
  }

  static Future<String?> createPizzaSabor({
    required int    idProduto,
    required String nome,
    required String descricao,
    required double preco,
  }) async {
    try {
      final resp = await _post(Uri.parse('$baseUrl/produtos/$idProduto/pizza/sabores'), body: jsonEncode({'nome': nome, 'descricao': descricao, 'preco': preco}));
      if (resp.statusCode == 201) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao salvar sabor';
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
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
      final resp = await _patch(Uri.parse('$baseUrl/pizza/sabores/$idSabor'), body: jsonEncode(body));
      if (resp.statusCode == 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['error']?.toString() ?? 'Erro ao atualizar sabor';
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return 'Servidor indisponível.';
    }
  }

  static Future<void> deletePizzaSabor(int idSabor) async {
    try {
      await _delete(Uri.parse('$baseUrl/pizza/sabores/$idSabor'));
    } catch (e, st) { AppLogger.e('ApiService', e, st); }
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
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
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
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
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
    } catch (e, st) {
      AppLogger.e('ApiService', e, st);
      return 'Servidor indisponível.';
    }
  }

  // ----------------------------------------------------------------
  // FCM TOKEN
  // ----------------------------------------------------------------

  static Future<void> registrarFcmToken({
    required String token,
    required String plataforma,
  }) async {
    try {
      await _post(Uri.parse('$baseUrl/dispositivos/fcm-token'), body: jsonEncode({
          'fcm_token':  token,
          'plataforma': plataforma,
        }));
    } catch (e, st) { AppLogger.e('ApiService', e, st); }
  }
}

class OfflineException implements Exception {
  const OfflineException();
  @override
  String toString() => 'Sem conexão com a internet.';
}

class TimeoutApiException implements Exception {
  const TimeoutApiException();
  @override
  String toString() => 'Servidor demorou para responder. Tente novamente.';
}
