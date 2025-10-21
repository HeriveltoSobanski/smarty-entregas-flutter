import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:backend/db_connection.dart';

void main() async {
  final db = DbConnection();
  await db.open();

  final handler =
      Pipeline().addMiddleware(logRequests()).addHandler((Request req) async {
    if (req.url.path == 'ping') {
      return Response.ok('Servidor ativo e conectado!');
    }
    return Response.notFound('Rota não encontrada');
  });

  final server = await io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('✅ Servidor rodando em http://${server.address.host}:${server.port}');
}
