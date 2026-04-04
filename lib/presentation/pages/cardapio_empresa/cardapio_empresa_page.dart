import 'package:flutter/material.dart';
import '../checkout/checkout_page.dart';

const Color _cor = Color(0xFFFFA726);

class CardapioEmpresaPage extends StatefulWidget {
  final Map<String, dynamic> empresa;
  const CardapioEmpresaPage({super.key, required this.empresa});

  @override
  State<CardapioEmpresaPage> createState() => _CardapioEmpresaPageState();
}

class _CardapioEmpresaPageState extends State<CardapioEmpresaPage> {
  // id_produto -> quantidade
  final Map<int, int> _carrinho = {};

  List<Map<String, dynamic>> get _produtos =>
      List<Map<String, dynamic>>.from(widget.empresa['produtos'] as List? ?? []);

  int _idProduto(Map<String, dynamic> p) {
    final v = p['id_produto'];
    return v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
  }

  double _preco(Map<String, dynamic> p) {
    final v = p['preco'];
    return v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  double get _total => _produtos.fold(0.0, (acc, p) {
        final id = _idProduto(p);
        final qtd = _carrinho[id] ?? 0;
        return acc + _preco(p) * qtd;
      });

  int get _totalItens =>
      _carrinho.values.fold(0, (acc, q) => acc + q);

  void _incrementar(int id) => setState(() => _carrinho[id] = (_carrinho[id] ?? 0) + 1);
  void _decrementar(int id) => setState(() {
        final atual = _carrinho[id] ?? 0;
        if (atual <= 1) {
          _carrinho.remove(id);
        } else {
          _carrinho[id] = atual - 1;
        }
      });

  void _irParaCheckout() {
    final itensParaCheckout = _produtos
        .where((p) => (_carrinho[_idProduto(p)] ?? 0) > 0)
        .map((p) => {
              'id_produto': _idProduto(p),
              'nome':       p['nome'],
              'preco':      _preco(p),
              'quantidade': _carrinho[_idProduto(p)]!,
            })
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutPage(
          empresa: widget.empresa,
          itens:   itensParaCheckout,
          total:   _total,
        ),
      ),
    );
  }

  IconData _iconeCategoria(String cat) {
    if (cat == 'Bebidas') return Icons.local_drink;
    if (cat == 'Pizzas') return Icons.local_pizza;
    if (cat == 'Sobremesas') return Icons.cake;
    if (cat == 'Almoços') return Icons.restaurant;
    return Icons.fastfood;
  }

  @override
  Widget build(BuildContext context) {
    final nome = widget.empresa['nome']?.toString() ?? 'Restaurante';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _cor,
        elevation: 0,
        title: Text(nome,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _produtos.isEmpty
          ? const Center(child: Text('Nenhum produto disponível'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _produtos.length,
              itemBuilder: (_, i) {
                final p = _produtos[i];
                final id = _idProduto(p);
                final preco = _preco(p);
                final qtd = _carrinho[id] ?? 0;
                final cat = p['categoria_nome']?.toString() ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Ícone / imagem
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: _cor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_iconeCategoria(cat),
                              color: _cor, size: 32),
                        ),
                        const SizedBox(width: 12),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p['nome']?.toString() ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              if ((p['descricao']?.toString() ?? '').isNotEmpty)
                                Text(p['descricao'].toString(),
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text('R\$ ${preco.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      color: Color(0xFF4CAF50),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                        // Controles quantidade
                        Row(
                          children: [
                            if (qtd > 0) ...[
                              _BotaoQtd(
                                icone: Icons.remove,
                                onTap: () => _decrementar(id),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text('$qtd',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ),
                            ],
                            _BotaoQtd(
                              icone: Icons.add,
                              onTap: () => _incrementar(id),
                              filled: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      // Barra de carrinho
      bottomNavigationBar: _totalItens == 0
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _irParaCheckout,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('$_totalItens',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      const Text('Fazer Pedido',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('R\$ ${_total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _BotaoQtd extends StatelessWidget {
  final IconData icone;
  final VoidCallback onTap;
  final bool filled;
  const _BotaoQtd(
      {required this.icone, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: filled ? _cor : Colors.transparent,
          border: Border.all(color: _cor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icone,
            size: 18, color: filled ? Colors.white : _cor),
      ),
    );
  }
}
