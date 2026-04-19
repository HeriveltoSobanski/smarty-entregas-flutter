import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';

class FcmService {
  final String _projectId;
  final String _serviceAccountEmail;
  final String _privateKey;

  String? _cachedToken;
  DateTime? _tokenExpiry;

  FcmService({
    required String projectId,
    required String serviceAccountEmail,
    required String privateKey,
  })  : _projectId = projectId,
        _serviceAccountEmail = serviceAccountEmail,
        _privateKey = privateKey;

  bool get isConfigured =>
      _projectId.isNotEmpty &&
      _serviceAccountEmail.isNotEmpty &&
      _privateKey.isNotEmpty;

  // ── OAuth2 service-account token ─────────────────────────────────

  Future<String> _accessToken() async {
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken!;
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final jwt = JWT(
      {
        'iss':   _serviceAccountEmail,
        'sub':   _serviceAccountEmail,
        'aud':   'https://oauth2.googleapis.com/token',
        'iat':   now,
        'exp':   now + 3600,
        'scope': 'https://www.googleapis.com/auth/firebase.messaging',
      },
    );

    final signed = jwt.sign(
      RSAPrivateKey(_privateKey),
      algorithm: JWTAlgorithm.RS256,
    );

    final resp = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer'
            '&assertion=$signed',
    );

    if (resp.statusCode != 200) {
      throw Exception('FCM auth failed (${resp.statusCode}): ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    _cachedToken = data['access_token'] as String;
    _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
    return _cachedToken!;
  }

  // ── Envio individual ─────────────────────────────────────────────

  Future<void> enviar({
    required String fcmToken,
    required String titulo,
    required String corpo,
    Map<String, String>? data,
  }) async {
    if (!isConfigured) return;
    try {
      final accessToken = await _accessToken();
      final resp = await http.post(
        Uri.parse(
          'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send',
        ),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {'title': titulo, 'body': corpo},
            if (data != null) 'data': data,
            'android': {
              'priority': 'high',
              'notification': {'sound': 'default'},
            },
            'apns': {
              'payload': {
                'aps': {'sound': 'default'},
              },
            },
          }
        }),
      );
      if (resp.statusCode != 200) {
        print('[FCM] Falha ao enviar (${resp.statusCode}): ${resp.body}');
      }
    } catch (e) {
      print('[FCM] Erro: $e');
    }
  }

  // ── Envio para todos os dispositivos de um usuário ────────────────

  Future<void> enviarParaUsuario({
    required Connection conn,
    required int idUsuario,
    required String titulo,
    required String corpo,
    Map<String, String>? data,
  }) async {
    if (!isConfigured) return;
    try {
      final rows = await conn.execute(
        Sql.named(
          'SELECT fcm_token FROM dispositivos_fcm WHERE id_usuario = @id',
        ),
        parameters: {'id': idUsuario},
      );
      for (final row in rows) {
        final token = row[0]?.toString();
        if (token != null && token.isNotEmpty) {
          await enviar(
            fcmToken: token,
            titulo: titulo,
            corpo: corpo,
            data: data,
          );
        }
      }
    } catch (e) {
      print('[FCM] enviarParaUsuario erro: $e');
    }
  }
}
