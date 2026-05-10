import 'dart:async';
import '../../../presentation/navigation/app_routes.dart';
import '../../../core/utils/app_logger.dart';
import 'dart:convert';
import 'package:flutter/material.dart';

import '../../../data/auth_storage.dart';
import '../../../data/session_store.dart';
import '../../../services/push_notification_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    _checkSession();
  }

  Future<void> _checkSession() async {
    // Aguarda o mínimo de 2s para exibir o splash
    await Future.wait([
      Future.delayed(const Duration(seconds: 2)),
      _tryAutoLogin(),
    ]);
  }

  static bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }
      final map = jsonDecode(utf8.decode(base64.decode(payload))) as Map<String, dynamic>;
      final exp = map['exp'] as int?;
      if (exp == null) return false;
      return DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(exp * 1000));
    } catch (e, st) {
      AppLogger.e('SplashPage', e, st);
      return true;
    }
  }

  Future<void> _tryAutoLogin() async {
    final saved = await AuthStorage.load();
    if (!mounted) return;

    final token = saved != null ? (saved['token'] as String?) ?? '' : '';
    if (saved != null && token.isNotEmpty && !_isTokenExpired(token)) {
      SessionStore.set(
        idUsuario:   saved['idUsuario'] as int,
        email:       saved['email']    as String,
        nome:        saved['nome']     as String,
        tipoUsuario: saved['tipoUsuario'] as String,
        idEmpresa:   saved['idEmpresa']  as int?,
        token:       token,
      );

      PushNotificationService.registrarAposLogin();
      final tipo = saved['tipoUsuario'] as String;
      if (tipo == 'empresa') {
        Navigator.of(context).pushReplacementNamed(AppRoutes.empresa);
      } else if (tipo == 'motoboy') {
        Navigator.of(context).pushReplacementNamed(AppRoutes.motoboy);
      } else {
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      }
    } else {
      if (saved != null) await AuthStorage.clear();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFA726), Color(0xFFFFEB3B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _animation,
            child: Image.asset(
              'assets/logo.png',
              height: 250,
              errorBuilder: (context, error, stackTrace) {
                return const Text(
                  'Smarty Entregas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
