-- ============================================================
-- SMARTY ENTREGAS — Schema completo para Supabase
-- Execute este arquivo no SQL Editor do Supabase
-- ============================================================

-- ── TIPOS DE USUÁRIO ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS usuarios (
  id_usuario  SERIAL PRIMARY KEY,
  nome        VARCHAR(100) NOT NULL,
  email       VARCHAR(200) NOT NULL UNIQUE,
  senha       VARCHAR(200),
  telefone    VARCHAR(20),
  tipo        VARCHAR(20) NOT NULL DEFAULT 'cliente', -- cliente | empresa | motoboy | admin
  google_id   VARCHAR(100),
  facebook_id VARCHAR(100),
  foto_url    TEXT,
  status_motoboy VARCHAR(20) DEFAULT 'offline',
  criado_em   TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ── CATEGORIAS DE PRODUTO ────────────────────────────────────
CREATE TABLE IF NOT EXISTS categorias (
  id_categoria SERIAL PRIMARY KEY,
  nome         VARCHAR(100) NOT NULL
);

INSERT INTO categorias (nome) VALUES
  ('Lanches'),
  ('Pizzas'),
  ('Bebidas'),
  ('Sobremesas'),
  ('Salgados'),
  ('Japonês'),
  ('Árabe'),
  ('Carnes'),
  ('Vegetariano'),
  ('Outros')
ON CONFLICT DO NOTHING;

-- ── EMPRESAS (RESTAURANTES) ──────────────────────────────────
CREATE TABLE IF NOT EXISTS empresas (
  id_empresa    SERIAL PRIMARY KEY,
  id_usuario    INT NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
  nome          VARCHAR(100) NOT NULL,
  descricao     TEXT,
  foto_perfil   TEXT,
  foto_capa     TEXT,
  endereco      TEXT,
  latitude      DOUBLE PRECISION,
  longitude     DOUBLE PRECISION,
  telefone      VARCHAR(20),
  aberto        BOOLEAN NOT NULL DEFAULT false,
  taxa_minima   NUMERIC(10,2) NOT NULL DEFAULT 7.00,
  tempo_preparo INT NOT NULL DEFAULT 30,
  criado_em     TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ── PRODUTOS ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS produtos (
  id_produto   SERIAL PRIMARY KEY,
  id_empresa   INT NOT NULL REFERENCES empresas(id_empresa) ON DELETE CASCADE,
  id_categoria INT REFERENCES categorias(id_categoria),
  nome         VARCHAR(150) NOT NULL,
  descricao    TEXT,
  preco        NUMERIC(10,2) NOT NULL,
  imagem       TEXT,
  ativo        BOOLEAN NOT NULL DEFAULT true,
  is_pizza           BOOLEAN DEFAULT false,
  pizza_meio_a_meio  BOOLEAN DEFAULT false,
  pizza_tres_sabores BOOLEAN DEFAULT false,
  criado_em    TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ── ADICIONAIS DE PRODUTO ────────────────────────────────────
CREATE TABLE IF NOT EXISTS produto_adicionais (
  id_adicional SERIAL PRIMARY KEY,
  id_produto   INT NOT NULL REFERENCES produtos(id_produto) ON DELETE CASCADE,
  grupo        VARCHAR(100) NOT NULL DEFAULT 'Adicionais',
  maximo_grupo INT NOT NULL DEFAULT 3,
  obrigatorio  BOOLEAN NOT NULL DEFAULT false,
  nome         VARCHAR(150) NOT NULL,
  descricao    VARCHAR(200) NOT NULL DEFAULT '',
  preco        NUMERIC(10,2) NOT NULL DEFAULT 0,
  ativo        BOOLEAN NOT NULL DEFAULT true
);

-- ── SABORES DE PIZZA ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS pizza_sabores (
  id_sabor   SERIAL PRIMARY KEY,
  id_produto INT NOT NULL REFERENCES produtos(id_produto) ON DELETE CASCADE,
  nome       VARCHAR(100) NOT NULL,
  descricao  TEXT NOT NULL DEFAULT '',
  preco      NUMERIC(10,2) NOT NULL DEFAULT 0,
  ativo      BOOLEAN NOT NULL DEFAULT true
);

-- ── STATUS DE PEDIDO ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS status_pedidos (
  id_status SERIAL PRIMARY KEY,
  nome      VARCHAR(50) NOT NULL
);

INSERT INTO status_pedidos (id_status, nome) VALUES
  (1, 'Aguardando'),
  (2, 'Em Preparo'),
  (3, 'A Caminho'),
  (4, 'Entregue'),
  (5, 'Cancelado'),
  (6, 'Aguardando Motoboy')
ON CONFLICT (id_status) DO UPDATE SET nome = EXCLUDED.nome;

-- ── PEDIDOS ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS pedidos (
  id_pedido           SERIAL PRIMARY KEY,
  id_usuario          INT NOT NULL REFERENCES usuarios(id_usuario),
  id_empresa          INT NOT NULL REFERENCES empresas(id_empresa),
  id_status           INT NOT NULL REFERENCES status_pedidos(id_status) DEFAULT 1,
  id_motoboy          INT REFERENCES usuarios(id_usuario),
  total               NUMERIC(10,2) NOT NULL,
  taxa_entrega        NUMERIC(10,2) NOT NULL DEFAULT 0,
  endereco_entrega    TEXT,
  observacao          TEXT,
  tipo_entrega        VARCHAR(20),
  forma_pagamento     VARCHAR(30),
  troco_para          NUMERIC(10,2),
  quase_pronto        BOOLEAN NOT NULL DEFAULT false,
  motoboy_empresa_nome     VARCHAR(100),
  motoboy_empresa_telefone VARCHAR(20),
  criado_em           TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ── ITENS DO PEDIDO ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS pedido_itens (
  id_item      SERIAL PRIMARY KEY,
  id_pedido    INT NOT NULL REFERENCES pedidos(id_pedido) ON DELETE CASCADE,
  id_produto   INT NOT NULL REFERENCES produtos(id_produto),
  quantidade   INT NOT NULL DEFAULT 1,
  preco_unit   NUMERIC(10,2) NOT NULL,
  observacao   TEXT,
  adicionais   JSONB
);

-- ── ENDEREÇOS DO CLIENTE ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS usuario_enderecos (
  id_endereco SERIAL PRIMARY KEY,
  id_usuario  INT NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
  apelido     VARCHAR(50) NOT NULL DEFAULT 'Casa',
  endereco    TEXT NOT NULL DEFAULT '',
  latitude    DOUBLE PRECISION,
  longitude   DOUBLE PRECISION,
  principal   BOOLEAN NOT NULL DEFAULT false
);

-- ── MOTOBOYS DA EMPRESA ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS empresa_motoboys (
  id_motoboy_empresa SERIAL PRIMARY KEY,
  id_empresa         INT NOT NULL REFERENCES empresas(id_empresa) ON DELETE CASCADE,
  id_usuario         INT REFERENCES usuarios(id_usuario),
  nome               VARCHAR(100),
  telefone           VARCHAR(20),
  ativo              BOOLEAN NOT NULL DEFAULT true
);

-- ── NOTIFICAÇÕES ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notificacoes (
  id         SERIAL PRIMARY KEY,
  id_usuario INT NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
  titulo     VARCHAR(100) NOT NULL,
  corpo      TEXT NOT NULL,
  tipo       VARCHAR(30) NOT NULL DEFAULT 'status_pedido',
  lida       BOOLEAN NOT NULL DEFAULT false,
  id_pedido  INT REFERENCES pedidos(id_pedido) ON DELETE SET NULL,
  criado_em  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notif_usuario ON notificacoes (id_usuario, lida, criado_em DESC);

-- ── AVALIAÇÕES ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS avaliacoes (
  id_avaliacao      SERIAL PRIMARY KEY,
  id_pedido         INT NOT NULL REFERENCES pedidos(id_pedido),
  id_usuario        INT NOT NULL REFERENCES usuarios(id_usuario),
  id_empresa        INT NOT NULL REFERENCES empresas(id_empresa),
  id_motoboy        INT REFERENCES usuarios(id_usuario),
  nota_empresa      SMALLINT NOT NULL CHECK (nota_empresa BETWEEN 1 AND 5),
  nota_motoboy      SMALLINT CHECK (nota_motoboy BETWEEN 1 AND 5),
  comentario        TEXT,
  rapidez           BOOLEAN,
  educacao          BOOLEAN,
  cuidado           BOOLEAN,
  sabor             BOOLEAN,
  embalagem         BOOLEAN,
  pedido_correto    BOOLEAN,
  comentario_entrega TEXT,
  criado_em         TIMESTAMP DEFAULT NOW(),
  UNIQUE (id_pedido, id_usuario)
);

-- ── RECUPERAÇÃO DE SENHA ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS recuperacao_senha (
  id        SERIAL PRIMARY KEY,
  email     VARCHAR(200) NOT NULL,
  codigo    VARCHAR(6)   NOT NULL,
  expira_em TIMESTAMP    NOT NULL,
  usado     BOOLEAN      NOT NULL DEFAULT false
);

-- ── DISPOSITIVOS FCM (PUSH) ──────────────────────────────────
CREATE TABLE IF NOT EXISTS dispositivos_fcm (
  id            SERIAL PRIMARY KEY,
  id_usuario    INT NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
  fcm_token     TEXT NOT NULL,
  plataforma    VARCHAR(10) NOT NULL DEFAULT 'android',
  atualizado_em TIMESTAMP NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_fcm_token UNIQUE (fcm_token)
);

CREATE INDEX IF NOT EXISTS idx_fcm_usuario ON dispositivos_fcm (id_usuario);

-- ── TENTATIVAS DE LOGIN (RATE LIMITING) ──────────────────────
CREATE TABLE IF NOT EXISTS login_attempts (
  id          SERIAL PRIMARY KEY,
  chave       VARCHAR(200) NOT NULL UNIQUE,
  tentativas  INT NOT NULL DEFAULT 0,
  ultima_vez  TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ============================================================
-- FIM DO SCHEMA
-- ============================================================
