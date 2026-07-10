import 'package:backend/services/pix_brcode_service.dart';
import 'package:test/test.dart';

void main() {
  group('PixBrCodeService.gerarPayload', () {
    String gen() => PixBrCodeService.gerarPayload(
          chavePix: 'chave@exemplo.com',
          valor: 42.50,
          nomeRecebedor: 'Restaurante Teste',
          cidade: 'Sao Paulo',
          idPedido: 123,
        );

    test('comeca com o payload format indicator e contem a chave PIX', () {
      final p = gen();
      expect(p.startsWith('000201'), isTrue);
      expect(p.contains('BR.GOV.BCB.PIX'), isTrue);
      expect(p.contains('chave@exemplo.com'), isTrue);
    });

    test('termina com CRC de 4 chars hexadecimais maiusculos', () {
      final p = gen();
      final crc = p.substring(p.length - 4);
      expect(RegExp(r'^[0-9A-F]{4}$').hasMatch(crc), isTrue);
      expect(p.contains('6304$crc'), isTrue);
    });

    test('e deterministico para a mesma entrada', () {
      expect(gen(), equals(gen()));
    });

    test('remove acentos do nome do recebedor e da cidade', () {
      final p = PixBrCodeService.gerarPayload(
        chavePix: 'x',
        valor: 1,
        nomeRecebedor: 'Acai Joao',
        cidade: 'Brasilia',
        idPedido: 1,
      );
      final pAcentuado = PixBrCodeService.gerarPayload(
        chavePix: 'x',
        valor: 1,
        nomeRecebedor: 'Açaí João',
        cidade: 'Brasília',
        idPedido: 1,
      );
      // Acentos sao normalizados, entao o payload nao contem caracteres acentuados.
      expect(pAcentuado.contains('ç'), isFalse);
      expect(pAcentuado.contains('í'), isFalse);
      expect(pAcentuado.contains('ã'), isFalse);
      // E o resultado normalizado equivale ao ja sem acento.
      expect(pAcentuado, equals(p));
    });
  });
}
