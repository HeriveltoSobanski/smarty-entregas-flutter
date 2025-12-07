import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:bcrypt/bcrypt.dart';

import '../db_connection.dart';

class AuthController {
  final DbConnection db;

  AuthController(this.db);

  // ------------------------------------------------------------
  //  REGISTRO DE CLIENTE
  // ------------------------------------------------------------
  Future<Response> registerCliente(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());

      final nome = body['nome'] as String?;
      final email = body['email'] as String?;
      final senha = body['senha'] as String?;
      final cpf = body['cpf'] as String?;
      final telefone = body['telefone'] as String?;

      if ([nome, email, senha, cpf, telefone].contains(null)) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Campos obrigatórios ausentes'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final senhaHash = BCrypt.hashpw(senha!, BCrypt.gensalt());

      // documento = cpf
      await db.connection.execute(
        r'''
        INSERT INTO usuarios
          (nome, tipo_usuario, email, senha, cpf, telefone, documento, ativo)
        VALUES
          ($1, 'cliente', $2, $3, $4, $5, $4, true)
        ''',
        parameters: [nome, email, senhaHash, cpf, telefone],
      );

      return Response.ok(
        jsonEncode({'message': 'Cliente registrado com sucesso'}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      print('🔥 Erro em registerCliente: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Erro ao registrar cliente'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // ------------------------------------------------------------
  //  REGISTRO DE MOTOBOY
  // ------------------------------------------------------------
  Future<Response> registerMotoboy(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());

      final nome = body['nome'] as String?;
      final email = body['email'] as String?;
      final senha = body['senha'] as String?;
      final cpf = body['cpf'] as String?;
      final telefone = body['telefone'] as String?;

      if ([nome, email, senha, cpf, telefone].contains(null)) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Campos obrigatórios ausentes'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final senhaHash = BCrypt.hashpw(senha!, BCrypt.gensalt());

      // documento = cpf
      await db.connection.execute(
        r'''
        INSERT INTO usuarios
          (nome, tipo_usuario, email, senha, cpf, telefone, documento, ativo)
        VALUES
          ($1, 'motoboy', $2, $3, $4, $5, $4, true)
        ''',
        parameters: [nome, email, senhaHash, cpf, telefone],
      );

      return Response.ok(
        jsonEncode({'message': 'Motoboy registrado com sucesso'}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      print('🔥 Erro em registerMotoboy: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Erro ao registrar motoboy'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // ------------------------------------------------------------
  //  REGISTRO DE RESTAURANTE
  // ------------------------------------------------------------
  Future<Response> registerRestaurante(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());

      final nome = body['nome'] as String?;
      final email = body['email'] as String?;
      final senha = body['senha'] as String?;
      final cnpj = body['cnpj'] as String?;
      final telefone = body['telefone'] as String?;

      if ([nome, email, senha, cnpj, telefone].contains(null)) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Campos obrigatórios ausentes'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final senhaHash = BCrypt.hashpw(senha!, BCrypt.gensalt());

      // documento = cnpj
      await db.connection.execute(
        r'''
        INSERT INTO usuarios
          (nome, tipo_usuario, email, senha, cnpj, telefone, documento, ativo)
        VALUES
          ($1, 'restaurante', $2, $3, $4, $5, $4, true)
        ''',
        parameters: [nome, email, senhaHash, cnpj, telefone],
      );

      return Response.ok(
        jsonEncode({'message': 'Restaurante registrado com sucesso'}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      print('🔥 Erro em registerRestaurante: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Erro ao registrar restaurante'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // ------------------------------------------------------------
  //  LOGIN
  // ------------------------------------------------------------
  Future<Response> login(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());

      final email = body['email'] as String?;
      final senhaDigitada = body['senha'] as String?;

      if (email == null || senhaDigitada == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'E-mail e senha são obrigatórios'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final result = await db.connection.execute(
        r'''
        SELECT id_usuario, nome, email, senha, tipo_usuario, ativo
        FROM usuarios
        WHERE email = $1
        ''',
        parameters: [email],
      );

      if (result.isEmpty) {
        return Response.forbidden(
          jsonEncode({'error': 'Usuário não encontrado'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final row = result.first.toColumnMap();
      final senhaHash = row['senha'] as String;

      if (!BCrypt.checkpw(senhaDigitada, senhaHash)) {
        return Response.forbidden(
          jsonEncode({'error': 'Senha incorreta'}),
          headers: {'content-type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          'id': row['id_usuario'],
          'nome': row['nome'],
          'email': row['email'],
          'tipo_usuario': row['tipo_usuario'],
          'ativo': row['ativo'],
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      print('🔥 Erro em login: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Erro ao realizar login'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }
}
