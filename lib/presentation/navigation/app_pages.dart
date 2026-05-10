import 'package:flutter/material.dart';
import 'app_routes.dart';

import '../pages/splash/splash_page.dart';
import '../pages/login/login_page.dart';
import '../pages/pagina_inicial_clientes/pagina_inicial_clientes.dart';
import '../pages/pagina_empresa/pagina_empresa.dart';
import '../pages/pagina_motoboy/pagina_motoboy.dart';
import '../pages/register/register_page.dart';
import '../pages/trabalhe_conosco/trabalhe_conosco_page.dart';
import '../pages/pagina_esqueci_senha/pagina_esqueci_senha.dart';
import '../pages/notificacoes/notificacoes_page.dart';
import '../pages/busca/busca_page.dart';
import '../pages/meus_pedidos/meus_pedidos_page.dart';
import '../pages/perfil/perfil_page.dart';
import '../pages/cliente_enderecos/cliente_enderecos_page.dart';
import '../pages/empresa_motoboys/empresa_motoboys_page.dart';
import '../pages/suporte/suporte_page.dart';

abstract class AppPages {
  static Map<String, WidgetBuilder> get routes => {
    AppRoutes.splash:          (_) => const SplashPage(),
    AppRoutes.login:           (_) => const PaginaLogin(),
    AppRoutes.home:            (_) => const PaginaInicialClientes(),
    AppRoutes.empresa:         (_) => const PaginaEmpresa(),
    AppRoutes.motoboy:         (_) => const PaginaMotoboy(),
    AppRoutes.register:        (_) => const PaginaRegistro(),
    AppRoutes.trabalhe:        (_) => const TrabalheConoscoPage(),
    AppRoutes.esqueciSenha:    (_) => const PaginaEsqueciSenha(),
    AppRoutes.notificacoes:    (_) => const NotificacoesPage(),
    AppRoutes.busca:           (_) => const BuscaPage(),
    AppRoutes.meusPedidos:     (_) => const MeusPedidosPage(),
    AppRoutes.perfil:          (_) => const PerfilPage(),
    AppRoutes.enderecos:       (_) => const ClienteEnderecosPage(),
    AppRoutes.empresaMotoboys: (_) => const EmpresaMotoboyPage(),
    AppRoutes.suporte:         (_) => const SuportePage(),
  };
}
