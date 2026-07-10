import 'package:backend/controllers/pedido_controller.dart';
import 'package:test/test.dart';

void main() {
  group('transicaoStatusValida', () {
    test('transicoes validas a partir de Aguardando (1)', () {
      expect(transicaoStatusValida(1, 2), isTrue);
      expect(transicaoStatusValida(1, 3), isTrue);
      expect(transicaoStatusValida(1, 5), isTrue);
      expect(transicaoStatusValida(1, 6), isTrue);
    });

    test('nao permite pular etapas ate Entregue', () {
      expect(transicaoStatusValida(1, 4), isFalse);
      expect(transicaoStatusValida(2, 4), isFalse);
    });

    test('Aguardando Motoboy (6) so vai para A Caminho (3) ou Cancelado (5)', () {
      expect(transicaoStatusValida(6, 3), isTrue);
      expect(transicaoStatusValida(6, 5), isTrue);
      expect(transicaoStatusValida(6, 4), isFalse);
      expect(transicaoStatusValida(6, 2), isFalse);
    });

    test('estados terminais (Entregue/Cancelado) nao permitem saida', () {
      expect(transicaoStatusValida(4, 3), isFalse);
      expect(transicaoStatusValida(5, 1), isFalse);
    });

    test('mesmo status e no-op valido; origem null e invalida', () {
      expect(transicaoStatusValida(2, 2), isTrue);
      expect(transicaoStatusValida(null, 2), isFalse);
    });
  });
}
