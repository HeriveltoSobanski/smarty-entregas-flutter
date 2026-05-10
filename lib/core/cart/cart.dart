import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/app_logger.dart';

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

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'preco': preco,
        'imgPath': imgPath,
        'quantidade': quantidade,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        nome: json['nome'] as String? ?? '',
        preco: json['preco'] as String? ?? '',
        imgPath: json['imgPath'] as String? ?? '',
        quantidade: json['quantidade'] as int? ?? 0,
      );
}

class Cart extends ChangeNotifier {
  Cart._();
  static final Cart instance = Cart._();

  // ignore: prefer_constructors_over_static_methods
  static Cart testInstance() => Cart._();

  static const _prefsKey = 'cart_items';

  final List<CartItem> _itens = [];

  List<CartItem> get itens =>
      List.unmodifiable(_itens.where((i) => i.quantidade > 0));

  double get total => _itens.fold(0.0, (s, i) => s + i.subtotal);

  int get totalItens => _itens.fold(0, (s, i) => s + i.quantidade);

  String get totalFormatado =>
      'R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}';

  int quantidadeDe(String nome) {
    try {
      return _itens.firstWhere((i) => i.nome == nome).quantidade;
    } catch (e, st) {
      AppLogger.e('Cart', e, st);
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
    _salvar();
  }

  void remover(String nome) {
    final idx = _itens.indexWhere((i) => i.nome == nome);
    if (idx >= 0 && _itens[idx].quantidade > 0) {
      _itens[idx].quantidade--;
      if (_itens[idx].quantidade == 0) _itens.removeAt(idx);
      notifyListeners();
      _salvar();
    }
  }

  void limpar() {
    _itens.clear();
    notifyListeners();
    _salvar();
  }

  Future<void> carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final lista = jsonDecode(raw) as List<dynamic>;
      _itens
        ..clear()
        ..addAll(lista
            .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .where((i) => i.quantidade > 0));
      notifyListeners();
    } catch (e, st) {
      AppLogger.e('Cart', e, st);
    }
  }

  Future<void> _salvar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_itens.map((i) => i.toJson()).toList()));
    } catch (e, st) {
      AppLogger.e('Cart', e, st);
    }
  }
}
