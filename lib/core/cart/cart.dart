import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/app_logger.dart';

class CartItem {
  final int idProduto;
  final int idEmpresa;
  final String nome;
  final double preco; // preço unitário já incluindo adicionais
  final String imgPath;
  final List<Map<String, dynamic>> adicionais;
  final String? observacao;
  int quantidade;

  CartItem({
    required this.idProduto,
    required this.idEmpresa,
    required this.nome,
    required this.preco,
    required this.imgPath,
    this.adicionais = const [],
    this.observacao,
    this.quantidade = 1,
  });

  double get subtotal => preco * quantidade;

  String get resumoAdicionais =>
      adicionais.map((a) => a['nome']?.toString() ?? '').join(', ');

  List<int> get adicionaisIds => adicionais
      .map((a) {
        final v = a['id_adicional'];
        return v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
      })
      .where((id) => id > 0)
      .toList();

  Map<String, dynamic> toItemCheckout() => {
        'id_produto': idProduto,
        'nome': nome,
        'preco': preco,
        'quantidade': quantidade,
        'adicionais': resumoAdicionais,
        'adicionais_ids': adicionaisIds,
        'observacao': observacao ?? '',
      };

  Map<String, dynamic> toJson() => {
        'idProduto': idProduto,
        'idEmpresa': idEmpresa,
        'nome': nome,
        'preco': preco,
        'imgPath': imgPath,
        'adicionais': adicionais,
        'observacao': observacao,
        'quantidade': quantidade,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        idProduto: json['idProduto'] as int? ?? 0,
        idEmpresa: json['idEmpresa'] as int? ?? 0,
        nome: json['nome'] as String? ?? '',
        preco: (json['preco'] as num?)?.toDouble() ?? 0.0,
        imgPath: json['imgPath'] as String? ?? '',
        adicionais: (json['adicionais'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        observacao: json['observacao'] as String?,
        quantidade: json['quantidade'] as int? ?? 1,
      );
}

class Cart extends ChangeNotifier {
  Cart._();
  static final Cart instance = Cart._();

  // ignore: prefer_constructors_over_static_methods
  static Cart testInstance() => Cart._();

  static const _prefsKey      = 'cart_items';
  static const _prefsEmpresa  = 'cart_empresa';

  Map<String, dynamic>? _empresa;
  final List<CartItem> _itens = [];

  Map<String, dynamic>? get empresa => _empresa;

  List<CartItem> get itens => List.unmodifiable(_itens);

  double get total => _itens.fold(0.0, (s, i) => s + i.subtotal);

  int get totalItens => _itens.fold(0, (s, i) => s + i.quantidade);

  String get totalFormatado =>
      'R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}';

  bool get isEmpty => _itens.isEmpty;

  /// Retorna true se carrinho tem itens de outro restaurante.
  bool conflitaComEmpresa(int idEmpresa) =>
      _itens.isNotEmpty && _empresa?['id_empresa'] != idEmpresa;

  int quantidadeDe(int idProduto) => _itens
      .where((i) => i.idProduto == idProduto)
      .fold(0, (s, i) => s + i.quantidade);

  /// Adiciona item ao carrinho. Chame [conflitaComEmpresa] antes se necessário.
  void adicionarItem(CartItem item, Map<String, dynamic> empresa) {
    _empresa = empresa;
    // Se mesmo produto + mesmos adicionais, incrementa. Senão, nova entrada.
    final idx = _itens.indexWhere((i) =>
        i.idProduto == item.idProduto &&
        _mesmasAdicionais(i.adicionaisIds, item.adicionaisIds));
    if (idx >= 0) {
      _itens[idx].quantidade += item.quantidade;
    } else {
      _itens.add(item);
    }
    notifyListeners();
    _salvar();
  }

  void remover(int idProduto) {
    final idx = _itens.lastIndexWhere((i) => i.idProduto == idProduto);
    if (idx < 0) return;
    if (_itens[idx].quantidade > 1) {
      _itens[idx].quantidade--;
    } else {
      _itens.removeAt(idx);
    }
    if (_itens.isEmpty) _empresa = null;
    notifyListeners();
    _salvar();
  }

  void limpar() {
    _itens.clear();
    _empresa = null;
    notifyListeners();
    _salvar();
  }

  Future<void> carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawItens   = prefs.getString(_prefsKey);
      final rawEmpresa = prefs.getString(_prefsEmpresa);
      if (rawItens != null) {
        final lista = jsonDecode(rawItens) as List<dynamic>;
        _itens
          ..clear()
          ..addAll(lista.map((e) => CartItem.fromJson(e as Map<String, dynamic>)));
      }
      if (rawEmpresa != null) {
        _empresa = jsonDecode(rawEmpresa) as Map<String, dynamic>;
      }
      if (_itens.isNotEmpty) notifyListeners();
    } catch (e, st) {
      AppLogger.e('Cart', e, st);
    }
  }

  Future<void> _salvar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_itens.map((i) => i.toJson()).toList()));
      if (_empresa != null) {
        await prefs.setString(_prefsEmpresa, jsonEncode(_empresa));
      } else {
        await prefs.remove(_prefsEmpresa);
      }
    } catch (e, st) {
      AppLogger.e('Cart', e, st);
    }
  }

  bool _mesmasAdicionais(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    final sa = {...a};
    final sb = {...b};
    return sa.difference(sb).isEmpty;
  }
}
