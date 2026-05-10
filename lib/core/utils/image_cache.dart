import 'dart:convert';
import 'dart:typed_data';

/// Cache de decodificação base64 — evita decodificar a mesma imagem
/// em cada rebuild. Mesma string → mesmo Uint8List retornado do cache.
class Base64Cache {
  Base64Cache._();

  static final _cache = <String, Uint8List>{};

  static Uint8List decode(String base64) {
    return _cache.putIfAbsent(
      base64,
      () => base64Decode(base64.split(',').last),
    );
  }

  static void clear() => _cache.clear();
}
