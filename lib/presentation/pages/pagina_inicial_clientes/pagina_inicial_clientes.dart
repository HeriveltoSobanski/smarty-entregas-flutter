import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../data/session_store.dart';
import '../busca/busca_page.dart';
import '../meus_pedidos/meus_pedidos_page.dart';
import '../perfil/perfil_page.dart';
import '../cardapio_empresa/cardapio_empresa_page.dart';
import '../cliente_enderecos/cliente_enderecos_page.dart';
import '../avaliacao/avaliacao_page.dart' show NotaEstrelas;
import '../notificacoes/notificacoes_page.dart';
import '../../../data/favoritos_store.dart';
import '../../widgets/offline_banner.dart';

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verificarEndereco());
  }

  Future<void> _verificarEndereco() async {
    final id = SessionStore.idUsuario;
    if (id == null) return;
    final enderecos = await ApiService.getEnderecosCliente(id);
    if (!mounted) return;
    if (enderecos.isEmpty) {
      _mostrarModalEnderecoObrigatorio();
    }
  }

  void _mostrarModalEnderecoObrigatorio() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.location_on, color: _primary),
            SizedBox(width: 8),
            Expanded(child: Text('Endereço obrigatório',
                style: TextStyle(fontSize: 17))),
          ]),
          content: const Text(
            'Para fazer pedidos você precisa cadastrar pelo menos um endereço de entrega.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClienteEnderecosPage(),
                  ),
                );
                if (!mounted) return;
                // Verifica se cadastrou algum
                final id = SessionStore.idUsuario;
                if (id == null) return;
                final enderecos = await ApiService.getEnderecosCliente(id);
                if (enderecos.isEmpty && mounted) {
                  _mostrarModalEnderecoObrigatorio();
                }
              },
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Cadastrar agora',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

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
  bool _fromCache = false;
  String _categoriaFiltro = '';
  String _labelEntrega = '';
  Set<int> _favoritos = {};

  // Notificações
  int    _naoLidas     = 0;
  Timer? _notifTimer;

  static const _categorias = ['Todos', 'Lanches', 'Pizzas', 'Almoços', 'Bebidas', 'Sobremesas'];

  bool _filtroEntregaGratis = false;
  bool _filtroPromocoes     = false;
  bool _filtroMaisAvaliados = false;

  @override
  void initState() {
    super.initState();
    _carregar();
    _carregarFavoritos();
    _atualizarNaoLidas();
    _notifTimer = Timer.periodic(const Duration(seconds: 30), (_) => _atualizarNaoLidas());
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    super.dispose();
  }

  Future<void> _carregarFavoritos() async {
    final favs = await FavoritosStore.getAll();
    if (mounted) setState(() => _favoritos = favs);
  }

  Future<void> _toggleFavorito(int idEmpresa) async {
    await FavoritosStore.toggle(idEmpresa);
    await _carregarFavoritos();
  }

  Future<void> _atualizarNaoLidas() async {
    final id = SessionStore.idUsuario;
    if (id == null) return;
    final total = await ApiService.getNotificacoesNaoLidas(id);
    if (mounted) setState(() => _naoLidas = total);
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final id = SessionStore.idUsuario;

    final empresasFuture = ApiService.getEmpresasComProdutos(
      categoria: _categoriaFiltro.isEmpty ? null : _categoriaFiltro,
    );
    final enderecosFuture =
        id != null ? ApiService.getEnderecosCliente(id) : Future.value(<Map<String, dynamic>>[]);

    final results = await Future.wait([empresasFuture, enderecosFuture]);
    if (!mounted) return;

    final empresasResult =
        results[0] as ({List<Map<String, dynamic>> empresas, bool fromCache});
    final enderecos =
        results[1] as List<Map<String, dynamic>>;

    if (enderecos.isNotEmpty) {
      final principal = enderecos.firstWhere(
        (e) => e['principal'] == true,
        orElse: () => enderecos.first,
      );
      final apelido = (principal['apelido'] ?? '').toString().trim();
      _labelEntrega = apelido.isNotEmpty ? apelido : 'Meu endereço';
    }

    setState(() {
      _empresas = empresasResult.empresas;
      _fromCache = empresasResult.fromCache;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          const OfflineBanner(),
          if (_fromCache)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF3E0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 14, color: Color(0xFFE65100)),
                SizedBox(width: 6),
                Text('Dados salvos — puxe para atualizar',
                    style: TextStyle(fontSize: 12, color: Color(0xFFE65100))),
              ]),
            ),
          Expanded(
            child: RefreshIndicator(
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

            // ── Seção favoritos ────────────────────────────────
            if (!_loading && _favoritos.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(children: [
                    const Icon(Icons.favorite, color: Colors.red, size: 16),
                    const SizedBox(width: 6),
                    Text('Favoritos',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.grey.shade800)),
                  ]),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 110,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: _empresas
                        .where((e) => _favoritos.contains(
                            e['id_empresa'] is int
                                ? e['id_empresa'] as int
                                : int.tryParse(e['id_empresa']?.toString() ?? '') ?? -1))
                        .map((e) => _FavoritoCard(
                              empresa: e,
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(
                                      builder: (_) => CardapioEmpresaPage(empresa: e))),
                            ))
                        .toList(),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 4)),
            ],

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
                  (_, i) => _EmpresaCard(
                    empresa: _empresas[i],
                    isFavorito: _favoritos.contains(
                        _empresas[i]['id_empresa'] is int
                            ? _empresas[i]['id_empresa'] as int
                            : int.tryParse(_empresas[i]['id_empresa']?.toString() ?? '') ?? -1),
                    onFavoritoToggle: () {
                      final id = _empresas[i]['id_empresa'] is int
                          ? _empresas[i]['id_empresa'] as int
                          : int.tryParse(_empresas[i]['id_empresa']?.toString() ?? '') ?? -1;
                      _toggleFavorito(id);
                    },
                  ),
                  childCount: _empresas.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
          ),  // Expanded
        ],    // Column
      ),      // body
    );
  }

  Widget _buildBanner() => const _BannerWidget();

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final nome = SessionStore.nome ?? 'você';
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: const Color(0x1A000000),
      titleSpacing: 16,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Lado esquerdo: endereço de entrega
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Entregar em',
                  style: TextStyle(fontSize: 11, color: Color(0xFF757575))),
              Row(children: [
                Text(
                  _labelEntrega.isNotEmpty ? _labelEntrega : 'Meu endereço',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A)),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.keyboard_arrow_down, color: _primary, size: 18),
              ]),
            ],
          ),
          const Spacer(),
          // "Olá, nome" alinhado à base da coluna esquerda (mesma altura do endereço)
          Text('Olá, ${nome.split(' ').first}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF757575))),
        ],
      ),
      actions: [
        // Sino de notificações com badge (no lugar do avatar)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: Color(0xFF757575)),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificacoesPage()),
                  );
                  _atualizarNaoLidas();
                },
              ),
              if (_naoLidas > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _naoLidas > 99 ? '99+' : '$_naoLidas',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
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
        _FiltroToggle(
          icon: Icons.delivery_dining_outlined,
          label: 'Entrega grátis',
          active: _filtroEntregaGratis,
          onTap: () => setState(() => _filtroEntregaGratis = !_filtroEntregaGratis),
        ),
        const SizedBox(width: 8),
        _FiltroToggle(
          icon: Icons.percent,
          label: 'Promoções',
          active: _filtroPromocoes,
          onTap: () => setState(() => _filtroPromocoes = !_filtroPromocoes),
        ),
        const SizedBox(width: 8),
        _FiltroToggle(
          icon: Icons.star_outline,
          label: 'Mais avaliados',
          active: _filtroMaisAvaliados,
          onTap: () => setState(() => _filtroMaisAvaliados = !_filtroMaisAvaliados),
        ),
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

// ── Banner rotativo (widget isolado para não piscar a lista) ──────
class _BannerWidget extends StatefulWidget {
  const _BannerWidget();
  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget> {
  static const _banners = [
    (path: 'assets/banner.png',  texto: 'Peça Agora no Smarty Entregas'),
    (path: 'assets/banner2.png', texto: 'Entrega Rápida em Mallet!'),
    (path: 'assets/banner3.png', texto: 'Promoções Imperdíveis!'),
  ];

  final _ctrl = PageController();
  int _atual = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_atual + 1) % _banners.length;
      _ctrl.animateToPage(next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        height: 150,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PageView.builder(
              controller: _ctrl,
              itemCount: _banners.length,
              onPageChanged: (i) => setState(() => _atual = i),
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
                  final ativo = _atual == i;
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
}

// ── Chip de filtro (estilo diferente das categorias) ─────────────
class _FiltroToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FiltroToggle({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFF3E8) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? _primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14,
              color: active ? _primary : const Color(0xFF666666)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                color: active ? _primary : const Color(0xFF666666),
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              )),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CARD DE EMPRESA — estilo iFood
// ════════════════════════════════════════════════════════════════
class _EmpresaCard extends StatelessWidget {
  final Map<String, dynamic> empresa;
  final bool isFavorito;
  final VoidCallback onFavoritoToggle;
  const _EmpresaCard({
    required this.empresa,
    required this.isFavorito,
    required this.onFavoritoToggle,
  });

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
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: onFavoritoToggle,
                        child: Icon(
                          isFavorito ? Icons.favorite : Icons.favorite_border,
                          color: isFavorito ? Colors.red : Colors.grey.shade400,
                          size: 20,
                        ),
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
                      NotaEstrelas(
                        nota:  (empresa['nota_media'] is num
                            ? (empresa['nota_media'] as num).toDouble()
                            : double.tryParse(
                                    empresa['nota_media']?.toString() ?? '0') ??
                                0.0),
                        total: (empresa['nota_total'] is int
                            ? empresa['nota_total'] as int
                            : int.tryParse(
                                    empresa['nota_total']?.toString() ?? '0') ??
                                0),
                        tamanho: 12,
                      ),
                      if ((empresa['nota_total'] ?? 0) != 0)
                        const Text(' • ',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF757575))),
                      const Icon(Icons.delivery_dining,
                          size: 14, color: Color(0xFF757575)),
                      const SizedBox(width: 2),
                      Text(
                        'a partir de R\$ ${((empresa['taxa_minima'] is num ? (empresa['taxa_minima'] as num).toDouble() : double.tryParse(empresa['taxa_minima']?.toString() ?? '') ?? 7.0)).toStringAsFixed(2)} •',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF757575)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${empresa['tempo_preparo'] ?? 30}+ min',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF757575)),
                      ),
                    ]),
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

