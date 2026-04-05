import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:dotenv/dotenv.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'package:backend/controllers/db_connection.dart';
import 'package:backend/controllers/auth_controller.dart';
import 'package:backend/controllers/produto_controller.dart';
import 'package:backend/controllers/pedido_controller.dart';
import 'package:backend/controllers/criar_pedido_controller.dart';

void main() async {
  final env = DotEnv(includePlatformEnvironment: true)..load();

  final db = DbConnection(env);
  try {
    await db.open();
    print('Conexao com o banco estabelecida com sucesso');
  } catch (e) {
    print('Erro fatal ao conectar ao banco: $e');
    return;
  }

  final auth         = AuthController(db.connection);
  final produto      = ProdutoController(db.connection);
  final pedido       = PedidoController(db.connection);
  final criarPedido  = CriarPedidoController(db.connection);

  final app = Router();

  app.get('/', (Request req) => Response.ok('Smarty Entregas API Rodando'));

  // OPTIONS preflight — responde 200 para todas as rotas
  app.options('/<ignored|.*>', (Request req) => Response.ok(''));

  // AUTH
  app.post('/auth/login',              auth.login);
  app.post('/auth/register/cliente',   auth.registerCliente);
  app.post('/auth/register/empresa',   auth.registerEmpresa);
  app.post('/auth/register/motoboy',   auth.registerMotoboy);

  // PRODUTOS
  app.get('/produtos/categorias',      produto.getCategorias);
  app.get('/produtos/empresa',         produto.getProdutosByEmpresa);
  app.get('/produtos/publico',         produto.getProdutosPublico);
  app.get('/produtos/empresas',        produto.getEmpresasComProdutos);
  app.post('/produtos',                produto.createProduto);
  app.delete('/produtos/<id>',         produto.deleteProduto);
  app.patch('/produtos/<id>/ativo',    produto.toggleAtivo);

  // PEDIDOS
  app.post('/pedidos',                 criarPedido.criarPedido);
  app.get('/pedidos/empresa',          pedido.getPedidosByEmpresa);

  final overrideHeaders = {
    'Access-Control-Allow-Origin':  '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
  };

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders(headers: overrideHeaders))
      .addHandler(app.call);

  final server = await serve(handler, InternetAddress.anyIPv4, 8080);
  print('Servidor online em http://${server.address.host}:${server.port}');
}
