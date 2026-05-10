import 'package:flutter_test/flutter_test.dart';
import 'package:smarty_entregas/core/cart/cart.dart';

void main() {
  late Cart cart;

  setUp(() {
    cart = Cart.testInstance();
  });

  group('CartItem.precoNumerico', () {
    test('formato R\$ com virgula', () {
      final item = CartItem(nome: 'X', preco: 'R\$ 29,90', imgPath: '');
      expect(item.precoNumerico, closeTo(29.90, 0.001));
    });

    test('formato sem simbolo com ponto', () {
      final item = CartItem(nome: 'X', preco: '15.50', imgPath: '');
      expect(item.precoNumerico, closeTo(15.50, 0.001));
    });

    test('preco invalido retorna zero', () {
      final item = CartItem(nome: 'X', preco: 'abc', imgPath: '');
      expect(item.precoNumerico, 0.0);
    });

    test('subtotal = preco * quantidade', () {
      final item = CartItem(nome: 'X', preco: 'R\$ 10,00', imgPath: '', quantidade: 3);
      expect(item.subtotal, closeTo(30.0, 0.001));
    });
  });

  group('Cart.adicionar', () {
    test('adiciona novo item', () {
      cart.adicionar('Pizza', 'R\$ 40,00', 'img.jpg');
      expect(cart.itens.length, 1);
      expect(cart.itens.first.nome, 'Pizza');
      expect(cart.itens.first.quantidade, 1);
    });

    test('incrementa quantidade de item existente', () {
      cart.adicionar('Pizza', 'R\$ 40,00', 'img.jpg');
      cart.adicionar('Pizza', 'R\$ 40,00', 'img.jpg');
      expect(cart.itens.length, 1);
      expect(cart.itens.first.quantidade, 2);
    });

    test('itens diferentes ficam separados', () {
      cart.adicionar('Pizza', 'R\$ 40,00', 'img.jpg');
      cart.adicionar('Suco', 'R\$ 8,00', 'suco.jpg');
      expect(cart.itens.length, 2);
    });
  });

  group('Cart.remover', () {
    test('decrementa quantidade', () {
      cart.adicionar('Pizza', 'R\$ 40,00', 'img.jpg');
      cart.adicionar('Pizza', 'R\$ 40,00', 'img.jpg');
      cart.remover('Pizza');
      expect(cart.itens.first.quantidade, 1);
    });

    test('remove item quando quantidade chega a zero', () {
      cart.adicionar('Pizza', 'R\$ 40,00', 'img.jpg');
      cart.remover('Pizza');
      expect(cart.itens, isEmpty);
    });

    test('remover item inexistente nao causa erro', () {
      expect(() => cart.remover('Inexistente'), returnsNormally);
      expect(cart.itens, isEmpty);
    });
  });

  group('Cart.total', () {
    test('total zerado quando vazio', () {
      expect(cart.total, 0.0);
    });

    test('total soma todos os itens', () {
      cart.adicionar('Pizza', 'R\$ 40,00', 'img.jpg');
      cart.adicionar('Pizza', 'R\$ 40,00', 'img.jpg');
      cart.adicionar('Suco', 'R\$ 8,00', 'suco.jpg');
      expect(cart.total, closeTo(88.0, 0.001));
    });
  });

  group('Cart.totalItens', () {
    test('zero quando vazio', () {
      expect(cart.totalItens, 0);
    });

    test('soma quantidade de todos os itens', () {
      cart.adicionar('A', 'R\$ 10,00', '');
      cart.adicionar('A', 'R\$ 10,00', '');
      cart.adicionar('B', 'R\$ 5,00', '');
      expect(cart.totalItens, 3);
    });
  });

  group('Cart.totalFormatado', () {
    test('formato brasileiro correto', () {
      cart.adicionar('Item', 'R\$ 10,50', '');
      expect(cart.totalFormatado, 'R\$ 10,50');
    });
  });

  group('Cart.quantidadeDe', () {
    test('retorna zero para item nao adicionado', () {
      expect(cart.quantidadeDe('X'), 0);
    });

    test('retorna quantidade correta', () {
      cart.adicionar('Pizza', 'R\$ 40,00', '');
      cart.adicionar('Pizza', 'R\$ 40,00', '');
      expect(cart.quantidadeDe('Pizza'), 2);
    });
  });
}
