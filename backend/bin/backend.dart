import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'package:backend/db_connection.dart';
import 'package:backend/controllers/auth_controller.dart';

void main() async {
  final db = DbConnection();
  await db.open();

  final authController = AuthController(db);

  final router = Router()
    ..post('/register/cliente', authController.registerCliente)
    ..post('/register/motoboy', authController.registerMotoboy)
    ..post('/register/restaurante', authController.registerRestaurante)
    ..post('/login', authController.login)
    ..get('/ping', (Request req) => Response.ok("API OK"));

  final handler = Pipeline()
      .addMiddleware(corsHeaders())
      .addMiddleware(logRequests())
      .addHandler(router);

  final server = await io.serve(handler, InternetAddress.anyIPv4, 8080);

  print('🚀 Servidor rodando em http://${server.address.host}:${server.port}');
}
