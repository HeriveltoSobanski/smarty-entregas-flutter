import 'package:flutter/material.dart';

class SubcategoriasPage extends StatelessWidget {
  const SubcategoriasPage({super.key});

  @override
  Widget build(BuildContext context) {
    final categorias = [
      {"icone": Icons.lunch_dining, "nome": "Lanches"},
      {"icone": Icons.rice_bowl, "nome": "Almoços"},
      {"icone": Icons.icecream, "nome": "Sobremesas"},
      {"icone": Icons.local_pizza, "nome": "Pizzas"},
      {"icone": Icons.local_cafe, "nome": "Bebidas"},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Restaurantes"),
        backgroundColor: Colors.orange,
        centerTitle: true,
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        children: categorias.map((cat) {
          return GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("${cat["nome"]} em breve!")),
              );
            },
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(cat["icone"] as IconData,
                      color: Colors.orange, size: 40),
                  const SizedBox(height: 10),
                  Text(cat["nome"] as String,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
