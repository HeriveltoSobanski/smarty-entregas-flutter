import 'package:flutter/material.dart';

// AJUSTE os caminhos abaixo conforme sua estrutura de pastas:
import '../pagina_inicial_lanches/pagina_inicial_lanches.dart';
import '../pagina_inicial_sobremesas/pagina_inicial_sobremesas.dart';
import '../pagina_inicial_almocos/pagina_inicial_almocos.dart';
import '../pagina_inicial_pizza/pagina_inicial_pizza.dart';
import '../pagina_inicial_bebidas/pagina_inicial_bebidas.dart';
import '../pagina_inicial_dono/pagina_inicial_dono.dart';

class SubcategoriasPage extends StatelessWidget {
  const SubcategoriasPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color corSmarty = Color(0xFFFFA726);

    // Mapeamento direto: cada card já sabe qual página abrir
    final List<_Categoria> categorias = <_Categoria>[
      _Categoria(
          "Lanches", Icons.lunch_dining, () => const PaginaInicialLanches()),
      _Categoria(
          "Almoços", Icons.rice_bowl, () => const PaginaInicialAlmocos()),
      _Categoria(
          "Sobremesas", Icons.icecream, () => const PaginaInicialSobremesas()),
      _Categoria("Pizzas", Icons.local_pizza, () => const PaginaInicialPizza()),
      _Categoria(
          "Bebidas", Icons.local_cafe, () => const PaginaInicialBebidas()),
    ];

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 253, 253, 253),
      appBar: AppBar(
        backgroundColor: corSmarty,
        elevation: 0,
        title: const Text(
          "Restaurantes",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      // GRID DE CATEGORIAS
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categorias.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 2 colunas
          crossAxisSpacing: 16, // espaço horizontal
          mainAxisSpacing: 16, // espaço vertical
        ),
        itemBuilder: (context, index) {
          final c = categorias[index];

          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => c.pageBuilder()),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    // lista não-const por causa do withOpacity
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(c.icon, color: corSmarty, size: 45),
                    const SizedBox(height: 10),
                    Text(
                      c.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),

      // ATALHO DO DONO (abre a pagina_inicial_dono)
      floatingActionButton: FloatingActionButton(
        backgroundColor: corSmarty,
        child: const Icon(Icons.key),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PaginaInicialDono()),
          );
        },
      ),
    );
  }
}

// Classe de mapeamento (rótulo, ícone e construtor da página)
class _Categoria {
  final String label;
  final IconData icon;
  final Widget Function() pageBuilder;

  _Categoria(this.label, this.icon, this.pageBuilder);
}
