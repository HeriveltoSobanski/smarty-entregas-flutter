import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../cardapio_empresa/cardapio_empresa_page.dart';
import '../../widgets/floating_cart.dart';
import '../../widgets/shimmer_card.dart';

final GlobalKey<ScaffoldMessengerState> contextGlobal =
    GlobalKey<ScaffoldMessengerState>();

class PaginaInicialClientes extends StatefulWidget {
  const PaginaInicialClientes({super.key});

  @override
  State<PaginaInicialClientes> createState() => _PaginaInicialClientesState();
}

class _PaginaInicialClientesState extends State<PaginaInicialClientes> {
  final PageController _bannerController = PageController();
  int _bannerAtual = 0;
  int _tabIndex = 0;
  Timer? _bannerTimer;

  List<Map<String, dynamic>> _empresas = [];
  bool _carregando = true;
  String _categoriaSel = '';

  static const int _totalBanners = 2;

  static const List<Map<String, dynamic>> _categorias = [
    {'nome': 'Todos',      'icon': Icons.restaurant},
    {'nome': 'Lanches',    'icon': Icons.fastfood},
    {'nome': 'Almoços',    'icon': Icons.restaurant_menu},
    {'nome': 'Sobremesas', 'icon': Icons.cake},
    {'nome': 'Pizzas',     'icon': Icons.local_pizza},
    {'nome': 'Bebidas',    'icon': Icons.local_drink},
  ];

