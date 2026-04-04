import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../cardapio_empresa/cardapio_empresa_page.dart';

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
  List<Map<String, dynamic>> _empresas = [];
  bool _carregando = true;
  String _categoriaSel = '';

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
    const Color corSmarty = Color(0xFFFFA726);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        titleSpacing: 8,
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              width: 40,
              height: 40,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.delivery_dining, color: corSmarty),
            ),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Smarty Entregas',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
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
      body: RefreshIndicator(
        color: corSmarty,
        onRefresh: () => _carregar(categoria: _categoriaSel),
        child: CustomScrollView(
          slivers: [
            // Campo de busca
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar produtos ou lojas...',
                    prefixIcon: const Icon(Icons.search, color: corSmarty),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),

            // Banner rotativo
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  height: 150,
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
                      Positioned(
                        bottom: 8,
                        child: Row(
                          children: List.generate(2, (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _bannerAtual == i
                                  ? Colors.white
                                  : Colors.white54,
                            ),
                          )),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Filtro de categorias horizontal
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _categorias.length,
                  itemBuilder: (_, i) {
                    final cat = _categorias[i]['nome'] as String;
                    final sel = _categoriaSel == cat ||
                        (_categoriaSel.isEmpty && cat == 'Todos');
                    return GestureDetector(
                      onTap: () {
                        setState(() => _categoriaSel = cat == 'Todos' ? '' : cat);
                        _carregar(categoria: cat);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? corSmarty : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? corSmarty : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: sel ? Colors.white : Colors.black87,
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

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Título
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _categoriaSel.isEmpty || _categoriaSel == 'Todos'
                      ? 'Todos os restaurantes'
                      : _categoriaSel,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // Lista de empresas
            if (_carregando)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: corSmarty),
                ),
              )
            else if (_empresas.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Nenhum restaurante disponível',
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
                      SizedBox(height: 4),
                      Text('Aguarde novos estabelecimentos',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final empresa = _empresas[index];
                    return _CardEmpresa(empresa: empresa);
                  },
                  childCount: _empresas.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: corSmarty,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Busca'),
          BottomNavigationBarItem(
              icon: Icon(Icons.list_alt), label: 'Pedidos'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

// ===================== CARD DE EMPRESA =====================
class _CardEmpresa extends StatelessWidget {
  final Map<String, dynamic> empresa;
  const _CardEmpresa({required this.empresa});

  void _abrirCardapio(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardapioEmpresaPage(empresa: empresa),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const corSmarty = Color(0xFFFFA726);
    final produtos =
        List<Map<String, dynamic>>.from(empresa['produtos'] as List? ?? []);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da empresa
          GestureDetector(
            onTap: () => _abrirCardapio(context),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFA726), Color(0xFFFFEB3B)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        color: corSmarty, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          empresa['nome']?.toString() ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${produtos.length} produto${produtos.length != 1 ? 's' : ''}',
                          style: const TextStyle(
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
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: produtos.length,
              itemBuilder: (_, i) => _CardProduto(produto: produtos[i]),
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
    final preco = precoRaw is num ? precoRaw.toDouble()
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
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagem / ícone
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              height: 75,
              width: double.infinity,
              color: const Color(0xFFFFA726).withValues(alpha: 0.15),
              child: Icon(icone, color: const Color(0xFFFFA726), size: 32),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produto['nome']?.toString() ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'R\$ ${preco.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
                if (cat.isNotEmpty)
                  Text(cat,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
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
            colors: [Color(0xFFFFA726), Color(0xFFFF6F00)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Center(
          child: Text(
            texto,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
