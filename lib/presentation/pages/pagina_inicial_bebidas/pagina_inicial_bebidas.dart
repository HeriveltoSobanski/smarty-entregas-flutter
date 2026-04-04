import 'package:flutter/material.dart';
import '../../widgets/product_card.dart';
import '../../widgets/floating_cart.dart';
import '../../../core/theme/app_theme.dart';

class PaginaInicialBebidas extends StatefulWidget {
  const PaginaInicialBebidas({super.key});

  @override
  State<PaginaInicialBebidas> createState() => _PaginaInicialBebidasState();
}

class _PaginaInicialBebidasState extends State<PaginaInicialBebidas> {
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
          "Bebidas",
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

              // ===================== Banner rotativo =====================
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
                        _BannerItem('assets/banner_bebidas1.png'),
                        _BannerItem('assets/banner_bebidas2.png'),
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

              _tituloSecao("Promoções de Bebidas", corSmarty),
              const SizedBox(height: 8),

              // ===================== Cards de promoções =====================
              SizedBox(
                height: 260,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: const [
                    ProductCard(nome: "Coca-Cola Lata", preco: "R\$ 4,99", imgPath: "assets/coca_lata.png"),
                    ProductCard(nome: "Guaraná 2L", preco: "R\$ 8,99", imgPath: "assets/guarana_2l.png"),
                    ProductCard(nome: "Água Mineral", preco: "R\$ 2,50", imgPath: "assets/agua.png"),
                    ProductCard(nome: "Suco Natural", preco: "R\$ 6,99", imgPath: "assets/suco.png"),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _tituloSecao("Mais Pedidas", corSmarty),
              const SizedBox(height: 8),

              // ===================== Cards de mais pedidas =====================
              SizedBox(
                height: 260,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: const [
                    ProductCard(nome: "Cerveja Heineken", preco: "R\$ 7,50", imgPath: "assets/heineken.png"),
                    ProductCard(nome: "Refrigerante Pepsi", preco: "R\$ 5,50", imgPath: "assets/pepsi.png"),
                    ProductCard(nome: "Energético Monster", preco: "R\$ 10,99", imgPath: "assets/monster.png"),
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
              "Promoção de Bebidas",
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