  @override
  void initState() {
    super.initState();
    _carregar();
    // Auto-play do banner a cada 5 segundos
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_bannerAtual + 1) % _totalBanners;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _carregar({String categoria = ''}) async {
    setState(() => _carregando = true);
    final lista = await ApiService.getEmpresasComProdutos(
      categoria: categoria.isEmpty || categoria == 'Todos' ? null : categoria,
    );
    if (!mounted) return;
    setState(() {
      _empresas = lista;
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _carregar(categoria: _categoriaSel),
        child: CustomScrollView(
          slivers: [
            // Campo de busca
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: TextField(
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Buscar produtos ou lojas...',
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.primary, size: 22),
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Banner rotativo com dots animados
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 160,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      PageView(
                        controller: _bannerController,
                        onPageChanged: (i) =>
                            setState(() => _bannerAtual = i),
                        children: const [
                          _BannerItem('Bem-vindo ao Smarty Entregas!'),
                          _BannerItem('Peça agora e receba em casa'),
                        ],
                      ),
                      // Dots pill animados
                      Positioned(
                        bottom: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_totalBanners, (i) {
                            final ativo = _bannerAtual == i;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: ativo ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: ativo
                                    ? AppColors.primary
                                    : Colors.white.withValues(alpha: 0.6),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Filtro de categorias horizontal (chips)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categorias.length,
                  itemBuilder: (_, i) {
                    final cat = _categorias[i]['nome'] as String;
                    final sel = _categoriaSel == cat ||
                        (_categoriaSel.isEmpty && cat == 'Todos');
                    return GestureDetector(
                      onTap: () {
                        setState(() =>
                            _categoriaSel = cat == 'Todos' ? '' : cat);
                        _carregar(categoria: cat);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel
                                ? AppColors.primary
                                : AppColors.divider,
                          ),
                          boxShadow: sel
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Text(
                          cat,
                          style: GoogleFonts.poppins(
                            color: sel ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Título da seção
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _categoriaSel.isEmpty || _categoriaSel == 'Todos'
                          ? 'Todos os restaurantes'
                          : _categoriaSel,
                      style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // Lista de empresas (shimmer ou dados reais)
            if (_carregando)
              SliverToBoxAdapter(
                child: Column(
                  children: List.generate(
                    3,
                    (_) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: _ShimmerEmpresa(),
                    ),
                  ),
                ),
              )
            else if (_empresas.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_outlined,
                          size: 64, color: AppColors.disabled),
                      SizedBox(height: 12),
                      Text('Nenhum restaurante disponível',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 16)),
                      SizedBox(height: 4),
                      Text('Aguarde novos estabelecimentos',
                          style:
                              TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _CardEmpresa(empresa: _empresas[index]),
                  childCount: _empresas.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: const FloatingCart(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ===================== APP BAR =====================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: const Color(0x1A000000),
      backgroundColor: AppColors.surface,
      titleSpacing: 16,
      title: Row(
        children: [
          Image.asset(
            'assets/logo.png',
            width: 42,
            height: 42,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.delivery_dining,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.location_on,
                      color: AppColors.primary, size: 13),
                  SizedBox(width: 2),
                  Text(
                    'Entregar em',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                children: const [
                  Text(
                    'Mallet - PR',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.keyboard_arrow_down,
                      color: AppColors.primary, size: 18),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.textPrimary, size: 26),
                onPressed: () {},
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '2',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppColors.divider, height: 1),
      ),
    );
  }

  // ===================== BOTTOM NAV =====================
  Widget _buildBottomNav() {
    const icons = [
      [Icons.home_outlined, Icons.home],
      [Icons.search_outlined, Icons.search],
      [Icons.receipt_long_outlined, Icons.receipt_long],
      [Icons.person_outline, Icons.person],
    ];
    const labels = ['Início', 'Busca', 'Pedidos', 'Perfil'];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        backgroundColor: AppColors.surface,
        elevation: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.disabled,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        type: BottomNavigationBarType.fixed,
        items: List.generate(4, (i) {
          final ativo = _tabIndex == i;
          return BottomNavigationBarItem(
            icon: Icon(ativo ? icons[i][1] : icons[i][0]),
            label: labels[i],
          );
        }),
      ),
    );
  }
}

// ===================== CARD DE EMPRESA =====================
class _CardEmpresa extends StatelessWidget {
  final Map<String, dynamic> empresa;
  const _CardEmpresa({required this.empresa});

  @override
  Widget build(BuildContext context) {
    final produtos =
        List<Map<String, dynamic>>.from(empresa['produtos'] as List? ?? []);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da empresa
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CardapioEmpresaPage(empresa: empresa),
              ),
            ),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.storefront,
                        color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          empresa['nome']?.toString() ?? '',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${produtos.length} produto${produtos.length != 1 ? 's' : ''}',
                          style: GoogleFonts.poppins(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
          ),

          // Lista horizontal de produtos
          if (produtos.isNotEmpty)
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                itemCount: produtos.length,
                itemBuilder: (_, i) =>
                    _CardProduto(produto: produtos[i]),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Sem produtos cadastrados',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

// ===================== CARD DE PRODUTO =====================
class _CardProduto extends StatelessWidget {
  final Map<String, dynamic> produto;
  const _CardProduto({required this.produto});

  @override
  Widget build(BuildContext context) {
    final precoRaw = produto['preco'];
    final preco = precoRaw is num
        ? precoRaw.toDouble()
        : double.tryParse(precoRaw?.toString() ?? '') ?? 0.0;
    final cat = produto['categoria_nome']?.toString() ?? '';

    IconData icone = Icons.fastfood;
    if (cat == 'Bebidas') icone = Icons.local_drink;
    if (cat == 'Pizzas') icone = Icons.local_pizza;
    if (cat == 'Sobremesas') icone = Icons.cake;
    if (cat == 'Almoços') icone = Icons.restaurant;

    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000),
              blurRadius: 4,
              offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              height: 75,
              width: double.infinity,
              color: AppColors.primary.withValues(alpha: 0.1),
              child:
                  Icon(icone, color: AppColors.primary, size: 32),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produto['nome']?.toString() ?? '',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 12,
                      color: AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: GoogleFonts.poppins(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
                if (cat.isNotEmpty)
                  Text(cat,
                      style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== SHIMMER DE EMPRESA =====================
class _ShimmerEmpresa extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShimmerBanner(),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [
              ShimmerCard(),
              ShimmerCard(),
              ShimmerCard(),
            ],
          ),
        ),
      ],
    );
  }
}

// ===================== BANNER =====================
class _BannerItem extends StatelessWidget {
  final String texto;
  const _BannerItem(this.texto);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Center(
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
}
