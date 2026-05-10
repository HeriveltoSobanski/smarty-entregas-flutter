import 'package:flutter_test/flutter_test.dart';
import 'package:smarty_entregas/models/pedido.dart';

void main() {
  group('ItemPedido.fromJson', () {
    test('campos completos', () {
      final json = {
        'id_produto': 10,
        'nome': 'Frango',
        'quantidade': 2,
        'preco': 15.0,
        'observacao': 'Sem cebola',
      };
      final item = ItemPedido.fromJson(json);
      expect(item.idProduto, 10);
      expect(item.nome, 'Frango');
      expect(item.quantidade, 2);
      expect(item.preco, 15.0);
      expect(item.observacao, 'Sem cebola');
    });

    test('campos ausentes usa defaults', () {
      final item = ItemPedido.fromJson({});
      expect(item.idProduto, 0);
      expect(item.nome, '');
      expect(item.quantidade, 1);
      expect(item.preco, 0.0);
      expect(item.observacao, isNull);
    });
  });

  group('ItemPedido.toJson', () {
    test('observacao null nao aparece no json', () {
      final item = ItemPedido(
        idProduto: 1,
        nome: 'Suco',
        quantidade: 1,
        preco: 8.0,
      );
      final json = item.toJson();
      expect(json.containsKey('observacao'), false);
    });

    test('observacao presente aparece no json', () {
      final item = ItemPedido(
        idProduto: 2,
        nome: 'Lanche',
        quantidade: 1,
        preco: 12.0,
        observacao: 'Bem passado',
      );
      expect(item.toJson()['observacao'], 'Bem passado');
    });
  });

  group('Pedido.fromJson', () {
    test('pedido completo com itens', () {
      final json = {
        'id_pedido': 99,
        'cliente': 'João',
        'status': 'em_preparo',
        'total': 50.0,
        'endereco_entrega': 'Rua A, 123',
        'tipo_entrega': 'entrega',
        'quase_pronto': false,
        'id_motoboy': 5,
        'itens': [
          {'id_produto': 1, 'nome': 'Pizza', 'quantidade': 1, 'preco': 50.0},
        ],
      };
      final p = Pedido.fromJson(json);
      expect(p.id, 99);
      expect(p.cliente, 'João');
      expect(p.status, 'em_preparo');
      expect(p.total, 50.0);
      expect(p.idMotoboy, 5);
      expect(p.itens.length, 1);
      expect(p.itens.first.nome, 'Pizza');
    });

    test('itens ausentes resulta em lista vazia', () {
      final p = Pedido.fromJson({'id_pedido': 1, 'cliente': 'Maria', 'status': 'pendente', 'total': 0.0});
      expect(p.itens, isEmpty);
    });

    test('itens nao lista resulta em lista vazia', () {
      final p = Pedido.fromJson({
        'id_pedido': 1,
        'cliente': 'X',
        'status': 'pendente',
        'total': 0.0,
        'itens': 'invalido',
      });
      expect(p.itens, isEmpty);
    });

    test('campos ausentes usa defaults', () {
      final p = Pedido.fromJson({});
      expect(p.id, 0);
      expect(p.cliente, '');
      expect(p.status, '');
      expect(p.total, 0.0);
      expect(p.quasePronto, false);
      expect(p.idMotoboy, isNull);
      expect(p.enderecoEntrega, isNull);
    });
  });
}
