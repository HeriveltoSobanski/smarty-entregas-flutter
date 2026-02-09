import 'package:flutter/material.dart';

class CategoriaDetalhesPage extends StatelessWidget {
  final String titulo;

  const CategoriaDetalhesPage({super.key, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titulo, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFFFFA726)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant_menu, size: 80, color: Color(0xFFFFA726)),
            const SizedBox(height: 16),
            Text(
              "Explorar $titulo",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text("Carregando itens...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}