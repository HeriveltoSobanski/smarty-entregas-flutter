import 'package:flutter/material.dart';

class PaginaInicialDono extends StatefulWidget {
  const PaginaInicialDono({super.key});

  @override
  State<PaginaInicialDono> createState() => _PaginaInicialDonoState();
}

class _PaginaInicialDonoState extends State<PaginaInicialDono> {
  @override
  Widget build(BuildContext context) {
    const Color corSmarty = Color(0xFFFFA726);

    final List<_PainelOpcao> opcoes = [
      _PainelOpcao(
        icone: Icons.people_alt,
        titulo: "Funcionários",
        descricao: "Gerencie colaboradores e permissões de acesso.",
        cor: Colors.blueAccent,
      ),
      _PainelOpcao(
        icone: Icons.fastfood,
        titulo: "Produtos",
        descricao: "Adicione, edite ou remova produtos do catálogo.",
        cor: Colors.green,
      ),
      _PainelOpcao(
        icone: Icons.shopping_cart,
        titulo: "Pedidos",
        descricao: "Acompanhe pedidos realizados em tempo real.",
        cor: Colors.orange,
      ),
      _PainelOpcao(
        icone: Icons.bar_chart,
        titulo: "Relatórios",
        descricao: "Visualize lucros, vendas e métricas do sistema.",
        cor: Colors.purple,
      ),
      _PainelOpcao(
        icone: Icons.settings,
        titulo: "Configurações",
        descricao: "Ajuste preferências e controle o sistema.",
        cor: Colors.grey,
      ),
      _PainelOpcao(
        icone: Icons.verified_user,
        titulo: "Meu Perfil",
        descricao: "Dados pessoais, segurança e acesso do dono.",
        cor: Colors.teal,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      appBar: AppBar(
        backgroundColor: corSmarty,
        elevation: 0,
        title: const Text(
          "Painel do Dono",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      // ===================== CONTEÚDO PRINCIPAL =====================
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: opcoes.length,
          itemBuilder: (context, index) {
            final opcao = opcoes[index];
            return GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Abrindo ${opcao.titulo}..."),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      backgroundColor: opcao.cor.withOpacity(0.15),
                      radius: 35,
                      child: Icon(opcao.icone, color: opcao.cor, size: 35),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      opcao.titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        opcao.descricao,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ===================== CLASSE DE DADOS DOS CARDS =====================
class _PainelOpcao {
  final IconData icone;
  final String titulo;
  final String descricao;
  final Color cor;

  _PainelOpcao({
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.cor,
  });
}
