abstract class AppRoutes {
  static const splash          = '/splash';
  static const login           = '/login';
  static const home            = '/home';
  static const empresa         = '/empresa';
  static const motoboy         = '/motoboy';
  static const register        = '/register';
  static const trabalhe        = '/trabalhe';
  static const esqueciSenha    = '/esqueci-senha';
  static const notificacoes    = '/notificacoes';
  static const busca           = '/busca';
  static const meusPedidos     = '/meus-pedidos';
  static const perfil          = '/perfil';
  static const enderecos       = '/enderecos';
  static const empresaMotoboys = '/empresa-motoboys';
  static const suporte         = '/suporte';

  // Páginas com argumentos obrigatórios tipados — use Navigator.push(MaterialPageRoute(...))
  // cardapioEmpresa  → CardapioEmpresaPage(empresa: Empresa)
  // checkout         → CheckoutPage(...)
  // acompanhamento   → AcompanhamentoPedidoPage(idPedido: int, ...)
  // avaliacao        → AvaliacaoPage(...)
  // cancelarPedido   → CancelarPedidoPage(...)
  // mapaEntrega      → MapaEntregaPage(...)
  // selecionarEnder. → SelecionarEnderecoPage(onEnderecoSelecionado: callback)
}
