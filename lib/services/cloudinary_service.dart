import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  static const _cloudName = 'dqju4hjkq';
  static const _uploadPreset = 'smarty-entregas';
  static const _uploadUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  /// Faz upload da imagem e retorna a URL segura.
  /// Lança [CloudinaryException] em caso de falha.
  static Future<String> uploadImage(String filePath) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl))
        ..fields['upload_preset'] = _uploadPreset;

      if (kIsWeb) {
        // Web: fromPath não funciona — lê bytes diretamente via XFile
        final xfile = XFile(filePath);
        final bytes = await xfile.readAsBytes();
        final filename = xfile.name.isNotEmpty ? xfile.name : 'imagem.jpg';
        request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', filePath));
      }

      final streamed = await request.send()
          .timeout(const Duration(seconds: 30));
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        final url = json['secure_url'] as String?;
        if (url != null && url.isNotEmpty) return url;
        throw const CloudinaryException('Resposta inválida do servidor de imagens.');
      }

      String msg = 'Erro ao enviar imagem (${streamed.statusCode}).';
      try {
        final err = jsonDecode(body) as Map<String, dynamic>;
        msg = err['error']?['message']?.toString() ?? msg;
      } catch (_) {}
      throw CloudinaryException(msg);
    } on CloudinaryException {
      rethrow;
    } on SocketException {
      throw const CloudinaryException('Sem conexão. Verifique sua internet.');
    } on HttpException {
      throw const CloudinaryException('Falha na requisição de upload.');
    } catch (e) {
      throw CloudinaryException('Erro inesperado ao enviar imagem: $e');
    }
  }
}

class CloudinaryException implements Exception {
  final String message;
  const CloudinaryException(this.message);
  @override
  String toString() => message;
}
