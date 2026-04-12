import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import '../services/jwt_service.dart';
import '../services/password_service.dart';

class AuthController {
  final Connection conn;
  final JwtService _jwt;

  AuthController(this.conn, this._jwt);

  // ----------------------------------------------------------------
  // LOGIN
  // ----------------------------------------------------------------
  Future<Response> login(Request request) async {
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
        Sql.named('''
          SELECT u.id_usuario, u.email, u.senha, u.ativo,
                 u.tipo_usuario, u.nome,
                 COALESCE(e.id_empresa, 0) AS id_empresa
          FROM usuarios u
          LEFT JOIN empresas e ON e.id_usuario = u.id_usuario
          WHERE u.email = @email
          LIMIT 1
        '''),
        parameters: {'email': email},
      );

      if (result.isEmpty) {
        return _json(401, {'error': 'Credenciais inválidas'});
      }

      final row = result.first;
      final idUsuario   = row[0] as int;
      final dbEmail     = row[1]?.toString() ?? '';
      final dbSenha     = row[2]?.toString() ?? '';
      final ativo       = row[3] as bool;
      final tipoUsuario = row[4]?.toString() ?? '';
      final nome        = row[5]?.toString() ?? '';
      final idEmpresa   = (row[6] as int?) ?? 0;

      if (!ativo) {
        return _json(403, {'error': 'Usuário inativo'});
      }

      if (!PasswordService.verify(senha, dbSenha)) {
        return _json(401, {'error': 'Credenciais inválidas'});
      }

      // Migração automática: se a senha estava em texto plano, re-hasheia
      if (PasswordService.needsUpgrade(dbSenha)) {
        final newHash = PasswordService.hash(senha);
        await conn.execute(
          Sql.named('UPDATE usuarios SET senha = @senha WHERE id_usuario = @id'),
          parameters: {'senha': newHash, 'id': idUsuario},
        );
      }

      final token = _jwt.generateToken(
        idUsuario: idUsuario,
        tipoUsuario: tipoUsuario,
        idEmpresa: idEmpresa,
      );

