import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/session_store.dart';
import '../../widgets/product_card.dart';
import '../../widgets/floating_cart.dart';
import '../../widgets/shimmer_card.dart';
import '../subcategorias/subcategorias_page.dart';

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
  bool _carregando = true;

  static const int _totalBanners = 3;

  @override
  void initState() {
    super.initState();
    // Shimmer inicial por 1.2s simulando carregamento
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _carregando = false);
    });
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

  Future<void> _onRefresh() async {
    setState(() => _carregando = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) setState(() => _carregando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Campo de busca ──────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 4,
                          offset: Offset(0, 1)),
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
              const SizedBox(height: 16),

              // ── Banner rotativo ─────────────────────────────
              Padding(
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
                          _BannerItem('assets/banner.png',
                              'Peça Agora no Smarty Entregas'),
                          _BannerItem('assets/banner2.png',
                              'Entrega Rápida em Mallet!'),
                          _BannerItem('assets/banner3.png',
                              'Promoções Imperdíveis!'),
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
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 3),
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
              const SizedBox(height: 24),

              // ── Categorias (grid 4×2) ───────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.78,
                  children: [
                    _CategoriaItem(
                      icon: Icons.restaurant,
                      label: 'Restaurantes',
                      ativo: true,
                      onTap: () => Navigator.push(
                        context,
                        _slide(const SubcategoriasPage()),
                      ),
                    ),
                    const _CategoriaItem(
                        icon: Icons.store_outlined,
                        label: 'Mercados',
                        ativo: false),
                    const _CategoriaItem(
                        icon: Icons.local_pharmacy_outlined,
                        label: 'Farmácias',
                        ativo: false),
                    const _CategoriaItem(
                        icon: Icons.pets,
                        label: 'Pet Shop',
                        ativo: false),
                    const _CategoriaItem(
                        icon: Icons.local_drink_outlined,
                        label: 'Bebidas',
                        ativo: false),
                    const _CategoriaItem(
                        icon: Icons.shopping_bag_outlined,
                        label: 'Compras',
                        ativo: false),
                    const _CategoriaItem(
                        icon: Icons.local_shipping_outlined,
                        label: 'Express',
                        ativo: false),
                    const _CategoriaItem(
                        icon: Icons.more_horiz,
                        label: 'Mais',
                        ativo: false),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Promoções com entrega grátis ────────────────
              _TituloSecao(titulo: 'Promoções com entrega grátis'),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: _carregando
                    ? ListView(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        children: const [
                          ShimmerCard(),
                          ShimmerCard(),
                          ShimmerCard(),
                        ],
                      )
                    : ListView(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        children: const [
                          ProductCard(
                            nome: 'Mini Salgados',
                            preco: 'R\$ 12,99',
                            imgPath: 'assets/salgado.png',
                            restaurante: 'Salgaderia Mallet',
                            nota: 4.8,
                            tempoEntrega: '20-30 min',
                            entregaGratis: true,
                          ),
                          ProductCard(
                            nome: 'X-Burger',
                            preco: 'R\$ 9,99',
                            imgPath: 'assets/hamburguer.png',
                            restaurante: 'Burger Mania',
                            nota: 4.6,
                            tempoEntrega: '25-40 min',
                          ),
                          ProductCard(
                            nome: 'Pizza Grande',
                            preco: 'R\$ 29,90',
                            imgPath: 'assets/pizza.png',
                            restaurante: 'Pizzaria do Zé',
                            nota: 4.9,
                            tempoEntrega: '30-45 min',
                            entregaGratis: true,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),

              // ── Cupons e Entregas Grátis ────────────────────
              _TituloSecao(titulo: 'Cupons e Entregas Grátis'),
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: const [
                    _CupomCard(
                      texto: 'R\$ 10 OFF\nno 1º pedido',
                      icone: Icons.local_offer_outlined,
                      cores: [Color(0xFFF5841F), Color(0xFFFFC107)],
                    ),
                    _CupomCard(
                      texto: 'Entrega\nGrátis',
                      icone: Icons.delivery_dining_outlined,
                      cores: [Color(0xFF4CAF50), Color(0xFF81C784)],
                    ),
                    _CupomCard(
                      texto: '20% OFF\nem pizzas',
                      icone: Icons.local_pizza_outlined,
                      cores: [Color(0xFFE53935), Color(0xFFEF9A9A)],
                    ),
                    _CupomCard(
                      texto: 'Frete\nR\$ 1,99',
                      icone: Icons.two_wheeler_outlined,
                      cores: [Color(0xFF1976D2), Color(0xFF64B5F6)],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Faixa de boas-vindas ────────────────────────
              _BemVindo(),

              const SizedBox(height: 80), // espaço para o FAB
            ],
          ),
        ),
      ),
      floatingActionButton: const FloatingCart(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── APP BAR ────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: const Color(0x1A000000),
      backgroundColor: AppColors.surface,
      titleSpacing: 16,
      title: Row(
        children: [
          // Logo circular
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/logo.png',
              width: 40,
              height: 40,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.delivery_dining,
                color: AppColors.primary,
                size: 36,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Localização
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
                        fontSize: 11, color: AppColors.textSecondary),
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

  // ─── BOTTOM NAV ─────────────────────────────────────────────────
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

  // Animação de slide para navegação
  static Route _slide(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        const begin = Offset(1.0, 0.0);
        final tween = Tween(begin: begin, end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeInOut));
        return SlideTransition(
            position: anim.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ══════════════════════════════════════════════════════════════════

/// Faixa de boas-vindas com e-mail do usuário logado
class _BemVindo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final email = SessionStore.email;
    if (email == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Bem-vindo, $email!',
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// Cabeçalho de seção com título e "Ver mais"
class _TituloSecao extends StatelessWidget {
  final String titulo;
  const _TituloSecao({required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(titulo,
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          Text(
            'Ver mais',
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

/// Item de categoria (ativo = laranja, inativo = cinza com cadeado)
class _CategoriaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ativo;
  final VoidCallback? onTap;

  const _CategoriaItem({
    required this.icon,
    required this.label,
    required this.ativo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: ativo ? 1.0 : 0.38,
      child: GestureDetector(
        onTap: ativo ? onTap : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: ativo ? AppColors.primary : AppColors.divider,
                  width: 1.5,
                ),
                boxShadow: ativo
                    ? const [
                        BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 6,
                            offset: Offset(0, 2))
                      ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon,
                      color: ativo
                          ? AppColors.primary
                          : AppColors.disabled,
                      size: 26),
                  if (!ativo)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.lock,
                            color: AppColors.disabled, size: 10),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight:
                    ativo ? FontWeight.w600 : FontWeight.w400,
                color: ativo
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de cupom com gradiente
class _CupomCard extends StatelessWidget {
  final String texto;
  final IconData icone;
  final List<Color> cores;

  const _CupomCard({
    required this.texto,
    required this.icone,
    required this.cores,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: cores,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: cores.first.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icone, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Usar',
                style: GoogleFonts.poppins(
                  color: cores.first,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner do carrossel — mostra imagem ou gradiente como fallback
class _BannerItem extends StatelessWidget {
  final String imgPath;
  final String fallbackText;
  const _BannerItem(this.imgPath, this.fallbackText);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        imgPath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Center(
            child: Text(
              fallbackText,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
