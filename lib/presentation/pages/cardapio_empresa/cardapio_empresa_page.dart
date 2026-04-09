import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../checkout/checkout_page.dart';

const Color _primary = Color(0xFFF5841F);

// ══════════════════════════════════════════════════════════════════
// Representa um item no carrinho (produto + adicionais escolhidos)
// ══════════════════════════════════════════════════════════════════
class _ItemCarrinho {
  final Map<String, dynamic> produto;
  final List<Map<String, dynamic>> adicionais; // itens selecionados
  final String observacao;
  final int quantidade;

  _ItemCarrinho({
    required this.produto,
    required this.adicionais,
    required this.observacao,
    this.quantidade = 1,
  });

  int get idProduto {
    final v = produto['id_produto'];
    return v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
  }

  double get precoBase {
    final v = produto['preco'];
    return v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  double get precoAdicionais => adicionais.fold(0.0, (acc, a) {
        final p = a['preco'];
        return acc + (p is num ? p.toDouble() : double.tryParse(p?.toString() ?? '') ?? 0.0);
      });

  double get precoTotal => (precoBase + precoAdicionais) * quantidade;

  String get resumoAdicionais =>
      adicionais.map((a) => a['nome']?.toString() ?? '').join(', ');
}

// ══════════════════════════════════════════════════════════════════
// PÁGINA DO CARDÁPIO
// ══════════════════════════════════════════════════════════════════
class CardapioEmpresaPage extends StatefulWidget {
  final Map<String, dynamic> empresa;
  const CardapioEmpresaPage({super.key, required this.empresa});

