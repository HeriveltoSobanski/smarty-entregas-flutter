import 'dart:convert';
import 'package:backend/services/mercadopago_service.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

void main() {
  const secret = 'segredo-do-webhook-mp-para-teste';
  const requestId = 'req-abc-123';
  const dataId = 'PAY12345';
  const ts = '1700000000';

  // Assinatura v1 esperada, calculada de forma independente a partir do
  // manifesto que o helper deve reconstruir.
  String assinar(String manifesto) => Hmac(sha256, utf8.encode(secret))
      .convert(utf8.encode(manifesto))
      .toString();

  group('MercadoPagoService.validarAssinatura', () {
    test('aceita assinatura valida com id, request-id e ts', () {
      final v1 = assinar('id:${dataId.toLowerCase()};request-id:$requestId;ts:$ts;');
      expect(
        MercadoPagoService.validarAssinatura(
          secret: secret,
          xSignature: 'ts=$ts,v1=$v1',
          xRequestId: requestId,
          dataId: dataId,
        ),
        isTrue,
      );
    });

    test('rejeita quando o v1 nao confere', () {
      expect(
        MercadoPagoService.validarAssinatura(
          secret: secret,
          xSignature: 'ts=$ts,v1=deadbeef',
          xRequestId: requestId,
          dataId: dataId,
        ),
        isFalse,
      );
    });

    test('rejeita quando o secret e diferente', () {
      final v1 = assinar('id:${dataId.toLowerCase()};request-id:$requestId;ts:$ts;');
      expect(
        MercadoPagoService.validarAssinatura(
          secret: 'outro-secret',
          xSignature: 'ts=$ts,v1=$v1',
          xRequestId: requestId,
          dataId: dataId,
        ),
        isFalse,
      );
    });

    test('omite campos ausentes no manifesto (so ts)', () {
      final v1 = assinar('ts:$ts;');
      expect(
        MercadoPagoService.validarAssinatura(
          secret: secret,
          xSignature: 'ts=$ts,v1=$v1',
          xRequestId: null,
          dataId: null,
        ),
        isTrue,
      );
    });

    test('rejeita header ausente, malformado ou sem ts/v1', () {
      expect(
        MercadoPagoService.validarAssinatura(
          secret: secret, xSignature: null, xRequestId: requestId, dataId: dataId),
        isFalse,
      );
      expect(
        MercadoPagoService.validarAssinatura(
          secret: secret, xSignature: 'lixo', xRequestId: requestId, dataId: dataId),
        isFalse,
      );
      expect(
        MercadoPagoService.validarAssinatura(
          secret: secret, xSignature: 'ts=$ts', xRequestId: requestId, dataId: dataId),
        isFalse,
      );
    });

    test('rejeita quando o secret esta vazio', () {
      final v1 = assinar('ts:$ts;');
      expect(
        MercadoPagoService.validarAssinatura(
          secret: '', xSignature: 'ts=$ts,v1=$v1', xRequestId: null, dataId: null),
        isFalse,
      );
    });
  });
}
