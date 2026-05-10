import 'package:flutter_test/flutter_test.dart';
import 'package:smarty_entregas/core/cart/cart.dart';

// Simula o fluxo completo: cliente abre cardápio → adiciona produtos → faz pedido

final _empresa = {'id_empresa': 5, 'nome': 'Pizzaria Central'};

CartItem _pizza({int quantidade = 1}) => CartItem(
      idProduto: 10,
      idEmpresa: 5,
      nome: 'Pizza Margherita',
      preco: 45.0,
      imgPath: '',
      adicionais: [
        {'id_adicional': 1, 'nome': 'Borda Recheada', 'preco': 8.0},
      ],
      observacao: 'Sem cebola',
      quantidade: quantidade,
    );

CartItem _refrigerante() => CartItem(
      idProduto: 20,
      idEmpresa: 5,
      nome: 'Coca-Cola 2L',
      preco: 12.0,
      imgPath: '',
      quantidade: 1,
    );

void main() {
  late Cart cart;
  setUp(() => cart = Cart.testInstance());

  group('Fluxo: adicionar itens de um restaurante', () {
    test('adicionar pizza e refri — total correto', () {
      cart.adicionarItem(_pizza(), _empresa);
      cart.adicionarItem(_refrigerante(), _empresa);

      expect(cart.totalItens, 2);
      expect(cart.total, closeTo(57.0, 0.01)); // 45 + 12
      expect(cart.empresa?['id_empresa'], 5);
    });

    test('adicionar mesma pizza duas vezes — uma entrada com quantidade 2', () {
      cart.adicionarItem(_pizza(), _empresa);
      cart.adicionarItem(_pizza(), _empresa);

      expect(cart.itens.length, 1);
      expect(cart.itens.first.quantidade, 2);
      expect(cart.total, closeTo(90.0, 0.01));
    });

    test('quantidadeDe conta todas as entradas do mesmo produto', () {
      cart.adicionarItem(_pizza(), _empresa);
      cart.adicionarItem(CartItem(
        idProduto: 10,
        idEmpresa: 5,
        nome: 'Pizza Margherita',
        preco: 45.0,
        imgPath: '',
        adicionais: [{'id_adicional': 2, 'nome': 'Extra Queijo', 'preco': 5.0}],
        quantidade: 1,
      ), _empresa);

      // Dois itens com mesmo idProduto mas adicionais diferentes
      expect(cart.itens.length, 2);
      expect(cart.quantidadeDe(10), 2);
    });
  });

  group('Fluxo: remover itens', () {
    test('remover uma unidade', () {
      cart.adicionarItem(_pizza(quantidade: 3), _empresa);
      cart.remover(10);
      expect(cart.itens.first.quantidade, 2);
    });

    test('remover ultimo item limpa empresa', () {
      cart.adicionarItem(_pizza(), _empresa);
      cart.remover(10);
      expect(cart.isEmpty, true);
      expect(cart.empresa, isNull);
    });
  });

  group('Fluxo: conflito de restaurantes', () {
    test('conflitaComEmpresa false com carrinho vazio', () {
      expect(cart.conflitaComEmpresa(99), false);
    });

    test('conflitaComEmpresa true quando adiciona produto de outro restaurante', () {
      cart.adicionarItem(_pizza(), _empresa);
      expect(cart.conflitaComEmpresa(9), true);
    });

    test('apos limpar, sem conflito com qualquer empresa', () {
      cart.adicionarItem(_pizza(), _empresa);
      cart.limpar();
      expect(cart.conflitaComEmpresa(9), false);
    });
  });

  group('Fluxo: toItemCheckout — payload para API', () {
    test('retorna mapa correto com adicionais', () {
      final item = _pizza();
      final payload = item.toItemCheckout();

      expect(payload['id_produto'],  10);
      expect(payload['nome'],        'Pizza Margherita');
      expect(payload['preco'],       45.0);
      expect(payload['quantidade'],  1);
      expect(payload['adicionais'],  'Borda Recheada');
      expect(payload['adicionais_ids'], [1]);
      expect(payload['observacao'],  'Sem cebola');
    });

    test('adicionais vazios — lista e resumo vazios', () {
      final item = _refrigerante();
      final payload = item.toItemCheckout();

      expect(payload['adicionais'],     '');
      expect(payload['adicionais_ids'], isEmpty);
      expect(payload['observacao'],     '');
    });

    test('cart.itens mapeados para API via toItemCheckout', () {
      cart.adicionarItem(_pizza(), _empresa);
      cart.adicionarItem(_refrigerante(), _empresa);

      final itensApi = cart.itens.map((i) => i.toItemCheckout()).toList();
      expect(itensApi.length, 2);
      expect(itensApi[0]['id_produto'], 10);
      expect(itensApi[1]['id_produto'], 20);
    });
  });

  group('Fluxo: limpar apos pedido confirmado', () {
    test('carrinho vazio apos limpar', () {
      cart.adicionarItem(_pizza(), _empresa);
      cart.adicionarItem(_refrigerante(), _empresa);
      cart.limpar();

      expect(cart.isEmpty, true);
      expect(cart.total, 0.0);
      expect(cart.totalItens, 0);
      expect(cart.empresa, isNull);
    });
  });
}