  @override
  State<CardapioEmpresaPage> createState() => _CardapioEmpresaPageState();
}

class _CardapioEmpresaPageState extends State<CardapioEmpresaPage>
    with SingleTickerProviderStateMixin {
  final List<_ItemCarrinho> _carrinho = [];
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  String _searchTerm = '';

  List<Map<String, dynamic>> get _produtos =>
      List<Map<String, dynamic>>.from(widget.empresa['produtos'] as List? ?? []);

  List<Map<String, dynamic>> get _produtosFiltrados {
    if (_searchTerm.isEmpty) return _produtos;
    final t = _searchTerm.toLowerCase();
    return _produtos
        .where((p) =>
            (p['nome']?.toString() ?? '').toLowerCase().contains(t) ||
            (p['descricao']?.toString() ?? '').toLowerCase().contains(t) ||
            (p['categoria_nome']?.toString() ?? '').toLowerCase().contains(t))
        .toList();
  }

  Map<String, List<Map<String, dynamic>>> get _porCategoria {
    final Map<String, List<Map<String, dynamic>>> map = {};
    for (final p in _produtosFiltrados) {
      final cat = p['categoria_nome']?.toString() ?? 'Outros';
      map.putIfAbsent(cat, () => []).add(p);
    }
    return map;
  }

  int _idProduto(Map<String, dynamic> p) {
    final v = p['id_produto'];
    return v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
  }

  // Quantidade total de itens no carrinho para um produto
  int _qtdNoCarrinho(int idProduto) => _carrinho
      .where((i) => i.idProduto == idProduto)
      .fold(0, (acc, i) => acc + i.quantidade);

  double get _totalCarrinho =>
      _carrinho.fold(0.0, (acc, i) => acc + i.precoTotal);

  int get _totalItens =>
      _carrinho.fold(0, (acc, i) => acc + i.quantidade);

  void _abrirProduto(Map<String, dynamic> produto) async {
    final resultado = await Navigator.push<_ItemCarrinho>(
      context,
      MaterialPageRoute(
        builder: (_) => _ProdutoDetalhePage(produto: produto),
        fullscreenDialog: true,
      ),
    );
    if (resultado != null) {
      setState(() => _carrinho.add(resultado));
    }
  }

  void _irParaCheckout() {
    final itens = _carrinho.map((item) => {
      'id_produto': item.idProduto,
      'nome': item.produto['nome'],
      'preco': item.precoBase + item.precoAdicionais,
      'quantidade': item.quantidade,
      'adicionais': item.resumoAdicionais,
      'observacao': item.observacao,
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutPage(
          empresa: widget.empresa,
          itens: itens,
          total: _totalCarrinho,
        ),
      ),
    );
  }

  List<String> get _categoriasOrdenadas => _porCategoria.keys.toList();

  @override
  void initState() {
    super.initState();
    final cats = _categoriasOrdenadas;
    _tabController = TabController(length: cats.isEmpty ? 1 : cats.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Color get _headerColor {
    final nome = widget.empresa['nome']?.toString() ?? '';
    const colors = [
      Color(0xFFF5841F), Color(0xFF4CAF50), Color(0xFF2196F3),
      Color(0xFF9C27B0), Color(0xFFE91E63),
    ];
    return nome.isEmpty ? colors[0] : colors[nome.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final nome = widget.empresa['nome']?.toString() ?? 'Restaurante';
    final categorias = _categoriasOrdenadas;
    final color = _headerColor;
    final fotoPerfil = widget.empresa['foto_perfil']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          // ── Header expandível ──────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: color,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.favorite_border, color: Colors.white),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.65)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: _buildLogo(nome, fotoPerfil),
                ),
              ),
            ),
          ),

          // ── Barra de info ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nome,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20)),
                  const SizedBox(height: 4),
                  Row(children: const [
                    Icon(Icons.delivery_dining, size: 16, color: Colors.grey),
                    SizedBox(width: 4),
                    Text('R\$ 7,99', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    Text(' • ', style: TextStyle(color: Colors.grey)),
                    Text('40-60 min', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: const [
                    Icon(Icons.star, color: Color(0xFFFFC107), size: 15),
                    SizedBox(width: 3),
                    Text('4.8', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(' • ', style: TextStyle(color: Colors.grey)),
                    Text('mínimo R\$ 15,00', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchTerm = v),
                      decoration: const InputDecoration(
                        hintText: 'busque por item ou categoria',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                        prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                        border: InputBorder.none,
                        fillColor: Colors.transparent,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ── Abas de categorias ─────────────────────────────────
          if (categorias.isNotEmpty)
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: _primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: _primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  unselectedLabelStyle: const TextStyle(fontSize: 14),
                  tabs: categorias.map((c) => Tab(text: c)).toList(),
                ),
              ),
            ),
        ],
        body: categorias.isEmpty
            ? const Center(child: Text('Nenhum produto disponível'))
            : TabBarView(
                controller: _tabController,
                children: categorias.map((cat) {
                  final prods = _porCategoria[cat] ?? [];
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: prods.length + 1,
                    separatorBuilder: (_, i) =>
                        i == 0 ? const SizedBox.shrink() : const Divider(height: 1),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 12),
                          child: Text(cat,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        );
                      }
                      final p = prods[i - 1];
                      final id = _idProduto(p);
                      final qtd = _qtdNoCarrinho(id);
                      return _CardProduto(
                        produto: p,
                        qtdNoCarrinho: qtd,
                        onTap: () => _abrirProduto(p),
                      );
                    },
                  );
                }).toList(),
              ),
      ),
      bottomNavigationBar: _totalItens == 0
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _irParaCheckout,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('$_totalItens',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      const Text('Fazer Pedido',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('R\$ ${_totalCarrinho.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLogo(String nome, String? fotoPerfil) {
    if (fotoPerfil != null && fotoPerfil.contains(',')) {
      try {
        final bytes = base64Decode(fotoPerfil.split(',').last);
        return ClipOval(
          child: Image.memory(bytes, width: 80, height: 80, fit: BoxFit.cover),
        );
      } catch (_) {}
    }
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Center(
        child: Text(
          nome.isNotEmpty ? nome[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 36),
        ),
      ),
    );
  }
}

// ── Delegate TabBar ───────────────────────────────────────────────
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  const _TabBarDelegate(this._tabBar);

  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: Colors.white, child: _tabBar);

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}

// ── Card de produto no cardápio (clicável) ────────────────────────
class _CardProduto extends StatelessWidget {
  final Map<String, dynamic> produto;
  final int qtdNoCarrinho;
  final VoidCallback onTap;

