import 'package:flutter_test/flutter_test.dart';
import 'package:smarty_entregas/core/cart/cart.dart';

final _empresaA = {'id_empresa': 1, 'nome': 'Restaurante A'};

CartItem _item({
  int idProduto = 1,
  int idEmpresa = 1,
  String nome = 'Pizza',
  double preco = 40.0,
  int quantidade = 1,
  List<Map<String, dynamic>> adicionais = const [],
  String? observacao,
}) =>
    CartItem(
      idProduto: idProduto,
      idEmpresa: idEmpresa,
      nome: nome,
      preco: preco,
      imgPath: 'img.jpg',
      adicionais: adicionais,
      observacao: observacao,
      quantidade: quantidade,
    );

void main() {
  late Cart cart;

  setUp(() => cart = Cart.testInstance());

  group('CartItem', () {
    test('subtotal = preco * quantidade', () {
      final item = _item(preco: 10.0, quantidade: 3);
      expect(item.subtotal, closeTo(30.0, 0.001));
    });

    test('resumoAdicionais vazio quando sem adicionais', () {
      expect(_item().resumoAdicionais, '');
    });

    test('resumoAdicionais lista nomes separados por virgula', () {
      final item = _item(adicionais: [
        {'id_adicional': 1, 'nome': 'Borda'},
        {'id_adicional': 2, 'nome': 'Extra queijo'},
      ]);
      expect(item.resumoAdicionais, 'Borda, Extra queijo');
    });

    test('adicionaisIds extrai ids corretamente', () {
      final item = _item(adicionais: [
        {'id_adicional': 1, 'nome': 'Borda'},
        {'id_adicional': 2, 'nome': 'Extra'},
      ]);
      expect(item.adicionaisIds, [1, 2]);
    });

    test('toItemCheckout retorna mapa correto', () {
      final item = _item(idProduto: 5, nome: 'X-Burguer', preco: 25.0, quantidade: 2);
      final m = item.toItemCheckout();
      expect(m['id_produto'], 5);
      expect(m['nome'], 'X-Burguer');
      expect(m['preco'], 25.0);
      expect(m['quantidade'], 2);
    });
  });

  group('Cart.adicionarItem', () {
    test('adiciona novo item', () {
      cart.adicionarItem(_item(), _empresaA);
      expect(cart.itens.length, 1);
      expect(cart.itens.first.nome, 'Pizza');
    });

    test('incrementa quantidade se mesmo produto e adicionais', () {
      cart.adicionarItem(_item(), _empresaA);
      cart.adicionarItem(_item(), _empresaA);
      expect(cart.itens.length, 1);
      expect(cart.itens.first.quantidade, 2);
    });

    test('cria entrada separada para adicionais diferentes', () {
      cart.adicionarItem(_item(adicionais: [{'id_adicional': 1, 'nome': 'A'}]), _empresaA);
      cart.adicionarItem(_item(adicionais: [{'id_adicional': 2, 'nome': 'B'}]), _empresaA);
      expect(cart.itens.length, 2);
    });

    test('define empresa corretamente', () {
      cart.adicionarItem(_item(), _empresaA);
      expect(cart.empresa?['id_empresa'], 1);
    });
  });

  group('Cart.remover', () {
    test('decrementa quantidade', () {
      cart.adicionarItem(_item(quantidade: 2), _empresaA);
      cart.remover(1);
      expect(cart.itens.first.quantidade, 1);
    });

    test('remove item quando quantidade chega a zero', () {
      cart.adicionarItem(_item(), _empresaA);
      cart.remover(1);
      expect(cart.itens, isEmpty);
    });

    test('limpa empresa quando carrinho fica vazio', () {
      cart.adicionarItem(_item(), _empresaA);
      cart.remover(1);
      expect(cart.empresa, isNull);
    });

    test('remover item inexistente nao causa erro', () {
      expect(() => cart.remover(99), returnsNormally);
    });
  });

  group('Cart.quantidadeDe', () {
    test('retorna zero para produto nao adicionado', () {
      expect(cart.quantidadeDe(1), 0);
    });

    test('soma quantidades de todas as entradas com mesmo idProduto', () {
      cart.adicionarItem(_item(adicionais: [{'id_adicional': 1, 'nome': 'A'}]), _empresaA);
      cart.adicionarItem(_item(adicionais: [{'id_adicional': 2, 'nome': 'B'}]), _empresaA);
      expect(cart.quantidadeDe(1), 2);
    });
  });

  group('Cart.total', () {
    test('zero quando vazio', () {
      expect(cart.total, 0.0);
    });

    test('soma subtotais de todos os itens', () {
      cart.adicionarItem(_item(preco: 40.0, quantidade: 2), _empresaA);
      cart.adicionarItem(_item(idProduto: 2, nome: 'Suco', preco: 8.0), _empresaA);
      expect(cart.total, closeTo(88.0, 0.001));
    });
  });

  group('Cart.totalFormatado', () {
    test('formato brasileiro correto', () {
      cart.adicionarItem(_item(preco: 10.50), _empresaA);
      expect(cart.totalFormatado, 'R\$ 10,50');
    });
  });

  group('Cart.conflitaComEmpresa', () {
    test('false quando carrinho vazio', () {
      expect(cart.conflitaComEmpresa(99), false);
    });

    test('false quando mesma empresa', () {
      cart.adicionarItem(_item(), _empresaA);
      expect(cart.conflitaComEmpresa(1), false);
    });

    test('true quando empresa diferente', () {
      cart.adicionarItem(_item(), _empresaA);
      expect(cart.conflitaComEmpresa(2), true);
    });
  });

  group('Cart.limpar', () {
    test('remove todos os itens e empresa', () {
      cart.adicionarItem(_item(), _empresaA);
      cart.limpar();
      expect(cart.itens, isEmpty);
      expect(cart.empresa, isNull);
      expect(cart.total, 0.0);
    });
  });
}
