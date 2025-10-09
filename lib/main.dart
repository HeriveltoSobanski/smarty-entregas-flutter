import 'package:flutter/material.dart';
import 'presentation/pages/splash/splash_page.dart';
import 'presentation/pages/login/login_page.dart';
import 'presentation/pages/pagina_inicial_clientes/pagina_inicial_clientes.dart';
import 'presentation/pages/register/register_page.dart';
import 'presentation/pages/trabalhe_conosco/trabalhe_conosco_page.dart';
import 'presentation/pages/pagina_esqueci_senha/pagina_esqueci_senha.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smarty Entregas',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        fontFamily: 'Roboto',
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashPage(),
        '/login': (_) => const PaginaLogin(),
        '/home': (_) => const PaginaInicialClientes(),
        '/register': (_) => const PaginaRegistro(),
        '/trabalhe': (_) => const TrabalheConoscoPage(),
        '/esqueci-senha': (_) =>
            const PaginaEsqueciSenha(), // <-- agora está no lugar certo
      },
    );
  }
}
