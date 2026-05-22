import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:postgres/postgres.dart';

/// Salva imagens base64 em disco e retorna URL relativa.
/// Registros já em URL passam sem alteração (backward compat).
class ImageService {
  final String publicDir; // caminho absoluto para a pasta public/

  ImageService(this.publicDir);

  static const _maxBytes    = 5 * 1024 * 1024; // 5 MB
  static const _allowedMime = {
    'data:image/jpeg',
    'data:image/jpg',
    'data:image/png',
    'data:image/webp',
  };

  /// Retorna mensagem de erro se o valor for um data URI inválido, null se ok.
  String? validar(String? valor) {
    if (valor == null || valor.isEmpty) return null;
    if (valor.startsWith('http://') ||
        valor.startsWith('https://') ||
        valor.startsWith('/uploads/')) {
      return null;
    }
    if (!valor.contains(',')) return 'Formato de imagem inválido';
    final mime = valor.split(',').first.split(';').first;
    if (!_allowedMime.contains(mime)) {
      return 'Tipo de imagem não permitido. Use JPEG, PNG ou WebP.';
    }
    try {
      final bytes = base64Decode(valor.split(',').last);
      if (bytes.length > _maxBytes) return 'Imagem muito grande. Máximo 5 MB.';
    } catch (_) {
      return 'Imagem corrompida ou inválida';
    }
    return null;
  }

  /// Processa um valor de imagem:
  /// - null / vazio       → null
  /// - URL já existente   → retorna sem alterar
  /// - base64 data URI    → valida → salva arquivo → retorna /uploads/imagens/xxx.ext
  Future<String?> processar(String? valor) async {
    if (valor == null || valor.isEmpty) return null;
    if (valor.startsWith('http://') ||
        valor.startsWith('https://') ||
        valor.startsWith('/uploads/')) {
      return valor;
    }
    if (!valor.contains(',')) return null;
    final erro = validar(valor);
    if (erro != null) return null;
    try {
      final bytes = base64Decode(valor.split(',').last);
      final ext = _ext(valor);
      final nome = '${_rand()}.$ext';
      final dir = Directory(p.join(publicDir, 'uploads', 'imagens'));
      await dir.create(recursive: true);
      await File(p.join(dir.path, nome)).writeAsBytes(bytes);
      return '/uploads/imagens/$nome';
    } catch (e) {
      print('ImageService.processar erro: $e');
      return null;
    }
  }

  /// Converte todos os campos base64 do banco para arquivos em disco.
  /// Executado uma vez na startup — seguro para re-executar.
  Future<void> migrarBanco(Pool conn) async {
    await _migrarColuna(conn, 'produtos',            'imagem',      'id_produto');
    await _migrarColuna(conn, 'empresas',            'foto_perfil', 'id_empresa');
    await _migrarColuna(conn, 'empresas',            'foto_capa',   'id_empresa');
    await _migrarColunaOpcional(conn, 'produto_adicionais', 'imagem', 'id_adicional');
    print('Migração de imagens concluída');
  }

  Future<void> _migrarColuna(
      Pool conn, String tabela, String coluna, String pk) async {
    try {
      final rows = await conn.execute(
        Sql.named(
            "SELECT $pk, $coluna FROM $tabela WHERE $coluna IS NOT NULL AND $coluna LIKE 'data:%'"),
        parameters: {},
      );
      var count = 0;
      for (final r in rows) {
        final id  = r[0];
        final b64 = r[1]?.toString();
        if (b64 == null) continue;
        final url = await processar(b64);
        if (url == null) continue;
        await conn.execute(
          Sql.named('UPDATE $tabela SET $coluna = @url WHERE $pk = @id'),
          parameters: {'url': url, 'id': id},
        );
        count++;
      }
      if (count > 0) print('Imagens migradas: $tabela.$coluna ($count registros)');
    } catch (e) {
      print('Aviso migração $tabela.$coluna: $e');
    }
  }

  // Versão que não falha se a coluna não existir
  Future<void> _migrarColunaOpcional(
      Pool conn, String tabela, String coluna, String pk) async {
    try {
      await _migrarColuna(conn, tabela, coluna, pk);
    } catch (_) {}
  }

  String _ext(String dataUri) {
    if (dataUri.startsWith('data:image/png'))  return 'png';
    if (dataUri.startsWith('data:image/webp')) return 'webp';
    if (dataUri.startsWith('data:image/gif'))  return 'gif';
    return 'jpg';
  }

  String _rand() {
    final r = Random.secure();
    return List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
  }
}
