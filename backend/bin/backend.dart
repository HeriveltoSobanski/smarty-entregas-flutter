import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:dotenv/dotenv.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'package:backend/controllers/db_connection.dart';
import 'package:backend/controllers/auth_controller.dart';

void main() async {
  // 1. Carrega as variaveis de ambiente
  final env = DotEnv(includePlatformEnvironment: true)..load();

  // 2. Inicializa o banco
  final db = DbConnection(env);
  
  try {
    await db.open();
    print('Conexao com o banco estabelecida com sucesso');
  } catch (e) {
    print('Erro fatal ao conectar ao banco: $e');
    return;
  }

  // 3. Configuracao das rotas
  final authController = AuthController(db.connection);
  final app = Router();

  app.get('/', (Request request) {
    return Response.ok('Smarty Entregas API Rodando');
  });

  app.mount('/auth/', authController.router.call);

  // 4. Configuracao do CORS e Servidor
  final overrideHeaders = {
    'Access-Control-Allow-Origin': '*', 
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
  };

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders(headers: overrideHeaders))
      .addHandler(app.call);

  final server = await serve(handler, InternetAddress.anyIPv4, 8080);
  print('Servidor online em http://${server.address.host}:${server.port}');
}