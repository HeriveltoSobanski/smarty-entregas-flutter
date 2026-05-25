import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import '../services/jwt_service.dart';
import '../services/password_service.dart';
import '../services/email_service.dart';

class AuthController {
  final Pool conn;
  final JwtService _jwt;
  final EmailService _email;

  AuthController(this.conn, this._jwt, this._email);

  // ---- Rate limiting persistente no banco ----

  Future<bool> _isRateLimited(String key) async {
    try {
      final r = await conn.execute(
        Sql.named('''
          SELECT tentativas FROM login_attempts
          WHERE chave = @chave AND tentativas >= 5 AND bloqueado_ate > NOW()
        '''),
        parameters: {'chave': key},
      );
      return r.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _recordFail(String key) async {
    try {
      await conn.execute(
        Sql.named('''
          INSERT INTO login_attempts (chave, tentativas, bloqueado_ate)
          VALUES (@chave, 1, NOW() + INTERVAL '15 minutes')
          ON CONFLICT (chave) DO UPDATE
            SET tentativas   = CASE
                  WHEN login_attempts.bloqueado_ate <= NOW()
                  THEN 1
                  ELSE login_attempts.tentativas + 1
                END,
                bloqueado_ate = CASE
                  WHEN login_attempts.bloqueado_ate <= NOW()
                  THEN NOW() + INTERVAL '15 minutes'
                  ELSE login_attempts.bloqueado_ate
                END
        '''),
        parameters: {'chave': key},
      );
    } catch (_) {}
  }

  Future<void> _clearAttempts(String key) async {
    try {
      await conn.execute(
        Sql.named('DELETE FROM login_attempts WHERE chave = @chave'),
        parameters: {'chave': key},
      );
    } catch (_) {}
  }

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

      if (await _isRateLimited('login:$email')) {
        return _json(429, {'error': 'Muitas tentativas. Aguarde 15 minutos.'});
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
        await _recordFail('login:$email');
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
        await _recordFail('login:$email');
        return _json(401, {'error': 'Credenciais inválidas'});
      }

      await _clearAttempts('login:$email');

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
  // REFRESH TOKEN
  // ----------------------------------------------------------------
  Future<Response> refresh(Request request) async {
    try {
      final auth = request.headers['authorization'] ?? '';
      final token = auth.startsWith('Bearer ') ? auth.substring(7) : '';
      if (token.isEmpty) {
        return _json(401, {'error': 'Token ausente'});
      }

      final payload = _jwt.verifyExpiredToken(token);
      if (payload == null) {
        return _json(401, {'error': 'Token inválido ou expirado há mais de 30 dias'});
      }

      final idUsuario   = payload['sub'] as int;
      final tipoUsuario = payload['tipo']?.toString() ?? '';
      final idEmpresa   = payload['id_empresa'] as int?;

      final newToken = _jwt.generateToken(
        idUsuario: idUsuario,
        tipoUsuario: tipoUsuario,
        idEmpresa: idEmpresa,
      );

      return _json(200, {'token': newToken});
    } catch (e) {
      return _json(500, {'error': 'Erro ao renovar token'});
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

  // ----------------------------------------------------------------
  // PERFIL — buscar dados completos
  // ----------------------------------------------------------------
  Future<Response> getPerfil(Request request, String id) async {
    try {
      final idUsuario = int.tryParse(id);
      if (idUsuario == null) return _json(400, {'error': 'ID inválido'});
      final jwtId = int.tryParse(request.context['userId']?.toString() ?? '');
      if (jwtId != idUsuario) return _json(403, {'error': 'Acesso negado'});

      final result = await conn.execute(
        Sql.named('''
          SELECT nome, email, telefone, tipo_usuario
          FROM usuarios WHERE id_usuario = @id LIMIT 1
        '''),
        parameters: {'id': idUsuario},
      );

      if (result.isEmpty) return _json(404, {'error': 'Usuário não encontrado'});

      final r = result.first;
      return _json(200, {
        'nome':        r[0]?.toString() ?? '',
        'email':       r[1]?.toString() ?? '',
        'telefone':    r[2]?.toString() ?? '',
        'tipo_usuario': r[3]?.toString() ?? '',
      });
    } catch (e) {
      return _json(500, {'error': 'Erro ao buscar perfil'});
    }
  }

  // ----------------------------------------------------------------
  // PERFIL — atualizar nome, e-mail, telefone e/ou senha
  // ----------------------------------------------------------------
  Future<Response> atualizarPerfil(Request request, String id) async {
    try {
      final idUsuario = int.tryParse(id);
      if (idUsuario == null) return _json(400, {'error': 'ID inválido'});
      final jwtId = int.tryParse(request.context['userId']?.toString() ?? '');
      if (jwtId != idUsuario) return _json(403, {'error': 'Acesso negado'});

      final body = await request.readAsString();
      final data = body.isEmpty ? <String, dynamic>{} : jsonDecode(body) as Map<String, dynamic>;

      final novoNome     = data['nome']?.toString().trim();
      final novoEmail    = data['email']?.toString().trim();
      final novoTelefone = data['telefone']?.toString().trim();
      final novaSenha    = data['nova_senha']?.toString();
      final senhaAtual   = data['senha_atual']?.toString();

      // Validações
      if (novoNome != null && novoNome.isEmpty) {
        return _json(400, {'error': 'Nome não pode ser vazio'});
      }
      if (novoEmail != null) {
        if (novoEmail.isEmpty) return _json(400, {'error': 'E-mail não pode ser vazio'});
        if (!RegExp(r'.+@.+\..+').hasMatch(novoEmail)) {
          return _json(400, {'error': 'E-mail inválido'});
        }
      }
      if (novaSenha != null) {
        if (novaSenha.length < 6) {
          return _json(400, {'error': 'Nova senha deve ter ao menos 6 caracteres'});
        }
        if (senhaAtual == null || senhaAtual.isEmpty) {
          return _json(400, {'error': 'Informe a senha atual para alterá-la'});
        }
        // Verifica senha atual
        final senhaResult = await conn.execute(
          Sql.named('SELECT senha FROM usuarios WHERE id_usuario = @id LIMIT 1'),
          parameters: {'id': idUsuario},
        );
        if (senhaResult.isEmpty) return _json(404, {'error': 'Usuário não encontrado'});
        final hashAtual = senhaResult.first[0]?.toString() ?? '';
        if (!PasswordService.verify(senhaAtual, hashAtual)) {
          return _json(401, {'error': 'Senha atual incorreta'});
        }
      }

      // Monta SET dinâmico apenas com campos fornecidos
      final sets   = <String>[];
      final params = <String, dynamic>{'id': idUsuario};

      if (novoNome != null)     { sets.add('nome = @nome');         params['nome']     = novoNome; }
      if (novoEmail != null)    { sets.add('email = @email');       params['email']    = novoEmail; }
      if (novoTelefone != null) { sets.add('telefone = @telefone'); params['telefone'] = novoTelefone.isEmpty ? null : novoTelefone; }
      if (novaSenha != null)    { sets.add('senha = @senha');       params['senha']    = PasswordService.hash(novaSenha); }

      if (sets.isEmpty) return _json(400, {'error': 'Nenhum campo para atualizar'});

      sets.add('atualizado_em = NOW()');

      try {
        await conn.execute(
          Sql.named('UPDATE usuarios SET ${sets.join(', ')} WHERE id_usuario = @id'),
          parameters: params,
        );
      } catch (e) {
        if (e.toString().contains('usuarios_email_key')) {
          return _json(409, {'error': 'Este e-mail já está em uso'});
        }
        rethrow;
      }

      // Retorna dados atualizados
      final updated = await conn.execute(
        Sql.named('SELECT nome, email, telefone FROM usuarios WHERE id_usuario = @id LIMIT 1'),
        parameters: {'id': idUsuario},
      );
      final r = updated.first;
      return _json(200, {
        'ok':       true,
        'nome':     r[0]?.toString() ?? '',
        'email':    r[1]?.toString() ?? '',
        'telefone': r[2]?.toString() ?? '',
      });
    } catch (e) {
      return _json(500, {'error': 'Erro ao atualizar perfil'});
    }
  }

  // ----------------------------------------------------------------
  // ESQUECI SENHA — envia código por e-mail
  // ----------------------------------------------------------------
  Future<Response> esqueciSenha(Request request) async {
    try {
      final body = await request.readAsString();
      final data = body.isEmpty ? <String, dynamic>{} : jsonDecode(body) as Map<String, dynamic>;
      final email = (data['email'] ?? '').toString().trim();

      if (email.isEmpty) return _json(400, {'error': 'E-mail obrigatório'});
      if (await _isRateLimited('reset:$email')) {
        return _json(429, {'error': 'Muitas tentativas. Aguarde 15 minutos.'});
      }

      final result = await conn.execute(
        Sql.named('SELECT id_usuario FROM usuarios WHERE email = @email LIMIT 1'),
        parameters: {'email': email},
      );
      // Retorna 200 mesmo se não existe (não revela se e-mail está cadastrado)
      if (result.isEmpty) return _json(200, {'ok': true});

      final code = (Random.secure().nextInt(900000) + 100000).toString();

      await conn.execute(
        Sql.named('''
          INSERT INTO recuperacao_senha (email, codigo, expira_em)
          VALUES (@email, @codigo, NOW() + INTERVAL '15 minutes')
        '''),
        parameters: {'email': email, 'codigo': code},
      );

      await _email.sendRecoveryCode(email, code);
      return _json(200, {'ok': true});
    } catch (e) {
      return _json(500, {'error': 'Erro ao enviar código: ${e.toString()}'});
    }
  }

  // ----------------------------------------------------------------
  // VERIFICAR CÓDIGO
  // ----------------------------------------------------------------
  Future<Response> verificarCodigo(Request request) async {
    try {
      final body = await request.readAsString();
      final data = body.isEmpty ? <String, dynamic>{} : jsonDecode(body) as Map<String, dynamic>;
      final email  = (data['email']  ?? '').toString().trim();
      final codigo = (data['codigo'] ?? '').toString().trim();

      if (email.isEmpty || codigo.isEmpty) {
        return _json(400, {'error': 'E-mail e código obrigatórios'});
      }

      final result = await conn.execute(
        Sql.named('''
          SELECT id FROM recuperacao_senha
          WHERE email = @email AND codigo = @codigo
            AND usado = false AND expira_em > NOW()
          ORDER BY id DESC LIMIT 1
        '''),
        parameters: {'email': email, 'codigo': codigo},
      );

      if (result.isEmpty) {
        await _recordFail('reset:$email');
        return _json(400, {'error': 'Código inválido ou expirado'});
      }
      await _clearAttempts('reset:$email');
      return _json(200, {'ok': true});
    } catch (e) {
      return _json(500, {'error': 'Erro ao verificar código'});
    }
  }

  // ----------------------------------------------------------------
  // REDEFINIR SENHA
  // ----------------------------------------------------------------
  Future<Response> redefinirSenha(Request request) async {
    try {
      final body = await request.readAsString();
      final data = body.isEmpty ? <String, dynamic>{} : jsonDecode(body) as Map<String, dynamic>;
      final email     = (data['email']      ?? '').toString().trim();
      final codigo    = (data['codigo']     ?? '').toString().trim();
      final novaSenha = (data['nova_senha'] ?? '').toString();

      if (email.isEmpty || codigo.isEmpty || novaSenha.isEmpty) {
        return _json(400, {'error': 'E-mail, código e nova senha são obrigatórios'});
      }
      if (novaSenha.length < 6) {
        return _json(400, {'error': 'A senha deve ter ao menos 6 caracteres'});
      }

      final codeResult = await conn.execute(
        Sql.named('''
          SELECT id FROM recuperacao_senha
          WHERE email = @email AND codigo = @codigo
            AND usado = false AND expira_em > NOW()
          ORDER BY id DESC LIMIT 1
        '''),
        parameters: {'email': email, 'codigo': codigo},
      );

      if (codeResult.isEmpty) return _json(400, {'error': 'Código inválido ou expirado'});

      final idCodigo = codeResult.first[0] as int;
      final senhaHash = PasswordService.hash(novaSenha);

      await conn.execute(
        Sql.named('UPDATE usuarios SET senha = @senha WHERE email = @email'),
        parameters: {'senha': senhaHash, 'email': email},
      );
      await conn.execute(
        Sql.named('UPDATE recuperacao_senha SET usado = true WHERE id = @id'),
        parameters: {'id': idCodigo},
      );

      return _json(200, {'ok': true});
    } catch (e) {
      return _json(500, {'error': 'Erro ao redefinir senha'});
    }
  }

  // ----------------------------------------------------------------
  // LOGIN GOOGLE
  // ----------------------------------------------------------------
  Future<Response> loginGoogle(Request request) async {
    try {
      final body = await request.readAsString();
      final data = body.isEmpty ? <String, dynamic>{} : jsonDecode(body) as Map<String, dynamic>;

      final idToken = (data['id_token'] ?? '').toString().trim();
      if (idToken.isEmpty) {
        return _json(400, {'error': 'Token Google obrigatório'});
      }

      final googleResp = await http.get(
        Uri.parse('https://oauth2.googleapis.com/tokeninfo?id_token=$idToken'),
      );

      if (googleResp.statusCode != 200) {
        return _json(401, {'error': 'Token Google inválido'});
      }

      final googleData = jsonDecode(googleResp.body) as Map<String, dynamic>;
      if (googleData.containsKey('error_description')) {
        return _json(401, {'error': 'Token Google inválido'});
      }

      final email = googleData['email']?.toString().trim() ?? '';
      final nome  = (googleData['name'] ?? googleData['given_name'] ?? 'Usuário Google').toString().trim();

      if (email.isEmpty) {
        return _json(400, {'error': 'E-mail não fornecido pelo Google'});
      }

      return await _socialLogin(email: email, nome: nome);
    } catch (e) {
      return _json(500, {'error': 'Erro ao autenticar com Google'});
    }
  }

  // ----------------------------------------------------------------
  // LOGIN FACEBOOK
  // ----------------------------------------------------------------
  Future<Response> loginFacebook(Request request) async {
    try {
      final body = await request.readAsString();
      final data = body.isEmpty ? <String, dynamic>{} : jsonDecode(body) as Map<String, dynamic>;

      final accessToken = (data['access_token'] ?? '').toString().trim();
      if (accessToken.isEmpty) {
        return _json(400, {'error': 'Token Facebook obrigatório'});
      }

      final fbResp = await http.get(
        Uri.parse('https://graph.facebook.com/me?fields=id,name,email&access_token=$accessToken'),
      );

      if (fbResp.statusCode != 200) {
        return _json(401, {'error': 'Token Facebook inválido'});
      }

      final fbData = jsonDecode(fbResp.body) as Map<String, dynamic>;
      if (fbData.containsKey('error')) {
        return _json(401, {'error': 'Token Facebook inválido'});
      }

      final email = fbData['email']?.toString().trim() ?? '';
      final nome  = fbData['name']?.toString().trim() ?? 'Usuário Facebook';

      if (email.isEmpty) {
        return _json(400, {'error': 'E-mail não fornecido pelo Facebook. Verifique as permissões do app.'});
      }

      return await _socialLogin(email: email, nome: nome);
    } catch (e) {
      return _json(500, {'error': 'Erro ao autenticar com Facebook'});
    }
  }

  // ----------------------------------------------------------------
  // SOCIAL LOGIN — lógica compartilhada: busca ou cria usuário
  // ----------------------------------------------------------------
  Future<Response> _socialLogin({required String email, required String nome}) async {
    final result = await conn.execute(
      Sql.named('''
        SELECT u.id_usuario, u.ativo, u.tipo_usuario, u.nome,
               COALESCE(e.id_empresa, 0) AS id_empresa
        FROM usuarios u
        LEFT JOIN empresas e ON e.id_usuario = u.id_usuario
        WHERE u.email = @email
        LIMIT 1
      '''),
      parameters: {'email': email},
    );

    int    idUsuario;
    String tipoUsuario;
    String nomeUsuario;
    int    idEmpresa;

    if (result.isNotEmpty) {
      final row = result.first;
      idUsuario   = row[0] as int;
      final ativo = row[1] as bool;
      tipoUsuario = row[2]?.toString() ?? 'cliente';
      nomeUsuario = row[3]?.toString() ?? nome;
      idEmpresa   = (row[4] as int?) ?? 0;

      if (!ativo) return _json(403, {'error': 'Usuário inativo'});
    } else {
      // Cria novo usuário com senha aleatória (não usada em social login)
      final senhaHash = PasswordService.hash(
        '${DateTime.now().millisecondsSinceEpoch}$email',
      );

      final ins = await conn.execute(
        Sql.named('''
          INSERT INTO usuarios
            (nome, email, senha, ativo, tipo_usuario, criado_em, atualizado_em)
          VALUES
            (@nome, @email, @senha, true, 'cliente', now(), now())
          RETURNING id_usuario
        '''),
        parameters: {'nome': nome, 'email': email, 'senha': senhaHash},
      );

      idUsuario   = ins.first[0] as int;
      tipoUsuario = 'cliente';
      nomeUsuario = nome;
      idEmpresa   = 0;
    }

    final token = _jwt.generateToken(
      idUsuario:   idUsuario,
      tipoUsuario: tipoUsuario,
      idEmpresa:   idEmpresa,
    );

    return _json(200, {
      'ok':    true,
      'token': token,
      'user':  {
        'id_usuario':   idUsuario,
        'email':        email,
        'nome':         nomeUsuario,
        'tipo_usuario': tipoUsuario,
        'id_empresa':   idEmpresa,
      },
    });
  }

  Response _json(int status, Map<String, dynamic> body) {
    return Response(
      status,
      body: jsonEncode(body),
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}
