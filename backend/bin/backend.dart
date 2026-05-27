import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
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
import 'package:backend/controllers/empresa_motoboy_controller.dart';
import 'package:backend/controllers/avaliacao_controller.dart';
import 'package:backend/controllers/notificacao_controller.dart';
import 'package:backend/controllers/pizza_controller.dart';
import 'package:backend/controllers/dispositivo_controller.dart';
import 'package:backend/controllers/relatorio_controller.dart';
import 'package:backend/controllers/cupom_controller.dart';
import 'package:backend/services/fcm_service.dart';
import 'package:backend/services/jwt_service.dart';
import 'package:backend/services/email_service.dart';
import 'package:backend/services/image_service.dart';
import 'package:backend/services/mercadopago_service.dart';
import 'package:backend/middleware/jwt_middleware.dart';

void main() async {
  final env = DotEnv(includePlatformEnvironment: true)..load();

  final jwtSecret = env['JWT_SECRET'];
  if (jwtSecret == null || jwtSecret.isEmpty) {
    throw Exception('JWT_SECRET nao encontrado no .env — servidor nao pode iniciar sem este valor.');
  }

  final mapboxToken = env['MAPBOX_TOKEN'] ?? '';
  final gmailUser = env['GMAIL_USER'] ?? '';
  final gmailPass = env['GMAIL_APP_PASSWORD'] ?? '';
  final jwtService   = JwtService(jwtSecret);
  final emailService = EmailService(gmailUser, gmailPass);

  final mpAccessToken = env['MP_ACCESS_TOKEN'] ?? '';
  final mpService = MercadoPagoService(mpAccessToken);

  // Diretório public/ relativo ao local onde o binário roda (backend/)
  final publicDir = p.join(Directory.current.path, 'public');
  await Directory(p.join(publicDir, 'uploads', 'imagens')).create(recursive: true);
  final imageService = ImageService(publicDir);

  final fcmService = FcmService(
    projectId:           env['FCM_PROJECT_ID']            ?? '',
    serviceAccountEmail: env['FCM_SERVICE_ACCOUNT_EMAIL'] ?? '',
    privateKey:          (env['FCM_PRIVATE_KEY']          ?? '').replaceAll(r'\n', '\n'),
  );

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
    "ALTER TABLE empresas ADD COLUMN IF NOT EXISTS foto_capa TEXT",
    "ALTER TABLE empresas ADD COLUMN IF NOT EXISTS endereco TEXT",
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS endereco_entrega TEXT",
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS observacao TEXT",
    "ALTER TABLE pedido_itens ADD COLUMN IF NOT EXISTS observacao TEXT",
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS id_motoboy INT REFERENCES usuarios(id_usuario)",
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS quase_pronto BOOLEAN DEFAULT false",
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS tipo_entrega VARCHAR(20) DEFAULT NULL",
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS forma_pagamento VARCHAR(30) DEFAULT NULL",
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS troco_para NUMERIC(10,2) DEFAULT NULL",
    '''
      CREATE TABLE IF NOT EXISTS empresa_motoboys (
        id_motoboy_empresa SERIAL PRIMARY KEY,
        id_empresa         INT NOT NULL REFERENCES empresas(id_empresa) ON DELETE CASCADE,
        nome               VARCHAR(100) NOT NULL,
        telefone           VARCHAR(20) NOT NULL DEFAULT '',
        ativo              BOOLEAN NOT NULL DEFAULT true
      )
    ''',
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS motoboy_empresa_nome VARCHAR(100) DEFAULT NULL",
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS motoboy_empresa_telefone VARCHAR(20) DEFAULT NULL",
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
    "ALTER TABLE usuario_enderecos ADD COLUMN IF NOT EXISTS id_usuario INT",
    "ALTER TABLE usuario_enderecos ADD COLUMN IF NOT EXISTS apelido VARCHAR(50) NOT NULL DEFAULT 'Casa'",
    "ALTER TABLE usuario_enderecos ADD COLUMN IF NOT EXISTS endereco TEXT NOT NULL DEFAULT ''",
    "ALTER TABLE usuario_enderecos ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION",
    "ALTER TABLE usuario_enderecos ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION",
    "ALTER TABLE usuario_enderecos ADD COLUMN IF NOT EXISTS principal BOOLEAN NOT NULL DEFAULT false",
    "ALTER TABLE usuario_enderecos ALTER COLUMN cep         DROP NOT NULL",
    "ALTER TABLE usuario_enderecos ALTER COLUMN logradouro  DROP NOT NULL",
    "ALTER TABLE usuario_enderecos ALTER COLUMN numero      DROP NOT NULL",
    "ALTER TABLE usuario_enderecos ALTER COLUMN complemento DROP NOT NULL",
    "ALTER TABLE usuario_enderecos ALTER COLUMN bairro      DROP NOT NULL",
    "ALTER TABLE usuario_enderecos ALTER COLUMN cidade      DROP NOT NULL",
    "ALTER TABLE usuario_enderecos ALTER COLUMN estado      DROP NOT NULL",
    "ALTER TABLE usuario_enderecos ALTER COLUMN pais        DROP NOT NULL",
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
    "INSERT INTO status_pedidos (id_status, nome) VALUES (1, 'Aguardando')        ON CONFLICT (id_status) DO UPDATE SET nome = EXCLUDED.nome",
    "INSERT INTO status_pedidos (id_status, nome) VALUES (2, 'Em Preparo')        ON CONFLICT (id_status) DO UPDATE SET nome = EXCLUDED.nome",
    "INSERT INTO status_pedidos (id_status, nome) VALUES (3, 'A Caminho')         ON CONFLICT (id_status) DO UPDATE SET nome = EXCLUDED.nome",
    "INSERT INTO status_pedidos (id_status, nome) VALUES (4, 'Entregue')          ON CONFLICT (id_status) DO UPDATE SET nome = EXCLUDED.nome",
    "INSERT INTO status_pedidos (id_status, nome) VALUES (5, 'Cancelado')         ON CONFLICT (id_status) DO UPDATE SET nome = EXCLUDED.nome",
    "INSERT INTO status_pedidos (id_status, nome) VALUES (6, 'Aguardando Motoboy') ON CONFLICT (id_status) DO UPDATE SET nome = EXCLUDED.nome",
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
    // Aumenta o campo senha para suportar o formato hash v1:salt:sha256
    "ALTER TABLE usuarios ALTER COLUMN senha TYPE VARCHAR(200)",
    // Vincula motoboys da empresa a usuários reais
    "ALTER TABLE empresa_motoboys ADD COLUMN IF NOT EXISTS id_usuario INT REFERENCES usuarios(id_usuario)",
    "ALTER TABLE empresa_motoboys ALTER COLUMN nome     DROP NOT NULL",
    "ALTER TABLE empresa_motoboys ALTER COLUMN telefone DROP NOT NULL",
    // Notificações in-app
    '''
      CREATE TABLE IF NOT EXISTS notificacoes (
        id         SERIAL PRIMARY KEY,
        id_usuario INT NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
        titulo     VARCHAR(100) NOT NULL,
        corpo      TEXT NOT NULL,
        tipo       VARCHAR(30) NOT NULL DEFAULT 'status_pedido',
        lida       BOOLEAN NOT NULL DEFAULT false,
        id_pedido  INT REFERENCES pedidos(id_pedido) ON DELETE SET NULL,
        criado_em  TIMESTAMP NOT NULL DEFAULT NOW()
      )
    ''',
    "CREATE INDEX IF NOT EXISTS idx_notif_usuario ON notificacoes (id_usuario, lida, criado_em DESC)",
    // Critérios de avaliação
    "ALTER TABLE avaliacoes ADD COLUMN IF NOT EXISTS rapidez          BOOLEAN",
    "ALTER TABLE avaliacoes ADD COLUMN IF NOT EXISTS educacao          BOOLEAN",
    "ALTER TABLE avaliacoes ADD COLUMN IF NOT EXISTS cuidado           BOOLEAN",
    "ALTER TABLE avaliacoes ADD COLUMN IF NOT EXISTS sabor             BOOLEAN",
    "ALTER TABLE avaliacoes ADD COLUMN IF NOT EXISTS embalagem         BOOLEAN",
    "ALTER TABLE avaliacoes ADD COLUMN IF NOT EXISTS pedido_correto    BOOLEAN",
    "ALTER TABLE avaliacoes ADD COLUMN IF NOT EXISTS comentario_entrega TEXT",
    // Recuperação de senha
    '''
      CREATE TABLE IF NOT EXISTS recuperacao_senha (
        id        SERIAL PRIMARY KEY,
        email     VARCHAR(200) NOT NULL,
        codigo    VARCHAR(6)   NOT NULL,
        expira_em TIMESTAMP    NOT NULL,
        usado     BOOLEAN      NOT NULL DEFAULT false
      )
    ''',
    // Avaliações de restaurantes e motoboys
    '''
      CREATE TABLE IF NOT EXISTS avaliacoes (
        id_avaliacao  SERIAL PRIMARY KEY,
        id_pedido     INT NOT NULL REFERENCES pedidos(id_pedido),
        id_usuario    INT NOT NULL REFERENCES usuarios(id_usuario),
        id_empresa    INT NOT NULL REFERENCES empresas(id_empresa),
        id_motoboy    INT REFERENCES usuarios(id_usuario),
        nota_empresa  SMALLINT NOT NULL CHECK (nota_empresa BETWEEN 1 AND 5),
        nota_motoboy  SMALLINT CHECK (nota_motoboy BETWEEN 1 AND 5),
        comentario    TEXT,
        criado_em     TIMESTAMP DEFAULT NOW(),
        UNIQUE (id_pedido, id_usuario)
      )
    ''',
    // Taxa de entrega por pedido e tempo de preparo do restaurante
    "ALTER TABLE empresas ADD COLUMN IF NOT EXISTS tempo_preparo INT DEFAULT 30",
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS taxa_entrega NUMERIC(10,2) DEFAULT 0",
    // Taxa mínima de entrega configurável por restaurante
    "ALTER TABLE empresas ADD COLUMN IF NOT EXISTS taxa_minima NUMERIC(10,2) DEFAULT 7.00",
    // Sistema de pizza
    "ALTER TABLE produtos ADD COLUMN IF NOT EXISTS is_pizza BOOLEAN DEFAULT false",
    "ALTER TABLE produtos ADD COLUMN IF NOT EXISTS pizza_meio_a_meio BOOLEAN DEFAULT false",
    "ALTER TABLE produtos ADD COLUMN IF NOT EXISTS pizza_tres_sabores BOOLEAN DEFAULT false",
    '''
      CREATE TABLE IF NOT EXISTS pizza_sabores (
        id_sabor    SERIAL PRIMARY KEY,
        id_produto  INT NOT NULL REFERENCES produtos(id_produto) ON DELETE CASCADE,
        nome        VARCHAR(100) NOT NULL,
        descricao   TEXT NOT NULL DEFAULT '',
        preco       NUMERIC(10,2) NOT NULL DEFAULT 0,
        ativo       BOOLEAN NOT NULL DEFAULT true
      )
    ''',
    // Migração: mover pizza_sabores de id_empresa para id_produto (se tabela já existia)
    "ALTER TABLE pizza_sabores DROP COLUMN IF EXISTS id_empresa",
    "ALTER TABLE pizza_sabores ADD COLUMN IF NOT EXISTS id_produto INT REFERENCES produtos(id_produto) ON DELETE CASCADE",
    // FCM tokens por dispositivo
    '''
      CREATE TABLE IF NOT EXISTS dispositivos_fcm (
        id            SERIAL PRIMARY KEY,
        id_usuario    INT NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
        fcm_token     TEXT NOT NULL,
        plataforma    VARCHAR(10) NOT NULL DEFAULT 'android',
        atualizado_em TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT uq_fcm_token UNIQUE (fcm_token)
      )
    ''',
    "CREATE INDEX IF NOT EXISTS idx_fcm_usuario ON dispositivos_fcm (id_usuario)",
    // Sistema de cupons globais
    '''
      CREATE TABLE IF NOT EXISTS cupons (
        id_cupom      SERIAL PRIMARY KEY,
        codigo        VARCHAR(30) NOT NULL UNIQUE,
        tipo          VARCHAR(10) NOT NULL DEFAULT 'percentual',
        valor         NUMERIC(10,2) NOT NULL,
        valor_minimo  NUMERIC(10,2) NOT NULL DEFAULT 0,
        usos_maximos  INT,
        usos_atuais   INT NOT NULL DEFAULT 0,
        ativo         BOOLEAN NOT NULL DEFAULT true,
        valido_ate    TIMESTAMP,
        criado_em     TIMESTAMP NOT NULL DEFAULT NOW()
      )
    ''',
    // Cupom aplicado ao pedido
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS codigo_cupom VARCHAR(30)",
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS desconto NUMERIC(10,2) NOT NULL DEFAULT 0",
    // Rate limiting persistente
    '''
      CREATE TABLE IF NOT EXISTS login_attempts (
        chave        VARCHAR(200) PRIMARY KEY,
        tentativas   INT NOT NULL DEFAULT 1,
        bloqueado_ate TIMESTAMPTZ NOT NULL
      )
    ''',
    // Pagamento via Mercado Pago
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS id_pagamento_mp VARCHAR(50)",
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS status_pagamento VARCHAR(30) NOT NULL DEFAULT 'pendente'",
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS qr_code_pix TEXT",
    // Saldo (caixa) da empresa para pagamentos em dinheiro
    "ALTER TABLE empresas ADD COLUMN IF NOT EXISTS saldo NUMERIC(10,2) NOT NULL DEFAULT 0",
    '''
      CREATE TABLE IF NOT EXISTS empresa_transacoes (
        id            SERIAL PRIMARY KEY,
        id_empresa    INT NOT NULL REFERENCES empresas(id_empresa) ON DELETE CASCADE,
        tipo          VARCHAR(20) NOT NULL,
        valor         NUMERIC(10,2) NOT NULL,
        descricao     TEXT NOT NULL DEFAULT '',
        id_pedido     INT REFERENCES pedidos(id_pedido) ON DELETE SET NULL,
        criado_em     TIMESTAMP NOT NULL DEFAULT NOW()
      )
    ''',
    // Carteira do motoboy
    "ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS saldo_motoboy NUMERIC(10,2) NOT NULL DEFAULT 0",
    // Garante que tabela categorias existe com unique constraint para ON CONFLICT
    '''
      CREATE TABLE IF NOT EXISTS categorias (
        id_categoria SERIAL PRIMARY KEY,
        nome         VARCHAR(100) NOT NULL
      )
    ''',
    // Remove duplicatas antes de criar o índice único
    '''
      DELETE FROM categorias c1
      USING categorias c2
      WHERE c1.id_categoria > c2.id_categoria
        AND c1.nome = c2.nome
    ''',
    "CREATE UNIQUE INDEX IF NOT EXISTS uq_categorias_nome ON categorias(nome)",
    // Cria linha em empresas para usuários empresa que não têm — sem ON CONFLICT para não depender de unique index
    '''
      INSERT INTO empresas (id_usuario)
      SELECT u.id_usuario FROM usuarios u
      WHERE u.tipo_usuario = 'empresa'
        AND NOT EXISTS (SELECT 1 FROM empresas e WHERE e.id_usuario = u.id_usuario)
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

  // Converte imagens base64 antigas para arquivos em disco
  await imageService.migrarBanco(db.connection);

  final auth           = AuthController(db.connection, jwtService, emailService);
  final produto        = ProdutoController(db.connection, imageService);
  final pedido         = PedidoController(db.connection, fcmService: fcmService);
  final criarPedido    = CriarPedidoController(db.connection, mpService);
  final adicional      = AdicionalController(db.connection);
  final empresa        = EmpresaController(db.connection, imageService);
  final motoboy        = MotoboyController(db.connection);
  final clienteEndereco  = ClienteEnderecoController(db.connection);
  final empresaMotoboy   = EmpresaMotoboyController(db.connection);
  final avaliacao        = AvaliacaoController(db.connection);
  final notificacao      = NotificacaoController(db.connection);
  final pizza            = PizzaController(db.connection);
  final dispositivo      = DispositivoController(db.connection);
  final relatorio        = RelatorioController(db.connection);
  final cupom            = CupomController(db.connection);

  final app = Router();

  app.get('/', (Request req) => Response.ok('Smarty Entregas API'));
  app.get('/health', (Request req) => Response.ok('ok'));

  // OPTIONS preflight
  app.options('/<ignored|.*>', (Request req) => Response.ok(''));

  // ── AUTH (públicas) ──────────────────────────────────────────
  app.post('/auth/login',              auth.login);
  app.post('/auth/google',             auth.loginGoogle);
  app.post('/auth/facebook',           auth.loginFacebook);
  app.post('/auth/register/cliente',   auth.registerCliente);
  app.post('/auth/register/empresa',   auth.registerEmpresa);
  app.post('/auth/register/motoboy',   auth.registerMotoboy);
  app.get('/usuarios/<id>/perfil',     auth.getPerfil);
  app.patch('/usuarios/<id>/perfil',   auth.atualizarPerfil);
  // ── NOTIFICAÇÕES ─────────────────────────────────────────────
  app.get('/notificacoes',                  notificacao.listar);
  app.get('/notificacoes/nao-lidas',        notificacao.contarNaoLidas);
  app.patch('/notificacoes/<id>/lida',      notificacao.marcarLida);
  app.patch('/notificacoes/todas-lidas',    notificacao.marcarTodasLidas);

  // ── DISPOSITIVOS / FCM ───────────────────────────────────────
  app.post('/dispositivos/fcm-token',       dispositivo.registrarFcmToken);

  app.post('/auth/refresh',            auth.refresh);
  app.post('/auth/esqueci-senha',      auth.esqueciSenha);
  app.post('/auth/verificar-codigo',   auth.verificarCodigo);
  app.post('/auth/redefinir-senha',    auth.redefinirSenha);

  // ── PRODUTOS ─────────────────────────────────────────────────
  app.get('/produtos/categorias',      produto.getCategorias);
  app.get('/produtos/busca',           produto.buscarProdutos);
  app.get('/produtos/empresa',         produto.getProdutosByEmpresa);
  app.get('/produtos/publico',         produto.getProdutosPublico);
  app.get('/produtos/empresas',        produto.getEmpresasComProdutos);
  app.post('/produtos',                produto.createProduto);
  app.put('/produtos/<id>',            produto.updateProduto);
  app.delete('/produtos/<id>',         produto.deleteProduto);
  app.patch('/produtos/<id>/ativo',    produto.toggleAtivo);

  // ── ADICIONAIS ───────────────────────────────────────────────
  app.get('/produtos/<id>/adicionais',  adicional.getAdicionais);
  app.post('/produtos/<id>/adicionais', adicional.createAdicional);
  app.delete('/adicionais/<id>',        adicional.deleteAdicional);

  // ── PIZZA ────────────────────────────────────────────────────
  app.get('/produtos/<id>/pizza/sabores',  pizza.getSabores);
  app.post('/produtos/<id>/pizza/sabores', pizza.createSabor);
  app.patch('/pizza/sabores/<id>',         pizza.updateSabor);
  app.delete('/pizza/sabores/<id>',        pizza.deleteSabor);

  // ── EMPRESAS ─────────────────────────────────────────────────
  app.patch('/empresas/<id>/foto',           empresa.atualizarFoto);
  app.get('/empresas/<id>/foto',             empresa.getFoto);
  app.get('/empresas/<id>/endereco',         empresa.getEndereco);
  app.patch('/empresas/<id>/endereco',       empresa.atualizarEndereco);
  app.get('/empresas/<id>/configuracoes',    empresa.getConfiguracoes);
  app.patch('/empresas/<id>/configuracoes',  empresa.atualizarConfiguracoes);
  app.get('/empresas/relatorio',             relatorio.getRelatorio);

  // ── ENDEREÇOS DO CLIENTE ─────────────────────────────────────
  app.get('/clientes/<id>/enderecos',              clienteEndereco.listar);
  app.post('/clientes/<id>/enderecos',             clienteEndereco.criar);
  app.delete('/clientes/enderecos/<id>',           clienteEndereco.deletar);
  app.patch('/clientes/enderecos/<id>/principal',  clienteEndereco.marcarPrincipal);

  // ── PEDIDOS ──────────────────────────────────────────────────
  app.post('/pedidos',                  criarPedido.criarPedido);
  app.get('/pedidos/empresa',           pedido.getPedidosByEmpresa);
  app.get('/pedidos/cliente',           pedido.getPedidosByCliente);
  app.get('/pedidos/<id>/detalhes',     pedido.getPedidoDetalhes);
  app.patch('/pedidos/<id>/status',     pedido.atualizarStatus);
  app.patch('/pedidos/<id>/quase-pronto',    pedido.marcarQuasePronto);
  app.patch('/pedidos/<id>/chamar-motoboy',  pedido.chamarMotoboy);
  app.patch('/pedidos/<id>/entrega-propria', pedido.entregaPropria);
  app.patch('/pedidos/<id>/entrega-propria-motoboy', empresaMotoboy.atribuirMotoboy);

  // ── CUPONS ───────────────────────────────────────────────────
  app.post('/cupons/validar',            cupom.validar);
  app.post('/cupons',                    cupom.criar);
  app.get('/cupons',                     cupom.listar);
  app.patch('/cupons/<codigo>/ativo',    cupom.toggleAtivo);

  // ── PAGAMENTOS / MERCADO PAGO ────────────────────────────────
  // Consulta status do pagamento de um pedido
  app.get('/pedidos/<id>/pagamento', (Request req, String id) async {
    final idPedido = int.tryParse(id);
    if (idPedido == null) return _json(400, {'error': 'id inválido'});

    final result = await db.connection.execute(
      Sql.named('''
        SELECT id_pagamento_mp, status_pagamento, qr_code_pix
        FROM pedidos WHERE id_pedido = @id
      '''),
      parameters: {'id': idPedido},
    );
    if (result.isEmpty) return _json(404, {'error': 'Pedido não encontrado'});

    final row = result.first;
    final idMp = row[0]?.toString();

    // Se tem pagamento MP e está pendente, consulta status atualizado
    if (idMp != null && row[1]?.toString() == 'pending') {
      try {
        final mpStatus = await mpService.consultarPagamento(idMp);
        final novoStatus = mpStatus['status_pagamento'] as String;
        if (novoStatus != 'pending') {
          await db.connection.execute(
            Sql.named('UPDATE pedidos SET status_pagamento = @s WHERE id_pedido = @id'),
            parameters: {'s': novoStatus, 'id': idPedido},
          );
          return _json(200, {
            'id_pagamento_mp': idMp,
            'status_pagamento': novoStatus,
            'qr_code_pix': row[2]?.toString(),
          });
        }
      } catch (_) {}
    }

    return _json(200, {
      'id_pagamento_mp': idMp,
      'status_pagamento': row[1]?.toString() ?? 'pendente',
      'qr_code_pix': row[2]?.toString(),
    });
  });

  // Webhook do Mercado Pago — notifica quando pagamento é aprovado/rejeitado
  app.post('/pagamentos/webhook', (Request req) async {
    try {
      final bodyStr = await req.readAsString();
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;

      final tipo = body['type']?.toString();
      if (tipo != 'payment') return Response.ok('ok');

      final idMp = body['data']?['id']?.toString();
      if (idMp == null) return Response.ok('ok');

      final mpStatus = await mpService.consultarPagamento(idMp);
      final status   = mpStatus['status_pagamento'] as String;

      await db.connection.execute(
        Sql.named('UPDATE pedidos SET status_pagamento = @s WHERE id_pagamento_mp = @id_mp'),
        parameters: {'s': status, 'id_mp': idMp},
      );

      return Response.ok('ok');
    } catch (_) {
      return Response.ok('ok');
    }
  });

  // ── SALDO DA EMPRESA (caixa para dinheiro) ───────────────────
  app.get('/empresas/<id>/saldo', (Request req, String id) async {
    final idEmpresa = int.tryParse(id);
    if (idEmpresa == null) return _json(400, {'error': 'id inválido'});

    final result = await db.connection.execute(
      Sql.named('SELECT saldo FROM empresas WHERE id_empresa = @id'),
      parameters: {'id': idEmpresa},
    );
    if (result.isEmpty) return _json(404, {'error': 'Empresa não encontrada'});

    final saldo = (result.first[0] as num?)?.toDouble() ?? 0.0;
    return _json(200, {'saldo': saldo});
  });

  app.get('/empresas/<id>/extrato', (Request req, String id) async {
    final idEmpresa = int.tryParse(id);
    if (idEmpresa == null) return _json(400, {'error': 'id inválido'});

    final result = await db.connection.execute(
      Sql.named('''
        SELECT tipo, valor, descricao, id_pedido, criado_em
        FROM empresa_transacoes
        WHERE id_empresa = @id
        ORDER BY criado_em DESC
        LIMIT 50
      '''),
      parameters: {'id': idEmpresa},
    );

    final transacoes = result.map((r) => {
      'tipo':      r[0]?.toString(),
      'valor':     (r[1] as num?)?.toDouble(),
      'descricao': r[2]?.toString(),
      'id_pedido': r[3],
      'criado_em': r[4]?.toString(),
    }).toList();

    return _json(200, {'transacoes': transacoes});
  });

  // Empresa deposita saldo via PIX (gera QR para pagar à Smarty)
  app.post('/empresas/<id>/depositar', (Request req, String id) async {
    final idEmpresa = int.tryParse(id);
    if (idEmpresa == null) return _json(400, {'error': 'id inválido'});

    try {
      final bodyStr = await req.readAsString();
      final body    = jsonDecode(bodyStr) as Map<String, dynamic>;
      final valor   = (body['valor'] as num?)?.toDouble();

      if (valor == null || valor < 10) {
        return _json(400, {'error': 'Valor mínimo de depósito é R\$ 10,00'});
      }

      final empResult = await db.connection.execute(
        Sql.named('SELECT nome FROM empresas WHERE id_empresa = @id'),
        parameters: {'id': idEmpresa},
      );
      if (empResult.isEmpty) return _json(404, {'error': 'Empresa não encontrada'});

      final nomeEmpresa = empResult.first[0]?.toString() ?? 'Empresa';
      final mpResult = await mpService.criarPagamentoPix(
        valor:        valor,
        descricao:    'Depósito de saldo - $nomeEmpresa',
        emailPagador: 'empresa$idEmpresa@smartyentregas.com',
        idPedido:     idEmpresa * -1,
      );

      // Registra depósito pendente como transação
      await db.connection.execute(
        Sql.named('''
          INSERT INTO empresa_transacoes (id_empresa, tipo, valor, descricao)
          VALUES (@id_empresa, 'deposito_pendente', @valor, @desc)
        '''),
        parameters: {
          'id_empresa': idEmpresa,
          'valor':      valor,
          'desc':       'Depósito via PIX - MP: ${mpResult['id_pagamento_mp']}',
        },
      );

      return _json(201, {
        'qr_code_pix':    mpResult['qr_code_pix'],
        'qr_code_base64': mpResult['qr_code_base64'],
        'id_pagamento_mp': mpResult['id_pagamento_mp'],
        'valor':          valor,
      });
    } catch (e) {
      return _json(500, {'error': 'Erro ao gerar PIX de depósito', 'details': e.toString()});
    }
  });

  // ── AVALIAÇÕES ───────────────────────────────────────────────
  app.post('/avaliacoes',                    avaliacao.criar);
  app.get('/pedidos/<id>/avaliacao',         avaliacao.verificar);
  app.get('/empresas/<id>/avaliacao',        avaliacao.getEmpresa);

  // ── MOTOBOYS DA EMPRESA ──────────────────────────────────────
  app.get('/motoboys/buscar',              empresaMotoboy.buscarPorId);
  app.get('/empresas/<id>/motoboys',       empresaMotoboy.listar);
  app.post('/empresas/<id>/motoboys',      empresaMotoboy.criar);
  app.delete('/empresas/motoboys/<id>',    empresaMotoboy.deletar);

  // ── MOTOBOY ──────────────────────────────────────────────────
  app.get('/motoboy/disponiveis',       motoboy.getDisponiveis);
  app.get('/motoboy/em-rota',           motoboy.getEmRota);
  app.get('/motoboy/historico',         motoboy.getHistorico);
  app.get('/motoboys/count',            motoboy.getMotoboyCount);
  app.post('/motoboy/aceitar',          motoboy.aceitarEntrega);
  app.patch('/motoboy/status',          motoboy.atualizarStatus);
  app.patch('/motoboy/meu-status',      motoboy.atualizarMeuStatus);

  // ── MAPA / PROXY MAPBOX ──────────────────────────────────────
  // Mantém o token no servidor — o app Flutter não precisa saber a chave.
  app.get('/mapa/rota', (Request req) async {
    try {
      final params    = req.url.queryParameters;
      final origemLat = params['origemLat'] ?? '';
      final origemLng = params['origemLng'] ?? '';
      final destLat   = params['destLat'] ?? '';
      final destLng   = params['destLng'] ?? '';

      if ([origemLat, origemLng, destLat, destLng].any((s) => s.isEmpty)) {
        return _json(400, {'error': 'Parâmetros origemLat, origemLng, destLat, destLng são obrigatórios'});
      }

      if (mapboxToken.isEmpty) {
        return _json(503, {'error': 'Serviço de rotas não configurado'});
      }

      // Mapbox Directions API — coordenadas em ordem lon,lat
      final coords = '$origemLng,$origemLat;$destLng,$destLat';
      final uri = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/$coords'
        '?geometries=geojson'
        '&overview=full'
        '&access_token=$mapboxToken',
      );

      final mbResp = await http.get(uri);

      return Response(
        mbResp.statusCode,
        body: mbResp.body,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return _json(500, {'error': 'Erro ao calcular rota'});
    }
  });

  // ── MANUTENÇÃO ───────────────────────────────────────────────
  app.get('/admin/fix-triggers', (Request req) async {
    if (req.context['tipoUsuario'] != 'admin') {
      return _json(403, {'error': 'Acesso negado'});
    }
    try {
      final triggers = await db.connection.execute(
        Sql.named('''
          SELECT trigger_name FROM information_schema.triggers
          WHERE event_object_table = 'pedidos'
        '''),
        parameters: {},
      );
      final nomes = triggers.map((r) => r[0]?.toString() ?? '').toList();
      for (final nome in nomes) {
        if (nome.isNotEmpty) {
          await db.connection.execute(
            Sql.named('DROP TRIGGER IF EXISTS $nome ON pedidos'),
            parameters: {},
          );
        }
      }
      return Response.ok(
        jsonEncode({'ok': true, 'triggers_removidos': nomes}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  });

  final overrideHeaders = {
    'Access-Control-Allow-Origin':  '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization, ngrok-skip-browser-warning',
  };

  // Handler de arquivos estáticos (sem JWT)
  final staticFiles = createStaticHandler(publicDir, serveFilesOutsidePath: false);

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders(headers: overrideHeaders))
      .addHandler((Request req) {
        // /uploads/* e webhook do MP servidos sem JWT
        if (req.url.path.startsWith('uploads/')) return staticFiles(req);
        if (req.url.path == 'pagamentos/webhook') return app.call(req);
        return Pipeline()
            .addMiddleware(jwtMiddleware(jwtService))
            .addHandler(app.call)
            .call(req);
      });

  final port = int.tryParse(env['PORT'] ?? '') ?? 8081;
  final server = await serve(handler, InternetAddress.anyIPv4, port);
  print('Servidor online em http://${server.address.host}:${server.port}');
}

Response _json(int status, Map<String, dynamic> body) => Response(
      status,
      body: jsonEncode(body),
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
