import 'package:flutter/material.dart';

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
    const Color corSmarty = Color(0xFFFFA726);

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
                height: 170,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _promoCard(
                      "Feijoada",
                      "R\$ 29,90",
                      "assets/feijoada.png",
                    ),
                    _promoCard(
                      "Strogonoff de Frango",
                      "R\$ 24,90",
                      "assets/strogonoff.png",
                    ),
                    _promoCard(
                      "Parmegiana de Frango",
                      "R\$ 28,90",
                      "assets/parmegiana.png",
                    ),
                    _promoCard(
                      "Filé Grelhado",
                      "R\$ 22,00",
                      "assets/filegrelhado.png",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _tituloSecao("Mais Pedidos", corSmarty),
              const SizedBox(height: 8),

              // Cards de mais pedidos
              SizedBox(
                height: 170,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _promoCard(
                      "Lasanha à Bolonhesa",
                      "R\$ 26,50",
                      "assets/lasanha.png",
                    ),
                    _promoCard(
                      "Prato Executivo",
                      "R\$ 27,90",
                      "assets/pratoexecutivo.png",
                    ),
                    _promoCard(
                      "Frango Xadrez",
                      "R\$ 25,00",
                      "assets/frangoxadrez.png",
                    ),
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
