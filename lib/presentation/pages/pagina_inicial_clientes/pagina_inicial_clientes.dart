import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    const Color corSmarty = Color(0xFFFFA726);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 253, 253, 253),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        titleSpacing: 8,
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              width: 45,
              height: 45,
              errorBuilder: (_, __, ___) => const Icon(Icons.delivery_dining),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Entregas em",
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
                Text(
                  "Mallet - PR",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),

      // ===================== CONTEÚDO PRINCIPAL =====================
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campo de busca
              TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar produtos ou lojas...',
                  prefixIcon: const Icon(Icons.search, color: corSmarty),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
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
                        _BannerItem('assets/banner.png'),
                        _BannerItem('assets/banner2.png'),
                        _BannerItem('assets/banner3.png'),
                      ],
                    ),
                    Positioned(
                      bottom: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
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

              // Grade de categorias
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _categoriaAtiva(
                    context,
                    Icons.restaurant,
                    "Restaurantes",
                    () {
                      Navigator.push(
                        context,
                        _animacaoSlide(const SubcategoriasPage()),
                      );
                    },
                  ),
                  _categoriaEmBreve(Icons.store, "Mercados"),
                  _categoriaEmBreve(Icons.local_pharmacy, "Farmácias"),
                  _categoriaEmBreve(Icons.pets, "Pet shops"),
                  _categoriaEmBreve(Icons.local_drink, "Bebidas"),
                  _categoriaEmBreve(Icons.shopping_bag, "Compras"),
                  _categoriaEmBreve(Icons.local_shipping, "Express"),
                  _categoriaEmBreve(Icons.more_horiz, "Mais"),
                ],
              ),
              const SizedBox(height: 20),

              // Promoções
              _tituloSecao("Promoções com entrega grátis", corSmarty),
              const SizedBox(height: 8),

              SizedBox(
                height: 170,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _promoCard(
                        "Mini Salgados", "R\$ 12,99", "assets/salgado.png"),
                    _promoCard("X-Burger", "R\$ 9,99", "assets/hamburguer.png"),
                    _promoCard("Pizza Grande", "R\$ 29,90", "assets/pizza.png"),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Cupons
              _tituloSecao("Cupons e Entregas Grátis", corSmarty),
              const SizedBox(height: 10),
              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _cupomCard("assets/loja1.png"),
                    _cupomCard("assets/loja2.png"),
                    _cupomCard("assets/loja3.png"),
                    _cupomCard("assets/loja4.png"),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),

      // ===================== BARRA INFERIOR =====================
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: corSmarty,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Busca'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Pedidos'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }

  // ===================== COMPONENTES AUXILIARES =====================

  static Route _animacaoSlide(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        final tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: anim.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  static Widget _tituloSecao(String texto, Color corSmarty) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(texto,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text("Ver mais", style: TextStyle(color: corSmarty, fontSize: 14)),
        ],
      ),
    );
  }

  static Widget _categoriaAtiva(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFA726), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.orange, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  static Widget _categoriaEmBreve(IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        contextGlobal.currentState?.showSnackBar(
          SnackBar(
            content: Text("$label disponível em breve!"),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey, width: 1.0),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.grey, size: 26),
          ),
          const SizedBox(height: 6),
          const Text("Em breve",
              style: TextStyle(fontSize: 12, color: Colors.grey)),
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
            child:
                Image.asset(imgPath, height: 90, width: 140, fit: BoxFit.cover),
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

  static Widget _cupomCard(String imgPath) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(
          image: AssetImage(imgPath),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
    );
  }
}

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
              "Banner Promocional",
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
