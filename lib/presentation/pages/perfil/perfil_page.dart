import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../data/session_store.dart';
import '../../../data/auth_storage.dart';
import '../../../services/api_service.dart';
import '../cliente_enderecos/cliente_enderecos_page.dart';
import '../suporte/suporte_page.dart';

const Color _laranja = Color(0xFFF5841F);

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  bool _carregando = true;

  String _nome     = '';
  String _email    = '';
  String _telefone = '';

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
  }

  Future<void> _carregarPerfil() async {
    final id = SessionStore.idUsuario;
    if (id == null) { setState(() => _carregando = false); return; }

    final data = await ApiService.getPerfil(id);
    if (!mounted) return;
    setState(() {
      _carregando = false;
      if (data != null) {
        _nome     = data['nome']?.toString()     ?? SessionStore.nome  ?? '';
        _email    = data['email']?.toString()    ?? SessionStore.email ?? '';
        _telefone = data['telefone']?.toString() ?? SessionStore.telefone ?? '';
        // Atualiza sessão com telefone
        SessionStore.telefone = _telefone;
      } else {
        _nome     = SessionStore.nome     ?? '';
        _email    = SessionStore.email    ?? '';
        _telefone = SessionStore.telefone ?? '';
      }
    });
  }

  Future<void> _abrirEdicao() async {
    final resultado = await Navigator.push<_PerfilEditado>(
      context,
      MaterialPageRoute(
        builder: (_) => _EditarPerfilPage(
          nomeAtual:     _nome,
          emailAtual:    _email,
          telefoneAtual: _telefone,
        ),
      ),
    );
    if (resultado == null || !mounted) return;

    setState(() {
      _nome     = resultado.nome;
      _email    = resultado.email;
      _telefone = resultado.telefone;
    });

    // Atualiza sessão em memória e storage
    SessionStore.nome     = resultado.nome;
    SessionStore.email    = resultado.email;
    SessionStore.telefone = resultado.telefone;
    await AuthStorage.save(
      token:       SessionStore.token ?? '',
      idUsuario:   SessionStore.idUsuario!,
      email:       resultado.email,
      nome:        resultado.nome,
      tipoUsuario: SessionStore.tipoUsuario ?? 'cliente',
      idEmpresa:   SessionStore.idEmpresa,
    );
  }

  @override
  Widget build(BuildContext context) {
    final inicial = _nome.isNotEmpty ? _nome[0].toUpperCase() : 'U';
    final tipo    = SessionStore.tipoUsuario ?? 'cliente';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: _laranja,
        elevation: 0,
        title: Text('Meu Perfil',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: _laranja))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Avatar + nome ──────────────────────────────
                Center(
                  child: Column(children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: _laranja,
                          child: Text(
                            inicial,
                            style: GoogleFonts.poppins(
                                fontSize: 38,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(_nome,
                        style: GoogleFonts.poppins(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_email,
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _laranja.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _labelTipo(tipo),
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _laranja,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 28),

                // ── Dados do perfil ────────────────────────────
                _secaoLabel('Dados pessoais'),
                const SizedBox(height: 8),
                _infoCard(Icons.person_outline,  'Nome',     _nome),
                _infoCard(Icons.email_outlined,  'E-mail',   _email),
                _infoCard(Icons.phone_outlined,
                    'Telefone',
                    _telefone.isNotEmpty ? _telefone : '—'),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _abrirEdicao,
                    icon: const Icon(Icons.edit_outlined, color: _laranja, size: 18),
                    label: Text('Editar perfil',
                        style: GoogleFonts.poppins(
                            color: _laranja,
                            fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _laranja),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Ações ──────────────────────────────────────
                _secaoLabel('Conta'),
                const SizedBox(height: 8),
                _acaoCard(
                  icon: Icons.location_on_outlined,
                  cor: _laranja,
                  titulo: 'Meus endereços',
                  subtitulo: 'Gerenciar endereços de entrega',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const ClienteEnderecosPage())),
                ),
                _acaoCard(
                  icon: Icons.support_agent,
                  cor: Colors.blue,
                  titulo: 'Ajuda e Suporte',
                  subtitulo: 'Dúvidas, problemas ou cancelamentos',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SuportePage())),
                ),
                const SizedBox(height: 24),

                // ── Sair ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmarSaida(context),
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: Text('Sair da conta',
                        style: GoogleFonts.poppins(
                            color: Colors.red,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _secaoLabel(String label) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 4),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
                letterSpacing: 0.5)),
      );

  Widget _infoCard(IconData icon, String titulo, String valor) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _laranja.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _laranja, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey.shade500)),
              Text(valor,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
            ]),
          ),
        ]),
      );

  Widget _acaoCard({
    required IconData icon,
    required Color    cor,
    required String   titulo,
    required String   subtitulo,
    required VoidCallback onTap,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: cor, size: 18),
          ),
          title: Text(titulo,
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(subtitulo,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.grey.shade500)),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );

  void _confirmarSaida(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sair da conta',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Tem certeza que deseja sair?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await SessionStore.logout();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (_) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Sair',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _labelTipo(String tipo) {
    switch (tipo) {
      case 'empresa': return 'Restaurante';
      case 'motoboy': return 'Entregador';
      default:        return 'Cliente';
    }
  }
}

// ── Resultado da edição ──────────────────────────────────────────
class _PerfilEditado {
  final String nome;
  final String email;
  final String telefone;
  const _PerfilEditado(
      {required this.nome, required this.email, required this.telefone});
}

// ── Tela de edição ───────────────────────────────────────────────
class _EditarPerfilPage extends StatefulWidget {
  final String nomeAtual;
  final String emailAtual;
  final String telefoneAtual;

