import 'dart:convert';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import '../services/jwt_service.dart';

/// Rotas públicas que não exigem autenticação.
const _publicPaths = {
  '',
  'health',
  'auth/login',
  'auth/register/cliente',
  'auth/register/empresa',
  'auth/register/motoboy',
  'produtos/categorias',
  'produtos/publico',
  'produtos/empresas',
  'produtos/busca',
  'motoboys/count',
  'auth/esqueci-senha',
  'auth/verificar-codigo',
  'auth/redefinir-senha',
  'auth/google',
  'auth/facebook',
};

/// ACL por prefixo de rota e método HTTP.
/// Formato: (method, pathPrefix) → tipo exigido.
/// A verificação usa startsWith no path após strip da barra inicial.
const _routeAcl = <(String, String), String>{
  // Empresa
  ('POST',   'produtos'):                   'empresa',
  ('PUT',    'produtos/'):                  'empresa',
  ('DELETE', 'produtos/'):                  'empresa',
  ('PATCH',  'produtos/'):                  'empresa',
  ('POST',   'produtos/'):                  'empresa',
  ('DELETE', 'adicionais/'):                'empresa',
  ('POST',   'pizza/'):                     'empresa',
  ('PATCH',  'pizza/'):                     'empresa',
  ('DELETE', 'pizza/'):                     'empresa',
  ('PATCH',  'empresas/'):                  'empresa',
  ('GET',    'empresas/relatorio'):         'empresa',
  ('GET',    'empresas/'):                  'empresa',
  ('GET',    'produtos/empresa'):           'empresa',
  ('GET',    'pedidos/empresa'):            'empresa',
  ('PATCH',  'pedidos/'):                   'empresa',
  // Gestão de cupons é exclusiva do admin (admin-panel). O controller já
  // exige tipoUsuario == 'admin'; a ACL 'empresa' antiga era inconsistente e
  // barrava o próprio admin no gate. POST /cupons/validar permanece liberado
  // para qualquer autenticado via _anyAuthPaths (usado pelo cliente no checkout).
  ('POST',   'cupons'):                     'admin',
  ('GET',    'cupons'):                     'admin',
  ('PATCH',  'cupons/'):                    'admin',
  ('POST',   'empresas/'):                  'empresa',
  ('DELETE', 'empresas/'):                  'empresa',
  // Cliente
  ('POST',   'pedidos'):                    'cliente',
  ('GET',    'pedidos/cliente'):            'cliente',
  ('GET',    'clientes/'):                  'cliente',
  ('POST',   'clientes/'):                  'cliente',
  ('DELETE', 'clientes/'):                  'cliente',
  ('POST',   'avaliacoes'):                 'cliente',
  // Motoboy
  ('GET',    'motoboy/disponiveis'):        'motoboy',
  ('GET',    'motoboy/em-rota'):            'motoboy',
  ('GET',    'motoboy/historico'):          'motoboy',
  ('POST',   'motoboy/aceitar'):            'motoboy',
  ('PATCH',  'motoboy/status'):             'motoboy',
  ('PATCH',  'motoboy/meu-status'):         'motoboy',
};

/// Rotas que qualquer tipo autenticado pode acessar (sobrepõem prefixos acima).
const _anyAuthPaths = {
  'GET:notificacoes',
  'GET:notificacoes/',
  'PATCH:notificacoes/',
  'POST:dispositivos/',
  'GET:usuarios/',
  'PATCH:usuarios/',
  'POST:cupons/validar',
  'GET:motoboys/buscar',
  'GET:pedidos/',
  'GET:empresas/',
  'GET:produtos/',
  'GET:pizza/',
};

/// Middleware que valida JWT e aplica RBAC por rota.
Middleware jwtMiddleware(JwtService jwtService, Pool conn) {
  return (Handler inner) {
    return (Request req) async {
      if (req.method == 'OPTIONS') return inner(req);

      final path = req.url.path;

      if (_publicPaths.contains(path)) return inner(req);

      final authHeader = req.headers['authorization'] ?? '';
      if (!authHeader.startsWith('Bearer ')) {
        return _unauthorized('Token não fornecido');
      }

      final token = authHeader.substring(7);
      final payload = jwtService.verifyToken(token);
      if (payload == null) {
        return _unauthorized('Token inválido ou expirado');
      }

      // Revogação de sessão: o token carrega a versão (claim `tv`) em que foi
      // emitido. Se não bater com o token_version atual do usuário no banco, o
      // token foi revogado (troca/reset de senha, logout forçado) → 401.
      // Tokens antigos sem `tv` valem como 0, casando com o DEFAULT 0 da coluna.
      final sub = payload['sub'];
      final subId = sub is int ? sub : int.tryParse(sub?.toString() ?? '');
      if (subId == null) return _unauthorized('Token inválido');
      final tokenTv = payload['tv'] is int
          ? payload['tv'] as int
          : int.tryParse(payload['tv']?.toString() ?? '0') ?? 0;
      try {
        final r = await conn.execute(
          Sql.named('SELECT COALESCE(token_version, 0) FROM usuarios WHERE id_usuario = @id'),
          parameters: {'id': subId},
        );
        if (r.isEmpty) return _unauthorized('Sessão inválida');
        final dbTv = r.first[0] is int
            ? r.first[0] as int
            : int.tryParse(r.first[0]?.toString() ?? '0') ?? 0;
        if (dbTv != tokenTv) {
          return _unauthorized('Sessão expirada. Faça login novamente.');
        }
      } catch (_) {
        // Falha transitória do banco não deve deslogar todo mundo (401);
        // sinaliza indisponibilidade para o app tentar de novo.
        return _serviceUnavailable('Falha ao validar sessão');
      }

      final tipoUsuario = payload['tipo']?.toString() ?? '';

      final updated = req.change(context: {
        ...req.context,
        'userId':      payload['sub'],
        'tipoUsuario': tipoUsuario,
        if (payload.containsKey('id_empresa')) 'idEmpresa': payload['id_empresa'],
      });

      // Verifica se a rota está liberada para qualquer autenticado
      final anyKey = '${req.method}:$path';
      final isAnyAuth = _anyAuthPaths.any((p) => anyKey.startsWith(p));
      if (isAnyAuth) return inner(updated);

      // Verifica ACL por prefixo (mais específico primeiro via firstWhere)
      final method = req.method;
      String? tipoExigido;
      int bestLen = -1;
      for (final entry in _routeAcl.entries) {
        final (m, prefix) = entry.key;
        if (m == method && path.startsWith(prefix) && prefix.length > bestLen) {
          tipoExigido = entry.value;
          bestLen = prefix.length;
        }
      }

      if (tipoExigido != null && tipoUsuario != tipoExigido) {
        return _forbidden('Acesso negado: requer perfil $tipoExigido');
      }

      return inner(updated);
    };
  };
}

Response _unauthorized(String message) => Response(
      401,
      body: jsonEncode({'error': message}),
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

Response _forbidden(String message) => Response(
      403,
      body: jsonEncode({'error': message}),
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

Response _serviceUnavailable(String message) => Response(
      503,
      body: jsonEncode({'error': message}),
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
