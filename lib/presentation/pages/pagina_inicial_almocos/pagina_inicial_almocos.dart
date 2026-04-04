import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/floating_cart.dart';
import '../../widgets/shimmer_card.dart';

class PaginaInicialAlmocos extends StatefulWidget {
  const PaginaInicialAlmocos({super.key});

  @override
  State<PaginaInicialAlmocos> createState() => _PaginaInicialAlmocosState();
}

class _PaginaInicialAlmocosState extends State<PaginaInicialAlmocos> {
  final PageController _bannerController = PageController();
  int _bannerAtual = 0;
  List<Map<String, dynamic>> _produtos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarProdutos();
  }

  Future<void> _carregarProdutos() async {
    setState(() => _carregando = true);
    final lista = await ApiService.getProdutosPublico(categoria: 'Almoços');
    if (!mounted) return;
    setState(() { _produtos = lista; _carregando = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        centerTitle: true,
        title: Text('Almoços',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _carregarProdutos,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _banner(),
              const SizedBox(height: 20),
              Text('Cardápio',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              _carregando
                  ? SizedBox(
                      height: 180,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: const [ShimmerCard(), ShimmerCard(), ShimmerCard()],
                      ),
                    )
                  : _produtos.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text('Nenhum produto disponível no momento.',
                                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
                          ),
                        )
                      : SizedBox(
                          height: 180,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _produtos.length,
                            itemBuilder: (_, i) => _CardProduto(produto: _produtos[i]),
                          ),
                        ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      floatingActionButton: const FloatingCart(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _banner() {
    return SizedBox(
      height: 160,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView(
            controller: _bannerController,
            onPageChanged: (i) => setState(() => _bannerAtual = i),
            children: const [
              _BannerItem('Almoços', 'Pratos do dia fresquinhos!'),
              _BannerItem('Almoços', 'Peça agora e receba em casa'),
            ],
          ),
          Positioned(
            bottom: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (i) {
                final ativo = _bannerAtual == i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: ativo ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: ativo ? AppColors.primary : Colors.white.withValues(alpha: 0.6),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardProduto extends StatelessWidget {
  final Map<String, dynamic> produto;
  const _CardProduto({required this.produto});

  @override
  Widget build(BuildContext context) {
    final precoRaw = produto['preco'];
    final preco = precoRaw is num
        ? precoRaw.toDouble()
        : double.tryParse(precoRaw?.toString() ?? '') ?? 0.0;
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              height: 90, width: 140,
              color: AppColors.primary.withValues(alpha: 0.12),
              child: const Icon(Icons.restaurant, color: AppColors.primary, size: 36),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(produto['nome']?.toString() ?? '',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 13,
                        color: AppColors.textPrimary),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerItem extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  const _BannerItem(this.titulo, this.subtitulo);

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(titulo, style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
              Text(subtitulo, style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
