import 'package:flutter/foundation.dart';

class CartItem {
  final String nome;
  final String preco;
  final String imgPath;
  int quantidade;

  CartItem({
    required this.nome,
    required this.preco,
    required this.imgPath,
    this.quantidade = 0,
  });

  double get precoNumerico {
    final limpo = preco
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    return double.tryParse(limpo) ?? 0;
  }

  double get subtotal => precoNumerico * quantidade;
}

class Cart extends ChangeNotifier {
  Cart._();
  static final Cart instance = Cart._();

  final List<CartItem> _itens = [];

  List<CartItem> get itens =>
      List.unmodifiable(_itens.where((i) => i.quantidade > 0));

  double get total => _itens.fold(0.0, (s, i) => s + i.subtotal);

  int get totalItens => _itens.fold(0, (s, i) => s + i.quantidade);

  int quantidadeDe(String nome) {
    try {
      return _itens.firstWhere((i) => i.nome == nome).quantidade;
    } catch (_) {
      return 0;
    }
  }

  void adicionar(String nome, String preco, String imgPath) {
    final idx = _itens.indexWhere((i) => i.nome == nome);
    if (idx >= 0) {
      _itens[idx].quantidade++;
    } else {
      _itens.add(CartItem(nome: nome, preco: preco, imgPath: imgPath, quantidade: 1));
    }
    notifyListeners();
  }

  void remover(String nome) {
    final idx = _itens.indexWhere((i) => i.nome == nome);
    if (idx >= 0 && _itens[idx].quantidade > 0) {
      _itens[idx].quantidade--;
      if (_itens[idx].quantidade == 0) _itens.removeAt(idx);
      notifyListeners();
    }
  }

  String get totalFormatado =>
      'R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}';
}