      return _json(200, {
        'ok': true,
        'token': token,
        'user': {
          'id_usuario': idUsuario,
          'email': dbEmail,
          'nome': nome,
          'tipo_usuario': tipoUsuario,
          'id_empresa': idEmpresa,
        }
      });
    } catch (e) {
      return _json(500, {'error': 'Erro ao realizar login'});
    }
  }

  // ----------------------------------------------------------------
  // REGISTRO CLIENTE
  // ----------------------------------------------------------------
  Future<Response> registerCliente(Request request) async {
    try {
      final body = await request.readAsString();
      final data = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;

      final nome     = (data['nome'] ?? '').toString().trim();
      final email    = (data['email'] ?? '').toString().trim();
      final senha    = (data['senha'] ?? '').toString();
      final cpf      = (data['cpf'] ?? '').toString().trim();
      final telefone = (data['telefone'] ?? '').toString().trim();

      if (nome.isEmpty || email.isEmpty || senha.isEmpty) {
        return _json(400, {'error': 'Nome, email e senha são obrigatórios'});
      }
      if (senha.length < 6) {
        return _json(400, {'error': 'Senha deve ter ao menos 6 caracteres'});
      }

      final senhaHash = PasswordService.hash(senha);

      final result = await conn.execute(
        Sql.named('''
          INSERT INTO usuarios
            (nome, email, senha, cpf, telefone, ativo, tipo_usuario, criado_em, atualizado_em)
          VALUES
            (@nome, @email, @senha, @cpf, @telefone, true, 'cliente', now(), now())
          RETURNING id_usuario
        '''),
        parameters: {
          'nome': nome,
          'email': email,
          'senha': senhaHash,
          'cpf': cpf.isEmpty ? null : cpf,
          'telefone': telefone.isEmpty ? null : telefone,
        },
      );

      final idUsuario = result.first[0] as int;
      final token = _jwt.generateToken(
        idUsuario: idUsuario,
        tipoUsuario: 'cliente',
      );

      return _json(201, {
        'ok': true,
        'token': token,
        'user': {'id_usuario': idUsuario, 'email': email, 'tipo_usuario': 'cliente'}
      });
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('usuarios_email_key')) {
        return _json(409, {'error': 'Este e-mail já está cadastrado'});
      }
      return _json(500, {'error': 'Erro ao registrar cliente'});
    }
  }

  // ----------------------------------------------------------------
  // REGISTRO EMPRESA
  // ----------------------------------------------------------------
  Future<Response> registerEmpresa(Request request) async {
    try {
      final body = await request.readAsString();
      final data = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;

      final nome     = (data['nome'] ?? '').toString().trim();
      final email    = (data['email'] ?? '').toString().trim();
      final senha    = (data['senha'] ?? '').toString();
      final cnpj     = (data['cnpj'] ?? '').toString().trim();
      final telefone = (data['telefone'] ?? '').toString().trim();

      if (nome.isEmpty || email.isEmpty || senha.isEmpty ||
          cnpj.isEmpty || telefone.isEmpty) {
        return _json(400, {
          'error': 'Nome fantasia, e-mail, senha, CNPJ e telefone são obrigatórios'
        });
      }
      if (senha.length < 6) {
        return _json(400, {'error': 'Senha deve ter ao menos 6 caracteres'});
      }

      final senhaHash = PasswordService.hash(senha);

      final result = await conn.execute(
        Sql.named('''
          INSERT INTO usuarios
            (nome, email, senha, cnpj, telefone, ativo, tipo_usuario, criado_em, atualizado_em)
          VALUES
            (@nome, @email, @senha, @cnpj, @telefone, true, 'empresa', now(), now())
          RETURNING id_usuario
        '''),
        parameters: {
          'nome': nome,
          'email': email,
          'senha': senhaHash,
          'cnpj': cnpj,
          'telefone': telefone,
        },
      );

      final idUsuario = result.first[0] as int;

      final empResult = await conn.execute(
        Sql.named(
          'SELECT id_empresa FROM empresas WHERE id_usuario = @id_usuario LIMIT 1',
        ),
        parameters: {'id_usuario': idUsuario},
      );

      final idEmpresa =
          empResult.isNotEmpty ? (empResult.first[0] as int?) ?? 0 : 0;

      final token = _jwt.generateToken(
        idUsuario: idUsuario,
        tipoUsuario: 'empresa',
        idEmpresa: idEmpresa,
      );

      return _json(201, {
        'ok': true,
        'token': token,
        'user': {
          'id_usuario': idUsuario,
          'email': email,
          'tipo_usuario': 'empresa',
          'id_empresa': idEmpresa,
        }
      });
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('usuarios_email_key')) {
        return _json(409, {'error': 'Este e-mail já está cadastrado'});
      }
      return _json(500, {'error': 'Erro ao registrar empresa'});
    }
  }

  // ----------------------------------------------------------------
  // REGISTRO MOTOBOY
  // ----------------------------------------------------------------
  Future<Response> registerMotoboy(Request request) async {
    try {
      final body = await request.readAsString();
      final data = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;

      final nome     = (data['nome'] ?? '').toString().trim();
      final email    = (data['email'] ?? '').toString().trim();
      final senha    = (data['senha'] ?? '').toString();
      final cpf      = (data['cpf'] ?? '').toString().trim();
      final telefone = (data['telefone'] ?? '').toString().trim();

      if (nome.isEmpty || email.isEmpty || senha.isEmpty) {
        return _json(400, {'error': 'Nome, email e senha são obrigatórios'});
      }
      if (senha.length < 6) {
        return _json(400, {'error': 'Senha deve ter ao menos 6 caracteres'});
      }

      final senhaHash = PasswordService.hash(senha);

      final result = await conn.execute(
        Sql.named('''
          INSERT INTO usuarios
            (nome, email, senha, cpf, telefone, ativo, tipo_usuario, criado_em, atualizado_em)
          VALUES
            (@nome, @email, @senha, @cpf, @telefone, true, 'motoboy', now(), now())
          RETURNING id_usuario
        '''),
        parameters: {
          'nome': nome,
          'email': email,
          'senha': senhaHash,
          'cpf': cpf.isEmpty ? null : cpf,
          'telefone': telefone.isEmpty ? null : telefone,
        },
      );

      final idUsuario = result.first[0] as int;
      final token = _jwt.generateToken(
        idUsuario: idUsuario,
        tipoUsuario: 'motoboy',
      );

      return _json(201, {
        'ok': true,
        'token': token,
        'user': {
          'id_usuario': idUsuario,
          'email': email,
          'tipo_usuario': 'motoboy',
        }
      });
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('usuarios_email_key')) {
        return _json(409, {'error': 'Este e-mail já está cadastrado'});
      }
      if (msg.contains('usuarios_cpf_key')) {
        return _json(409, {'error': 'Este CPF já está cadastrado'});
      }
      return _json(500, {'error': 'Erro ao registrar motoboy'});
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
