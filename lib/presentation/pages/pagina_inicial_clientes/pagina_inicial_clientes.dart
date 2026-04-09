import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../data/session_store.dart';
import '../busca/busca_page.dart';
import '../meus_pedidos/meus_pedidos_page.dart';
import '../perfil/perfil_page.dart';
import '../cardapio_empresa/cardapio_empresa_page.dart';

const Color _primary = Color(0xFFF5841F);
const Color _bg = Color(0xFFF5F5F5);

class PaginaInicialClientes extends StatefulWidget {
  const PaginaInicialClientes({super.key});

  @override
  State<PaginaInicialClientes> createState() => _PaginaInicialClientesState();
}

class _PaginaInicialClientesState extends State<PaginaInicialClientes> {
  int _tabIndex = 0;

  final _paginas = <Widget>[
    const _HomeContent(),
    const BuscaPage(),
    const MeusPedidosPage(),
    const PerfilPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(index: _tabIndex, children: _paginas),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    const iconsFilled = [Icons.home, Icons.search, Icons.receipt_long, Icons.person];
    const iconsOutlined = [Icons.home_outlined, Icons.search_outlined, Icons.receipt_long_outlined, Icons.person_outline];
    const labels = ['início', 'busca', 'pedidos', 'conta'];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE0E0E0), width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: _primary,
        unselectedItemColor: const Color(0xFF9E9E9E),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        type: BottomNavigationBarType.fixed,
        items: List.generate(4, (i) {
          final ativo = _tabIndex == i;
          return BottomNavigationBarItem(
            icon: Icon(ativo ? iconsFilled[i] : iconsOutlined[i]),
            label: labels[i],
          );
        }),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CONTEÚDO DA TAB HOME
// ════════════════════════════════════════════════════════════════
class _HomeContent extends StatefulWidget {
  const _HomeContent();

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  List<Map<String, dynamic>> _empresas = [];
  bool _loading = true;
  String _categoriaFiltro = '';

  // Banner
  final _bannerCtrl = PageController();
  int _bannerAtual = 0;
  Timer? _bannerTimer;

  static final _banners = [
    const _BannerData('assets/banner.png', 'Peça Agora no Smarty Entregas'),
    const _BannerData('assets/banner2.png', 'Entrega Rápida em Mallet!'),
    const _BannerData('assets/banner3.png', 'Promoções Imperdíveis!'),
  ];

  static const _categorias = ['Todos', 'Lanches', 'Pizzas', 'Almoços', 'Bebidas', 'Sobremesas'];

  @override
  void initState() {
    super.initState();
    _carregar();
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_bannerAtual + 1) % _banners.length;
      _bannerCtrl.animateToPage(next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final lista = await ApiService.getEmpresasComProdutos(
      categoria: _categoriaFiltro.isEmpty ? null : _categoriaFiltro,
    );
    if (mounted) setState(() { _empresas = lista; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        color: _primary,
        onRefresh: _carregar,
        child: CustomScrollView(
          slivers: [
            // ── Banner rotativo ────────────────────────────────
            SliverToBoxAdapter(child: _buildBanner()),

            // ── Chips de categoria ─────────────────────────────
            SliverToBoxAdapter(child: _buildCategoryBar()),

            // ── Chips de filtro ────────────────────────────────
            SliverToBoxAdapter(child: _buildFilterChips()),

            // ── Título seção ───────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Restaurantes',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.grey.shade800)),
              ),
            ),

            // ── Lista compacta de empresas ─────────────────────
            if (_loading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => const _EmpresaCardShimmer(),
                  childCount: 5,
                ),
              )
            else if (_empresas.isEmpty)
              SliverToBoxAdapter(child: _buildEmpty())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _EmpresaCard(empresa: _empresas[i]),
                  childCount: _empresas.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        height: 150,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PageView.builder(
              controller: _bannerCtrl,
              itemCount: _banners.length,
              onPageChanged: (i) => setState(() => _bannerAtual = i),
              itemBuilder: (_, i) {
                final b = _banners[i];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    b.path,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primary, Color(0xFFFFC107)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: Center(
                        child: Text(b.texto,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 17)),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              bottom: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_banners.length, (i) {
                  final ativo = _bannerAtual == i;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: ativo ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: ativo
                          ? _primary
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final nome = SessionStore.nome ?? 'você';
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: const Color(0x1A000000),
      titleSpacing: 16,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Entregar em',
              style: TextStyle(fontSize: 11, color: Color(0xFF757575))),
          Row(children: const [
            Text('Mallet - PR',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A))),
            SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down, color: _primary, size: 18),
          ]),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(children: [
            Text('Olá, ${nome.split(' ').first}',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF757575))),
            const SizedBox(width: 8),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: _primary,
            child: Text(
              (SessionStore.nome ?? 'U').isNotEmpty
                  ? (SessionStore.nome ?? 'U')[0].toUpperCase()
                  : 'U',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ),
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFE0E0E0)),
      ),
    );
  }

  Widget _buildCategoryBar() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: _categorias.map((cat) {
          final selected =
              cat == 'Todos' ? _categoriaFiltro.isEmpty : _categoriaFiltro == cat;
          return GestureDetector(
            onTap: () {
              setState(() =>
                  _categoriaFiltro = cat == 'Todos' ? '' : cat);
              _carregar();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? _primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: selected ? _primary : const Color(0xFFDDDDDD)),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF555555),
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Row(children: [
        _FilterChip(icon: Icons.tune, label: 'filtros'),
        const SizedBox(width: 8),
        _FilterChip(icon: Icons.delivery_dining, label: 'entrega grátis'),
        const SizedBox(width: 8),
        _FilterChip(icon: Icons.local_offer, label: 'promoções'),
      ]),
    );
  }

  Widget _buildEmpty() {
    return SizedBox(
      height: 320,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.store_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Nenhuma empresa encontrada',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text(_categoriaFiltro.isNotEmpty
              ? 'Tente outro filtro'
              : 'Aguarde o cadastro de estabelecimentos',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ]),
      ),
    );
  }
}

