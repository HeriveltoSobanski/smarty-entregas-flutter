import 'package:flutter/material.dart';

class PaginaInicialPizza extends StatefulWidget {
  const PaginaInicialPizza({super.key});

  @override
  State<PaginaInicialPizza> createState() => _PaginaInicialPizzaState();
}

class _PaginaInicialPizzaState extends State<PaginaInicialPizza> {
  final PageController _bannerController = PageController();
  int _bannerAtual = 0;

  @override
  Widget build(BuildContext context) {
    const Color corSmarty = Color(0xFFFFA726);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 253, 253, 253),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: corSmarty,
        title: const Text(
          "Pizzas",
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
                        _BannerItem('assets/banner_pizza1.png'),
                        _BannerItem('assets/banner_pizza2.png'),
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

              _tituloSecao("Promoções de Pizzas", corSmarty),
              const SizedBox(height: 8),

              // Cards de promoções
              SizedBox(
                height: 170,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _promoCard("Pizza Calabresa", "R\$ 39,90",
                        "assets/pizza_calabresa.png"),
                    _promoCard("Pizza Portuguesa", "R\$ 42,00",
                        "assets/pizza_portuguesa.png"),
                    _promoCard("Pizza Frango c/ Catupiry", "R\$ 41,50",
                        "assets/pizza_frango.png"),
                    _promoCard("Pizza Margherita", "R\$ 38,90",
                        "assets/pizza_margherita.png"),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _tituloSecao("Mais Pedidas", corSmarty),
              const SizedBox(height: 8),

              // Cards de mais pedidas
              SizedBox(
                height: 170,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _promoCard("Pizza Quatro Queijos", "R\$ 44,90",
                        "assets/pizza_quatroqueijos.png"),
                    _promoCard("Pizza Pepperoni", "R\$ 45,90",
                        "assets/pizza_pepperoni.png"),
                    _promoCard(
                        "Pizza Bacon", "R\$ 43,90", "assets/pizza_bacon.png"),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
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

  static Widget _promoCard(String nome, String preco, String imgPath) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.asset(
              imgPath,
              height: 90,
              width: 140,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFFFA726),
                height: 90,
                width: 140,
                child: const Center(
                  child: Text(
                    "Imagem",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(preco, style: const TextStyle(color: Colors.green)),
              ],
            ),
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
              colors: [Color(0xFFFFA726), Color(0xFFFFEB3B)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: const Center(
            child: Text(
              "Promoções de Pizza",
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