// ── Card horizontal de favorito ──────────────────────────────────
class _FavoritoCard extends StatelessWidget {
  final Map<String, dynamic> empresa;
  final VoidCallback onTap;
  const _FavoritoCard({required this.empresa, required this.onTap});

  Color _logoColor(String nome) {
    const colors = [
      Color(0xFFF5841F), Color(0xFF4CAF50), Color(0xFF2196F3),
      Color(0xFF9C27B0), Color(0xFFE91E63), Color(0xFF00BCD4), Color(0xFFFF5722),
    ];
    return nome.isEmpty ? colors[0] : colors[nome.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final nome = empresa['nome']?.toString() ?? '';
    final foto = empresa['foto_perfil']?.toString();
    final color = _logoColor(nome);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LogoEmpresa(nome: nome, fotoPerfil: foto, color: color),
            const SizedBox(height: 6),
            Text(
              nome,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Logo da empresa (foto ou inicial) ────────────────────────────
class _LogoEmpresa extends StatefulWidget {
  final String nome;
  final String? fotoPerfil;
  final Color color;
  const _LogoEmpresa({required this.nome, required this.fotoPerfil, required this.color});

  @override
  State<_LogoEmpresa> createState() => _LogoEmpresaState();
}

class _LogoEmpresaState extends State<_LogoEmpresa> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(_LogoEmpresa old) {
    super.didUpdateWidget(old);
    if (old.fotoPerfil != widget.fotoPerfil) _decode();
  }

  void _decode() {
    final foto = widget.fotoPerfil;
    if (foto != null && foto.contains(',')) {
      try {
        _bytes = base64Decode(foto.split(',').last);
      } catch (_) {
        _bytes = null;
      }
    } else {
      _bytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(_bytes!, width: 60, height: 60, fit: BoxFit.cover,
            gaplessPlayback: true),
      );
    }
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: widget.color.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Text(
          widget.nome.isNotEmpty ? widget.nome[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26),
        ),
      ),
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
          ]),
        ),
      ]),
    );
  }
}
