import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class AuthController {
  final Connection conn;

  AuthController(this.conn);

  Router get router {
    final router = Router();

    router.post('/login', _login);
    router.post('/register/cliente', _registerCliente);

    return router;
  }

  Future<Response> _login(Request request) async {
    try {
      final body = await request.readAsString();
      final data = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;

      final email = (data['email'] ?? '').toString().trim();
      final senha = (data['senha'] ?? '').toString();

      if (email.isEmpty || senha.isEmpty) {
        return _json(400, {'error': 'Email e senha são obrigatórios'});
      }

      final result = await conn.execute(
        Sql.named(
          '''
          SELECT id_usuario, email, senha, ativo
          FROM usuarios
          WHERE email = @email
          LIMIT 1
          '''
        ),
        parameters: {'email': email},
      );

      if (result.isEmpty) {
        return _json(401, {'error': 'Credenciais inválidas'});
      }

      final row = result.first;
      final idUsuario = row[0];
      final dbEmail = row[1]?.toString();
      final dbSenha = row[2]?.toString();
      final ativo = row[3] as bool;

      if (!ativo) {
        return _json(403, {'error': 'Usuário inativo'});
      }

      if (dbSenha != senha) {
        return _json(401, {'error': 'Credenciais inválidas'});
      }

      return _json(200, {
        'ok': true,
        'user': {
          'id_usuario': idUsuario,
          'email': dbEmail,
        }
      });
    } catch (e) {
      return _json(500, {
        'error': 'Erro ao realizar login',
        'details': e.toString()
      });
    }
  }

  Future<Response> _registerCliente(Request request) async {
    try {
      final body = await request.readAsString();
      final data = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;

      final nome = (data['nome'] ?? '').toString().trim();
      final email = (data['email'] ?? '').toString().trim();
      final senha = (data['senha'] ?? '').toString();

      if (nome.isEmpty || email.isEmpty || senha.isEmpty) {
        return _json(400, {'error': 'Nome, email e senha são obrigatórios'});
      }

      final result = await conn.execute(
        Sql.named(
          '''
          INSERT INTO usuarios (nome, email, senha, ativo, tipo_usuario, criado_em)
          VALUES (@nome, @email, @senha, true, 'cliente', now())
          RETURNING id_usuario
          '''
        ),
        parameters: {
          'nome': nome,
          'email': email,
          'senha': senha,
        },
      );

      final idUsuario = result.first[0];

      return _json(201, {
        'ok': true,
        'user': {
          'id_usuario': idUsuario,
          'email': email,
        }
      });
    } catch (e) {
      return _json(500, {
        'error': 'Erro ao registrar cliente',
        'details': e.toString()
      });
    }
  }

  Response _json(int status, Map<String, dynamic> body) {
    return Response(
      status,
      body: jsonEncode(body),
      headers: const {
        'content-type': 'application/json; charset=utf-8'
      },
    );
  }
}
