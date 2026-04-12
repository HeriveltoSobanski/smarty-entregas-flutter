import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/jwt_service.dart';

/// Rotas públicas que não exigem autenticação.
const _publicPaths = {
  '',
  'auth/login',
  'auth/register/cliente',
  'auth/register/empresa',
  'auth/register/motoboy',
  // Listagem pública de produtos/restaurantes (home sem login)
  'produtos/categorias',
  'produtos/publico',
  'produtos/empresas',
  'produtos/busca',
  'motoboys/count',
};

/// Middleware que valida o token JWT em todas as rotas protegidas.
/// Injeta `userId` e `tipoUsuario` no contexto da requisição.
Middleware jwtMiddleware(JwtService jwtService) {
  return (Handler inner) {
    return (Request req) async {
      // CORS preflight — sempre libera
      if (req.method == 'OPTIONS') return inner(req);

      final path = req.url.path;

      // Rotas públicas — libera sem token
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

      final updated = req.change(context: {
        ...req.context,
        'userId': payload['sub'],
        'tipoUsuario': payload['tipo'],
        if (payload.containsKey('id_empresa')) 'idEmpresa': payload['id_empresa'],
      });

      return inner(updated);
    };
  };
}

Response _unauthorized(String message) => Response(
      401,
      body: jsonEncode({'error': message}),
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
