import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:dotenv/dotenv.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'package:postgres/postgres.dart';
import 'package:backend/controllers/db_connection.dart';
import 'package:backend/controllers/auth_controller.dart';
import 'package:backend/controllers/produto_controller.dart';
import 'package:backend/controllers/pedido_controller.dart';
import 'package:backend/controllers/criar_pedido_controller.dart';
import 'package:backend/controllers/adicional_controller.dart';
import 'package:backend/controllers/empresa_controller.dart';
import 'package:backend/controllers/motoboy_controller.dart';

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

  // ── Migrações ─────────────────────────────────────────────────
  final migrations = [
    "ALTER TABLE produtos ADD COLUMN IF NOT EXISTS imagem TEXT",
    "ALTER TABLE empresas ADD COLUMN IF NOT EXISTS foto_perfil TEXT",
    "ALTER TABLE empresas ADD COLUMN IF NOT EXISTS endereco TEXT",
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS endereco_entrega TEXT",
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS observacao TEXT",
    "ALTER TABLE pedido_itens ADD COLUMN IF NOT EXISTS observacao TEXT",
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS id_motoboy INT REFERENCES usuarios(id_usuario)",
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS quase_pronto BOOLEAN DEFAULT false",
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS tipo_entrega VARCHAR(20) DEFAULT NULL",
    "ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS status_motoboy VARCHAR(20) DEFAULT 'offline'",
    "INSERT INTO status_pedidos (id_status, nome) VALUES (6, 'Aguardando Motoboy') ON CONFLICT DO NOTHING",
    '''
      CREATE TABLE IF NOT EXISTS produto_adicionais (
        id_adicional SERIAL PRIMARY KEY,
        id_produto   INT NOT NULL,
        grupo        VARCHAR(100) NOT NULL DEFAULT 'Adicionais',
        maximo_grupo INT NOT NULL DEFAULT 3,
        obrigatorio  BOOLEAN NOT NULL DEFAULT false,
        nome         VARCHAR(150) NOT NULL,
        descricao    VARCHAR(200) NOT NULL DEFAULT '',
        preco        NUMERIC(10,2) NOT NULL DEFAULT 0,
        ativo        BOOLEAN NOT NULL DEFAULT true
      )
    ''',
  ];
  for (final sql in migrations) {
    try {
      await db.connection.execute(Sql.named(sql), parameters: {});
    } catch (e) {
      print('Aviso migração: $e');
    }
  }
  print('Migrações aplicadas');

  final auth        = AuthController(db.connection);
  final produto     = ProdutoController(db.connection);
  final pedido      = PedidoController(db.connection);
  final criarPedido = CriarPedidoController(db.connection);
  final adicional   = AdicionalController(db.connection);
  final empresa     = EmpresaController(db.connection);
  final motoboy     = MotoboyController(db.connection);

  final app = Router();

  app.get('/', (Request req) => Response.ok('Smarty Entregas API Rodando'));

  // OPTIONS preflight
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

  // ADICIONAIS
  app.get('/produtos/<id>/adicionais',  adicional.getAdicionais);
  app.post('/produtos/<id>/adicionais', adicional.createAdicional);
  app.delete('/adicionais/<id>',        adicional.deleteAdicional);

  // EMPRESAS
  app.patch('/empresas/<id>/foto',      empresa.atualizarFoto);
  app.get('/empresas/<id>/foto',        empresa.getFoto);

  // PEDIDOS
  app.post('/pedidos',                  criarPedido.criarPedido);
  app.get('/pedidos/empresa',           pedido.getPedidosByEmpresa);
  app.get('/pedidos/cliente',           pedido.getPedidosByCliente);
  app.get('/pedidos/<id>/detalhes',     pedido.getPedidoDetalhes);
  app.patch('/pedidos/<id>/status',     pedido.atualizarStatus);

  // MOTOBOY
  app.get('/motoboy/disponiveis',       motoboy.getDisponiveis);
  app.get('/motoboy/em-rota',           motoboy.getEmRota);
  app.get('/motoboy/historico',         motoboy.getHistorico);
  app.get('/motoboys/count',            motoboy.getMotoboyCount);
  app.post('/motoboy/aceitar',          motoboy.aceitarEntrega);
  app.patch('/motoboy/status',          motoboy.atualizarStatus);
  app.patch('/motoboy/meu-status',      motoboy.atualizarMeuStatus);
  app.patch('/pedidos/<id>/quase-pronto',    pedido.marcarQuasePronto);
  app.patch('/pedidos/<id>/chamar-motoboy',  pedido.chamarMotoboy);
  app.patch('/pedidos/<id>/entrega-propria', pedido.entregaPropria);

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
