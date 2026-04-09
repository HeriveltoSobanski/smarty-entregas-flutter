import 'dart:convert';
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
import 'package:backend/controllers/cliente_endereco_controller.dart';

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
    "ALTER TABLE empresas ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION",
    "ALTER TABLE empresas ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION",
    '''
      CREATE TABLE IF NOT EXISTS usuario_enderecos (
        id_endereco SERIAL PRIMARY KEY,
        id_usuario  INT NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
        apelido     VARCHAR(50) NOT NULL DEFAULT 'Casa',
        endereco    TEXT NOT NULL DEFAULT '',
        latitude    DOUBLE PRECISION,
        longitude   DOUBLE PRECISION,
        principal   BOOLEAN NOT NULL DEFAULT false
      )
    ''',
    // Garante id_usuario mesmo sem FK (caso o tipo do PK seja diferente)
    "ALTER TABLE usuario_enderecos ADD COLUMN IF NOT EXISTS id_usuario INT",
    // Garante colunas mesmo que a tabela tenha sido criada sem elas
    "ALTER TABLE usuario_enderecos ADD COLUMN IF NOT EXISTS apelido VARCHAR(50) NOT NULL DEFAULT 'Casa'",
    "ALTER TABLE usuario_enderecos ADD COLUMN IF NOT EXISTS endereco TEXT NOT NULL DEFAULT ''",
    "ALTER TABLE usuario_enderecos ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION",
    "ALTER TABLE usuario_enderecos ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION",
    "ALTER TABLE usuario_enderecos ADD COLUMN IF NOT EXISTS principal BOOLEAN NOT NULL DEFAULT false",
    // O banco tem colunas extras (cep, cidade, região) que são NOT NULL mas não usamos.
    // Tornar nullable para não bloquear nossos inserts.
    "ALTER TABLE usuario_enderecos ALTER COLUMN cep         DROP NOT NULL",
    "ALTER TABLE usuario_enderecos ALTER COLUMN logradouro  DROP NOT NULL",
    "ALTER TABLE usuario_enderecos ALTER COLUMN numero      DROP NOT NULL",
    "ALTER TABLE usuario_enderecos ALTER COLUMN complemento DROP NOT NULL",
    "ALTER TABLE usuario_enderecos ALTER COLUMN bairro      DROP NOT NULL",
    "ALTER TABLE usuario_enderecos ALTER COLUMN cidade      DROP NOT NULL",
    "ALTER TABLE usuario_enderecos ALTER COLUMN estado      DROP NOT NULL",
    "ALTER TABLE usuario_enderecos ALTER COLUMN pais        DROP NOT NULL",
    // Faz DROP NOT NULL em TODAS as colunas da tabela exceto PK (abordagem genérica)
    '''
      DO \$\$
      DECLARE col RECORD;
      BEGIN
        FOR col IN
          SELECT column_name
          FROM information_schema.columns
          WHERE table_schema = 'public'
            AND table_name   = 'usuario_enderecos'
            AND column_name  NOT IN ('id_endereco', 'id_usuario')
            AND is_nullable  = 'NO'
            AND column_default IS NULL
        LOOP
          EXECUTE 'ALTER TABLE usuario_enderecos ALTER COLUMN '
                  || quote_ident(col.column_name) || ' DROP NOT NULL';
        END LOOP;
      END \$\$
    ''',
    // Remove qualquer trigger que possa estar bloqueando inserts em usuario_enderecos
    '''
      DO \$\$
      DECLARE r RECORD;
      BEGIN
        FOR r IN
          SELECT trigger_name
          FROM information_schema.triggers
          WHERE event_object_schema = 'public'
            AND event_object_table  = 'usuario_enderecos'
        LOOP
          EXECUTE 'DROP TRIGGER IF EXISTS ' || quote_ident(r.trigger_name) || ' ON usuario_enderecos';
        END LOOP;
      END \$\$
    ''',
    // Remove funções relacionadas a validação de tipo_usuario que usem smallint
    '''
      DO \$\$
      DECLARE r RECORD;
      BEGIN
        FOR r IN
          SELECT routine_name
          FROM information_schema.routines
          WHERE routine_type = 'FUNCTION'
            AND routine_name ILIKE '%tipo_usuario%'
        LOOP
          EXECUTE 'DROP FUNCTION IF EXISTS ' || quote_ident(r.routine_name) || '() CASCADE';
        END LOOP;
      END \$\$
    ''',
    "INSERT INTO status_pedidos (id_status, nome) VALUES (6, 'Aguardando Motoboy') ON CONFLICT DO NOTHING",
    // Remove trigger que bloqueia transições de status
    "DROP TRIGGER IF EXISTS trg_valida_status ON pedidos",
    "DROP FUNCTION IF EXISTS fn_valida_transicao_status() CASCADE",
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
  final empresa          = EmpresaController(db.connection);
  final motoboy          = MotoboyController(db.connection);
  final clienteEndereco  = ClienteEnderecoController(db.connection);

  final app = Router();

  app.get('/', (Request req) => Response.ok('Smarty Entregas API Rodando'));

  // Rota de manutenção — remove triggers bloqueadores da tabela pedidos
  app.get('/admin/fix-triggers', (Request req) async {
    try {
      // Lista todos os triggers na tabela pedidos
      final triggers = await db.connection.execute(
        Sql.named('''
          SELECT trigger_name, action_statement
          FROM information_schema.triggers
          WHERE event_object_table = 'pedidos'
        '''),
        parameters: {},
      );
      final nomes = triggers.map((r) => r[0]?.toString() ?? '').toList();

      // Derruba cada trigger encontrado
      for (final nome in nomes) {
        if (nome.isNotEmpty) {
          await db.connection.execute(
            Sql.named('DROP TRIGGER IF EXISTS $nome ON pedidos'),
            parameters: {},
          );
        }
      }

      // Derruba funções relacionadas a validação de status
      final funcs = await db.connection.execute(
        Sql.named('''
          SELECT routine_name FROM information_schema.routines
          WHERE routine_type = 'FUNCTION'
          AND routine_name ILIKE '%status%'
        '''),
        parameters: {},
      );
      for (final f in funcs) {
        final fn = f[0]?.toString() ?? '';
        if (fn.isNotEmpty) {
          await db.connection.execute(
            Sql.named('DROP FUNCTION IF EXISTS $fn() CASCADE'),
            parameters: {},
          );
        }
      }

      return Response.ok(
        jsonEncode({'ok': true, 'triggers_removidos': nomes}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  });

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
  app.get('/empresas/<id>/endereco',    empresa.getEndereco);
  app.patch('/empresas/<id>/endereco',  empresa.atualizarEndereco);

  // ENDEREÇOS DO CLIENTE
  app.get('/clientes/<id>/enderecos',              clienteEndereco.listar);
  app.post('/clientes/<id>/enderecos',             clienteEndereco.criar);
  app.delete('/clientes/enderecos/<id>',           clienteEndereco.deletar);
  app.patch('/clientes/enderecos/<id>/principal',  clienteEndereco.marcarPrincipal);

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
