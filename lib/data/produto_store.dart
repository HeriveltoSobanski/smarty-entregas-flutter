import 'dart:typed_data';

class Produto {
  final String id;
  String nome;
  String ingredientes;
  String tipo; // 'Lanches', 'Almoços', 'Sobremesas', 'Pizzas', 'Bebidas'
  Uint8List? fotoBytes;
  bool ativo;
  double preco;
  final DateTime criadoEm;

  Produto({
    required this.id,
    required this.nome,
    required this.ingredientes,
    required this.tipo,
    this.fotoBytes,
    this.ativo = true,
    required this.preco,
    required this.criadoEm,
  });
}

class ProdutoStore {
  static final List<Produto> _produtos = [];

  static List<Produto> get todos => List.unmodifiable(_produtos);

  static List<Produto> porTipo(String tipo) =>
      _produtos.where((p) => p.tipo == tipo && p.ativo).toList();

  static void adicionar(Produto p) => _produtos.add(p);

  static void remover(String id) =>
      _produtos.removeWhere((p) => p.id == id);

  static void toggleAtivo(String id) {
    final idx = _produtos.indexWhere((p) => p.id == id);
    if (idx != -1) _produtos[idx].ativo = !_produtos[idx].ativo;
  }
}
