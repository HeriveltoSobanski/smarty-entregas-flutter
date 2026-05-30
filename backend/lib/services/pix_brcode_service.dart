/// Gerador de PIX BR Code conforme padrão EMV/BC do Brasil.
/// Não requer nenhuma API externa — gera o payload localmente.
class PixBrCodeService {
  /// Gera o payload PIX pronto para virar QR Code.
  static String gerarPayload({
    required String chavePix,
    required double valor,
    required String nomeRecebedor,
    required String cidade,
    required int idPedido,
  }) {
    final valorStr = valor.toStringAsFixed(2);
    final txId     = 'PED${idPedido.toString().padLeft(11, '0')}';

    final nome = _sanitize(nomeRecebedor, 25);
    final cid  = _sanitize(cidade.isEmpty ? 'Brasil' : cidade, 15);
    final tx   = _sanitize(txId, 25);

    final mai = _field('26', '${_field('00', 'BR.GOV.BCB.PIX')}${_field('01', chavePix)}');
    final adf = _field('62', _field('05', tx));

    final body = '000201'
        '010211'
        '$mai'
        '52040000'
        '5303986'
        '${_field('54', valorStr)}'
        '5802BR'
        '${_field('59', nome)}'
        '${_field('60', cid)}'
        '$adf'
        '6304';

    return '$body${_crc16(body).toUpperCase()}';
  }

  static String _field(String id, String value) =>
      '$id${value.length.toString().padLeft(2, '0')}$value';

  static String _sanitize(String s, int maxLen) {
    var r = s
        .replaceAll(RegExp(r'[àáâãäÀÁÂÃÄ]'), 'a')
        .replaceAll(RegExp(r'[èéêëÈÉÊË]'), 'e')
        .replaceAll(RegExp(r'[ìíîïÌÍÎÏ]'), 'i')
        .replaceAll(RegExp(r'[òóôõöÒÓÔÕÖ]'), 'o')
        .replaceAll(RegExp(r'[ùúûüÙÚÛÜ]'), 'u')
        .replaceAll(RegExp(r'[çÇ]'), 'c')
        .replaceAll(RegExp(r'[ñÑ]'), 'n')
        .replaceAll(RegExp(r'[^A-Za-z0-9 \-.]'), ' ')
        .trim();
    if (r.length > maxLen) r = r.substring(0, maxLen).trim();
    return r.isEmpty ? 'N A' : r;
  }

  /// CRC16-CCITT (polinômio 0x1021, valor inicial 0xFFFF).
  static String _crc16(String payload) {
    const poly = 0x1021;
    int crc = 0xFFFF;
    for (final b in payload.codeUnits) {
      crc ^= (b << 8);
      for (var i = 0; i < 8; i++) {
        crc = (crc & 0x8000) != 0
            ? ((crc << 1) ^ poly) & 0xFFFF
            : (crc << 1) & 0xFFFF;
      }
    }
    return crc.toRadixString(16).padLeft(4, '0');
  }
}
