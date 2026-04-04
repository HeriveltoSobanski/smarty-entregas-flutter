/// Sessão em memória do usuário logado.
/// Preenchida após login bem-sucedido e limpa no logout.
class SessionStore {
  static int?    idUsuario;
  static String? email;
  static String? nome;
  static String? tipoUsuario; // 'cliente' | 'empresa' | 'motoboy'
  static int?    idEmpresa;

  static void set({
    required int    idUsuario,
    required String email,
    required String nome,
    required String tipoUsuario,
    int?            idEmpresa,
  }) {
    SessionStore.idUsuario   = idUsuario;
    SessionStore.email       = email;
    SessionStore.nome        = nome;
    SessionStore.tipoUsuario = tipoUsuario;
    SessionStore.idEmpresa   = idEmpresa;
  }

  static void clear() {
    idUsuario   = null;
    email       = null;
    nome        = null;
    tipoUsuario = null;
    idEmpresa   = null;
  }

  static bool get isEmpresa  => tipoUsuario == 'empresa';
  static bool get isCliente  => tipoUsuario == 'cliente';
  static bool get isMotoboy  => tipoUsuario == 'motoboy';
}
