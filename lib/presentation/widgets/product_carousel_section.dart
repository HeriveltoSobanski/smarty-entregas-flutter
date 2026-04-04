import 'package:flutter/material.dart';

class ProductCarouselSection extends StatelessWidget {
  final String title;
  final List<Map<String, String>> products;
  final VoidCallback onVerMais;

  const ProductCarouselSection({
    super.key,
    required this.title,
    required this.products,
    required this.onVerMais,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho da Seção (Título e Botão Ver Mais)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: Colors.brown,
                ),
              ),
              TextButton(
                onPressed: onVerMais, // Aqui o "Ver Mais" funciona
                child: const Text(
                  'Ver mais',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        // Lista Horizontal de Produtos
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final item = products[index];
              return _buildCard(item);
            },
          ),
        ),
      ],
    );
  }

  // O "Desenho" de cada quadradinho de comida
  Widget _buildCard(Map<String, String> item) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              item['imagem']!,
              height: 70,
              width: 70,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.fastfood, size: 50, color: Colors.orange),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item['nome']!,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            item['preco']!,
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}