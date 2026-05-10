import 'dart:io';
import '../core/utils/app_logger.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../data/session_store.dart';
import 'api_service.dart';

/// Invocado pelo sistema quando o app está em background/terminated.
/// Deve ser top-level (não pode ser método de classe).
@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'smarty_pedidos',
    'Pedidos',
    description: 'Atualizações de status de pedido',
    importance: Importance.max,
    playSound: true,
  );

  static Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_bgHandler);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onTap,
    );

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Mensagem em foreground → exibe notificação local
    FirebaseMessaging.onMessage.listen(_onForeground);

    // Toque na notificação quando app estava em background
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedFromBackground);

    // Registra token inicial e escuta renovações
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _registrar(token);
    FirebaseMessaging.instance.onTokenRefresh.listen(_registrar);
  }

  /// Chama após login/auto-login para garantir o registro do token.
  static Future<void> registrarAposLogin() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _registrar(token);
  }

  /// Verifica se o app foi aberto por toque em notificação (estado terminated).
  static Future<void> checarMensagemInicial() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) _navegarParaPedido(message.data);
  }

  // ── handlers privados ──────────────────────────────────────────

  static void _onForeground(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;

    _localNotifications.show(
      message.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['id_pedido'],
    );
  }

  static void _onTap(NotificationResponse response) {
    _navegarParaPedido({'id_pedido': response.payload ?? ''});
  }

  static void _onOpenedFromBackground(RemoteMessage message) {
    _navegarParaPedido(message.data);
  }

  static void _navegarParaPedido(Map<String, dynamic> data) {
    // Navega para home; a badge de notificação leva ao detalhe do pedido
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (_) => false);
  }

  static Future<void> _registrar(String token) async {
    if (!SessionStore.isLoggedIn) return;
    try {
      await ApiService.registrarFcmToken(
        token: token,
        plataforma: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (e, st) { AppLogger.e('PushNotification', e, st); }
  }
}