// ── Dados do banner ───────────────────────────────────────────────
class _BannerData {
  final String path;
  final String texto;
  const _BannerData(this.path, this.texto);
}

// ── Chip de filtro ────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FilterChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.black54),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CARD DE EMPRESA — estilo iFood
// ════════════════════════════════════════════════════════════════
class _EmpresaCard extends StatelessWidget {
  final Map<String, dynamic> empresa;
  const _EmpresaCard({required this.empresa});

  Color _logoColor(String nome) {
    const colors = [
      Color(0xFFF5841F),
      Color(0xFF4CAF50),
      Color(0xFF2196F3),
      Color(0xFF9C27B0),
      Color(0xFFE91E63),
      Color(0xFF00BCD4),
      Color(0xFFFF5722),
    ];
    return nome.isEmpty ? colors[0] : colors[nome.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final nome = empresa['nome']?.toString() ?? '';
    final produtos = List<Map<String, dynamic>>.from(
        empresa['produtos'] as List? ?? []);

    final categorias = produtos
        .map((p) => p['categoria_nome']?.toString() ?? '')
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();

    final color = _logoColor(nome);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CardapioEmpresaPage(empresa: empresa),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 2),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Logo circular ──────────────────────────────
              _LogoEmpresa(nome: nome, fotoPerfil: empresa['foto_perfil']?.toString(), color: color),
              const SizedBox(width: 14),

              // ── Info ───────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(nome,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF1A1A1A))),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Aberto',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    // Categorias
                    if (categorias.isNotEmpty)
                      Text(categorias.take(3).join(' • '),
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF757575))),
                    const SizedBox(height: 5),
                    // Estrela / tempo / frete
                    Row(children: [
                      const Icon(Icons.star,
                          color: Color(0xFFFFC107), size: 14),
                      const SizedBox(width: 2),
                      const Text('4.8 •',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      const Icon(Icons.delivery_dining,
                          size: 14, color: Color(0xFF757575)),
                      const SizedBox(width: 2),
                      const Text('R\$ 7,99 •',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF757575))),
                      const SizedBox(width: 4),
                      const Text('40-60 min',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF757575))),
                    ]),
                    const SizedBox(height: 8),
                    // Preview de produtos com imagem
                    if (produtos.isNotEmpty)
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: produtos.length > 5 ? 5 : produtos.length,
                          itemBuilder: (_, i) =>
                              _MiniCardProduto(produto: produtos[i]),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Logo da empresa (foto ou inicial) ────────────────────────────
class _LogoEmpresa extends StatelessWidget {
  final String nome;
  final String? fotoPerfil;
  final Color color;
  const _LogoEmpresa({required this.nome, required this.fotoPerfil, required this.color});

  @override
  Widget build(BuildContext context) {
    if (fotoPerfil != null && fotoPerfil!.contains(',')) {
      try {
        final bytes = base64Decode(fotoPerfil!.split(',').last);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes, width: 60, height: 60, fit: BoxFit.cover),
        );
      } catch (_) {}
    }
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Text(
          nome.isNotEmpty ? nome[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26),
        ),
      ),
    );
  }
}

// ── Mini card de produto (preview horizontal) ─────────────────────
class _MiniCardProduto extends StatelessWidget {
  final Map<String, dynamic> produto;
  const _MiniCardProduto({required this.produto});

  @override
  Widget build(BuildContext context) {
    final nome = produto['nome']?.toString() ?? '';
    final precoRaw = produto['preco'];
    final preco = precoRaw is num
        ? precoRaw.toDouble()
        : double.tryParse(precoRaw?.toString() ?? '') ?? 0.0;
    final imagem = produto['imagem']?.toString();

    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MiniImagem(imagem: imagem),
          const SizedBox(height: 4),
          Text(nome,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text('R\$ ${preco.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 10,
                  color: _primary,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ── Imagem em miniatura ───────────────────────────────────────────
class _MiniImagem extends StatelessWidget {
  final String? imagem;
  const _MiniImagem({this.imagem});

  @override
  Widget build(BuildContext context) {
    if (imagem != null && imagem!.contains(',')) {
      try {
        final bytes = base64Decode(imagem!.split(',').last);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(bytes, width: 80, height: 56, fit: BoxFit.cover),
        );
      } catch (_) {}
    }
    return Container(
      width: 80,
      height: 56,
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.fastfood, color: _primary, size: 24),
    );
  }
}

// ── Shimmer card (skeleton loading) ──────────────────────────────
class _EmpresaCardShimmer extends StatelessWidget {
  const _EmpresaCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                height: 14, width: 140,
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 6),
            Container(
                height: 12, width: 200,
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 6),
            Container(
                height: 12, width: 160,
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 10),
            Row(
              children: List.generate(
                  4,
                  (_) => Container(
                        width: 80, height: 56,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8)),
                      )),
            ),
          ]),
        ),
      ]),
    );
  }
}