  const _CardProduto({
    required this.produto,
    required this.qtdNoCarrinho,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nome = produto['nome']?.toString() ?? '';
    final descricao = produto['descricao']?.toString() ?? '';
    final precoRaw = produto['preco'];
    final preco = precoRaw is num
        ? precoRaw.toDouble()
        : double.tryParse(precoRaw?.toString() ?? '') ?? 0.0;
    final imagem = produto['imagem']?.toString();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Texto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nome,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  if (descricao.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(descricao,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.grey, height: 1.4),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 8),
                  Text('R\$ ${preco.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Imagem + badge carrinho
            Stack(
              clipBehavior: Clip.none,
              children: [
                _ImagemProduto(imagem: imagem),
                // Badge com quantidade no carrinho
                if (qtdNoCarrinho > 0)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                          color: _primary, shape: BoxShape.circle),
                      child: Center(
                        child: Text('$qtdNoCarrinho',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                // Botão +
                Positioned(
                  bottom: -10,
                  right: -10,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                        color: _primary, shape: BoxShape.circle),
                    child: const Icon(Icons.add, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Imagem do produto ─────────────────────────────────────────────
class _ImagemProduto extends StatelessWidget {
  final String? imagem;
  const _ImagemProduto({this.imagem});

  @override
  Widget build(BuildContext context) {
    if (imagem != null && imagem!.contains(',')) {
      try {
        final bytes = base64Decode(imagem!.split(',').last);
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(bytes, width: 88, height: 88, fit: BoxFit.cover),
        );
      } catch (_) {}
    }
    return Container(
      width: 88, height: 88,
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.fastfood, color: _primary, size: 36),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// PÁGINA DE DETALHE DO PRODUTO + ADICIONAIS
// ══════════════════════════════════════════════════════════════════
class _ProdutoDetalhePage extends StatefulWidget {
  final Map<String, dynamic> produto;
  const _ProdutoDetalhePage({required this.produto});

  @override
  State<_ProdutoDetalhePage> createState() => _ProdutoDetalhePageState();
}

class _ProdutoDetalhePageState extends State<_ProdutoDetalhePage> {
  List<Map<String, dynamic>> _grupos = [];
  bool _loading = true;

  // seleções: grupo -> lista de ids selecionados
  final Map<String, List<int>> _selecoes = {};
  int _quantidade = 1;
  final _obsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarAdicionais();
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarAdicionais() async {
    final idProduto = widget.produto['id_produto'] is int
        ? widget.produto['id_produto'] as int
        : int.tryParse(widget.produto['id_produto']?.toString() ?? '') ?? 0;

    final grupos = await ApiService.getAdicionais(idProduto);
    if (mounted) {
      setState(() {
        _grupos = grupos;
        // Inicializa seleções vazias
        for (final g in grupos) {
          final grupo = g['grupo']?.toString() ?? '';
          _selecoes[grupo] = [];
        }
        _loading = false;
      });
    }
  }

  double get _precoBase {
    final v = widget.produto['preco'];
    return v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  double get _precoAdicionais {
    double total = 0;
    for (final g in _grupos) {
      final grupo = g['grupo']?.toString() ?? '';
      final sels = _selecoes[grupo] ?? [];
      final itens = List<Map<String, dynamic>>.from(g['itens'] as List? ?? []);
      for (final item in itens) {
        final id = item['id_adicional'] is int
            ? item['id_adicional'] as int
            : int.tryParse(item['id_adicional']?.toString() ?? '') ?? 0;
        if (sels.contains(id)) {
          final p = item['preco'];
          total += p is num ? p.toDouble() : double.tryParse(p?.toString() ?? '') ?? 0.0;
        }
      }
    }
    return total;
  }

  double get _precoTotal => (_precoBase + _precoAdicionais) * _quantidade;

  bool get _podePedir {
    // Verifica obrigatórios
    for (final g in _grupos) {
      final obrig = g['obrigatorio'] == true;
      if (obrig) {
        final grupo = g['grupo']?.toString() ?? '';
        if ((_selecoes[grupo] ?? []).isEmpty) return false;
      }
    }
    return true;
  }

  void _toggleAdicional(String grupo, int idAdicional, int maximo) {
    setState(() {
      final sels = _selecoes[grupo] ??= [];
      if (sels.contains(idAdicional)) {
        sels.remove(idAdicional);
      } else if (sels.length < maximo) {
        sels.add(idAdicional);
      }
    });
  }

  List<Map<String, dynamic>> get _adicionaisSelecionados {
    final result = <Map<String, dynamic>>[];
    for (final g in _grupos) {
      final grupo = g['grupo']?.toString() ?? '';
      final sels = _selecoes[grupo] ?? [];
      final itens = List<Map<String, dynamic>>.from(g['itens'] as List? ?? []);
      for (final item in itens) {
        final id = item['id_adicional'] is int
            ? item['id_adicional'] as int
            : int.tryParse(item['id_adicional']?.toString() ?? '') ?? 0;
        if (sels.contains(id)) result.add(item);
      }
    }
    return result;
  }

  void _adicionar() {
    if (!_podePedir) return;
    Navigator.pop(
      context,
      _ItemCarrinho(
        produto: widget.produto,
        adicionais: _adicionaisSelecionados,
        observacao: _obsCtrl.text.trim(),
        quantidade: _quantidade,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nome = widget.produto['nome']?.toString() ?? '';
    final descricao = widget.produto['descricao']?.toString() ?? '';
    final imagem = widget.produto['imagem']?.toString();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(nome,
            style: const TextStyle(
                color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15),
            overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Colors.black54),
            onPressed: () {},
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : ListView(
              children: [
                // ── Imagem / hero ──────────────────────────────────
                if (imagem != null && imagem.contains(','))
                  _buildImagemHero(imagem)
                else
                  Container(
                    height: 180,
                    color: _primary.withValues(alpha: 0.08),
                    child: const Center(
                        child: Icon(Icons.fastfood, color: _primary, size: 72)),
                  ),

                // ── Info do produto ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nome,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20)),
                      if (descricao.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(descricao,
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                height: 1.5)),
                      ],
                      const SizedBox(height: 10),
                      Text('R\$ ${_precoBase.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: _primary)),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // ── Grupos de adicionais ───────────────────────────
                ..._grupos.map((g) => _buildGrupo(g)),

                // ── Observação ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: const [
                        Icon(Icons.chat_bubble_outline,
                            size: 16, color: Colors.grey),
                        SizedBox(width: 6),
                        Text('Alguma observação?',
                            style: TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 14)),
                      ]),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _obsCtrl,
                        maxLength: 140,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Ex: sem cebola, bem passado...',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),

                // Espaço para o botão
                const SizedBox(height: 100),
              ],
            ),
      // ── Barra inferior: quantidade + adicionar ─────────────────
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    // Controle de quantidade
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: _quantidade > 1
                              ? () => setState(() => _quantidade--)
                              : null,
                          color: _quantidade > 1 ? _primary : Colors.grey,
                        ),
                        Text('$_quantidade',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        IconButton(
                          icon: const Icon(Icons.add, size: 18, color: _primary),
                          onPressed: () => setState(() => _quantidade++),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    // Botão adicionar
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _podePedir ? _primary : Colors.grey.shade300,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: _podePedir ? _adicionar : null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _podePedir ? 'Adicionar' : 'Selecione obrigatórios',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: _podePedir ? 15 : 12,
                              ),
                            ),
                            if (_podePedir)
                              Text('R\$ ${_precoTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImagemHero(String imagem) {
    try {
      final bytes = base64Decode(imagem.split(',').last);
      return Image.memory(bytes,
          width: double.infinity, height: 220, fit: BoxFit.cover);
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildGrupo(Map<String, dynamic> g) {
    final grupo = g['grupo']?.toString() ?? 'Adicionais';
    final obrig = g['obrigatorio'] == true;
    final maximo = g['maximo_grupo'] is int
        ? g['maximo_grupo'] as int
        : int.tryParse(g['maximo_grupo']?.toString() ?? '3') ?? 3;
    final itens = List<Map<String, dynamic>>.from(g['itens'] as List? ?? []);
    final sels = _selecoes[grupo] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho do grupo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFFF5F5F5),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(grupo,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    maximo == 1
                        ? 'Escolha 1 opção'
                        : 'Escolha até $maximo opções',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (obrig)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('OBRIGATÓRIO',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
          ]),
        ),
        // Itens do grupo
        ...itens.map((item) {
          final id = item['id_adicional'] is int
              ? item['id_adicional'] as int
              : int.tryParse(item['id_adicional']?.toString() ?? '') ?? 0;
          final selecionado = sels.contains(id);
          final precoItem = item['preco'];
          final precoVal = precoItem is num
              ? precoItem.toDouble()
              : double.tryParse(precoItem?.toString() ?? '') ?? 0.0;
          final podeSelecionar = selecionado || sels.length < maximo;
          final itemImagem = item['imagem']?.toString();

          return InkWell(
            onTap: podeSelecionar || selecionado
                ? () => _toggleAdicional(grupo, id, maximo)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['nome']?.toString() ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 14)),
                      if ((item['descricao']?.toString() ?? '').isNotEmpty)
                        Text(item['descricao'].toString(),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500)),
                      if (precoVal > 0)
                        Text('+ R\$ ${precoVal.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Imagem (se houver)
                if (itemImagem != null && itemImagem.contains(','))
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _buildItemImagem(itemImagem),
                  ),
                // Checkbox/radio
                maximo == 1
                    ? GestureDetector(
                        onTap: () => _toggleAdicional(grupo, id, maximo),
                        child: Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: selecionado ? _primary : Colors.grey.shade400,
                                width: 2),
                            color: selecionado ? _primary : Colors.transparent,
                          ),
                          child: selecionado
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : null,
                        ),
                      )
                    : Checkbox(
                        value: selecionado,
                        onChanged: podeSelecionar || selecionado
                            ? (_) => _toggleAdicional(grupo, id, maximo)
                            : null,
                        activeColor: _primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
              ]),
            ),
          );
        }),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildItemImagem(String imagem) {
    try {
      final bytes = base64Decode(imagem.split(',').last);
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(bytes, width: 56, height: 56, fit: BoxFit.cover),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}
