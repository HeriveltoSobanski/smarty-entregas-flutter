import 'dart:async';
import 'package:flutter/material.dart';

import '../../../data/auth_storage.dart';
import '../../../data/session_store.dart';

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

  Future<void> _tryAutoLogin() async {
    final saved = await AuthStorage.load();
    if (!mounted) return;

    if (saved != null && (saved['token'] as String).isNotEmpty) {
      SessionStore.set(
        idUsuario:   saved['idUsuario'] as int,
        email:       saved['email']    as String,
        nome:        saved['nome']     as String,
        tipoUsuario: saved['tipoUsuario'] as String,
        idEmpresa:   saved['idEmpresa']  as int?,
        token:       saved['token']      as String,
      );

      final tipo = saved['tipoUsuario'] as String;
      if (tipo == 'empresa') {
        Navigator.of(context).pushReplacementNamed('/empresa');
      } else if (tipo == 'motoboy') {
        Navigator.of(context).pushReplacementNamed('/motoboy');
      } else {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
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