  const _EditarPerfilPage({
    required this.nomeAtual,
    required this.emailAtual,
    required this.telefoneAtual,
  });

  @override
  State<_EditarPerfilPage> createState() => _EditarPerfilPageState();
}

class _EditarPerfilPageState extends State<_EditarPerfilPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _telCtrl;
  final _senhaAtualCtrl = TextEditingController();
  final _novaSenhaCtrl  = TextEditingController();
  final _confirmaCtrl   = TextEditingController();

  bool _alterarSenha       = false;
  bool _verSenhaAtual      = false;
  bool _verNovaSenha       = false;
  bool _verConfirma        = false;
  bool _salvando           = false;

  @override
  void initState() {
    super.initState();
    _nomeCtrl  = TextEditingController(text: widget.nomeAtual);
    _emailCtrl = TextEditingController(text: widget.emailAtual);
    _telCtrl   = TextEditingController(text: widget.telefoneAtual);
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _telCtrl.dispose();
    _senhaAtualCtrl.dispose();
    _novaSenhaCtrl.dispose();
    _confirmaCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    final id = SessionStore.idUsuario!;
    final novoNome     = _nomeCtrl.text.trim();
    final novoEmail    = _emailCtrl.text.trim();
    final novoTel      = _telCtrl.text.trim();
    final novaSenha    = _alterarSenha ? _novaSenhaCtrl.text : null;
    final senhaAtual   = _alterarSenha ? _senhaAtualCtrl.text : null;

    final erro = await ApiService.atualizarPerfil(
      idUsuario:  id,
      nome:       novoNome  != widget.nomeAtual     ? novoNome  : null,
      email:      novoEmail != widget.emailAtual    ? novoEmail : null,
      telefone:   novoTel   != widget.telefoneAtual ? novoTel   : null,
      novaSenha:  novaSenha,
      senhaAtual: senhaAtual,
    );

    if (!mounted) return;
    setState(() => _salvando = false);

    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(erro),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Perfil atualizado com sucesso!'),
        backgroundColor: Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.of(context).pop(_PerfilEditado(
      nome:     novoNome,
      email:    novoEmail,
      telefone: novoTel,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: _laranja,
        foregroundColor: Colors.white,
        title: Text('Editar perfil',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(children: [
            // ── Dados pessoais ─────────────────────────────────
            _secao('Dados pessoais'),
            const SizedBox(height: 10),
            _campo(
              controller: _nomeCtrl,
              label: 'Nome completo',
              icon: Icons.person_outline,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 12),
            _campo(
              controller: _emailCtrl,
              label: 'E-mail',
              icon: Icons.email_outlined,
              teclado: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                if (!RegExp(r'.+@.+\..+').hasMatch(v.trim())) {
                  return 'E-mail inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _campo(
              controller: _telCtrl,
              label: 'Telefone (opcional)',
              icon: Icons.phone_outlined,
              teclado: TextInputType.phone,
            ),
            const SizedBox(height: 24),

            // ── Alterar senha ──────────────────────────────────
            _secao('Senha'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() {
                _alterarSenha = !_alterarSenha;
                if (!_alterarSenha) {
                  _senhaAtualCtrl.clear();
                  _novaSenhaCtrl.clear();
                  _confirmaCtrl.clear();
                }
              }),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(children: [
                  Icon(Icons.lock_outline,
                      color: _alterarSenha ? _laranja : Colors.grey.shade500,
                      size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _alterarSenha
                          ? 'Cancelar alteração de senha'
                          : 'Alterar senha',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _alterarSenha
                              ? _laranja
                              : Colors.black87),
                    ),
                  ),
                  Icon(
                    _alterarSenha
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ]),
              ),
            ),
            if (_alterarSenha) ...[
              const SizedBox(height: 12),
              _campoSenha(
                controller: _senhaAtualCtrl,
                label: 'Senha atual',
                visivel: _verSenhaAtual,
                onToggle: () =>
                    setState(() => _verSenhaAtual = !_verSenhaAtual),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Informe a senha atual'
                    : null,
              ),
              const SizedBox(height: 12),
              _campoSenha(
                controller: _novaSenhaCtrl,
                label: 'Nova senha',
                visivel: _verNovaSenha,
                onToggle: () =>
                    setState(() => _verNovaSenha = !_verNovaSenha),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Informe a nova senha';
                  if (v.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _campoSenha(
                controller: _confirmaCtrl,
                label: 'Confirmar nova senha',
                visivel: _verConfirma,
                onToggle: () =>
                    setState(() => _verConfirma = !_verConfirma),
                validator: (v) => v != _novaSenhaCtrl.text
                    ? 'As senhas não coincidem'
                    : null,
              ),
            ],
            const SizedBox(height: 32),

            // ── Botão salvar ───────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _laranja,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                child: _salvando
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white)))
                    : Text('Salvar alterações',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  Widget _secao(String label) => Align(
        alignment: Alignment.centerLeft,
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
                letterSpacing: 0.5)),
      );

  Widget _campo({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType teclado = TextInputType.text,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: teclado,
        validator: validator,
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: _deco(label, icon),
      );

  Widget _campoSenha({
    required TextEditingController controller,
    required String label,
    required bool visivel,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        obscureText: !visivel,
        validator: validator,
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: _deco(label, Icons.lock_outline).copyWith(
          suffixIcon: IconButton(
            icon: Icon(
              visivel
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.grey,
              size: 20,
            ),
            onPressed: onToggle,
          ),
        ),
      );

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _laranja, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );
}
