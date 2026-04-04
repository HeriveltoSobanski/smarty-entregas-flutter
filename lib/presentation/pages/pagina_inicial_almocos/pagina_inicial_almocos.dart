import 'package:flutter/material.dart';
import '../../widgets/product_card.dart';
import '../../widgets/floating_cart.dart';
import '../../../core/theme/app_theme.dart';

class PaginaInicialAlmocos extends StatefulWidget {
  const PaginaInicialAlmocos({super.key});

  @override
  State<PaginaInicialAlmocos> createState() => _PaginaInicialAlmocosState();
}

class _PaginaInicialAlmocosState extends State<PaginaInicialAlmocos> {
  final PageController _bannerController = PageController();
  int _bannerAtual = 0;

  @override
  Widget build(BuildContext context) {
    const Color corSmarty = AppColors.primary;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 253, 253, 253),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: corSmarty,
        title: const Text(
          "Almoços",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),

      // ===================== CONTEÚDO PRINCIPAL =====================
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Banner rotativo
              SizedBox(
                height: 160,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    PageView(
                      controller: _bannerController,
                      onPageChanged: (index) {
                        setState(() {
                          _bannerAtual = index;
                        });
                      },
                      children: const [
                        _BannerItem('assets/banner_almocos1.png'),
                        _BannerItem('assets/banner_almocos2.png'),
                      ],
                    ),
                    Positioned(
                      bottom: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(2, (index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _bannerAtual == index
                                  ? corSmarty
                                  : Colors.grey[300],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _tituloSecao("Pratos do Dia", corSmarty),
              const SizedBox(height: 8),

              // Cards de pratos do dia
              SizedBox(
                height: 260,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: const [
                    ProductCard(nome: "Feijoada", preco: "R\$ 29,90", imgPath: "assets/feijoada.png"),
                    ProductCard(nome: "Strogonoff de Frango", preco: "R\$ 24,90", imgPath: "assets/strogonoff.png"),
                    ProductCard(nome: "Parmegiana de Frango", preco: "R\$ 28,90", imgPath: "assets/parmegiana.png"),
                    ProductCard(nome: "Filé Grelhado", preco: "R\$ 22,00", imgPath: "assets/filegrelhado.png"),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _tituloSecao("Mais Pedidos", corSmarty),
              const SizedBox(height: 8),

              // Cards de mais pedidos
              SizedBox(
                height: 260,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: const [
                    ProductCard(nome: "Lasanha à Bolonhesa", preco: "R\$ 26,50", imgPath: "assets/lasanha.png"),
                    ProductCard(nome: "Prato Executivo", preco: "R\$ 27,90", imgPath: "assets/pratoexecutivo.png"),
                    ProductCard(nome: "Frango Xadrez", preco: "R\$ 25,00", imgPath: "assets/frangoxadrez.png"),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      floatingActionButton: const FloatingCart(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ===================== COMPONENTES AUXILIARES =====================

  static Widget _tituloSecao(String texto, Color corSmarty) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            texto,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            "Ver mais",
            style: TextStyle(color: corSmarty, fontSize: 14),
          ),
        ],
      ),
    );
  }

}

// ===================== COMPONENTE DE BANNER =====================
class _BannerItem extends StatelessWidget {
  final String imgPath;
  const _BannerItem(this.imgPath);

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
          child: const Center(
            child: Text(
              "Promoções de Almoço",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
