import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smarty_entregas/services/api_service.dart';

enum _Etapa { email, codigo, novaSenha }

class PaginaEsqueciSenha extends StatefulWidget {
  const PaginaEsqueciSenha({super.key});

  @override
  State<PaginaEsqueciSenha> createState() => _PaginaEsqueciSenhaState();
}

class _PaginaEsqueciSenhaState extends State<PaginaEsqueciSenha> {
  _Etapa _etapa = _Etapa.email;

  final _formKeyEmail  = GlobalKey<FormState>();
  final _formKeyCodigo = GlobalKey<FormState>();
  final _formKeySenha  = GlobalKey<FormState>();

  final _emailCtrl    = TextEditingController();
  final _codigoCtrl   = TextEditingController();
  final _senhaCtrl    = TextEditingController();
  final _confirmaCtrl = TextEditingController();

  bool _loading         = false;
  bool _senhaVisivel    = false;
  bool _confirmaVisivel = false;

  static const _orange   = Color(0xFFF5841F);
  static const _iconGrey = Color(0xFF757575);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codigoCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmaCtrl.dispose();
    super.dispose();
  }

  // ── Etapa 1: enviar código ──────────────────────────────────────
  Future<void> _enviarCodigo() async {
    if (!_formKeyEmail.currentState!.validate()) return;
    setState(() => _loading = true);

    final erro = await ApiService.forgotPassword(
      email: _emailCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (erro != null) {
      _showErro(erro);
      return;
    }

    setState(() => _etapa = _Etapa.codigo);
  }

  // ── Etapa 2: verificar código ───────────────────────────────────
  Future<void> _verificarCodigo() async {
    if (!_formKeyCodigo.currentState!.validate()) return;
    setState(() => _loading = true);

    final erro = await ApiService.verifyCode(
      email:  _emailCtrl.text.trim(),
      codigo: _codigoCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (erro != null) {
      _showErro(erro);
      return;
    }

    setState(() => _etapa = _Etapa.novaSenha);
  }

  // ── Etapa 3: redefinir senha ────────────────────────────────────
  Future<void> _redefinirSenha() async {
    if (!_formKeySenha.currentState!.validate()) return;
    setState(() => _loading = true);

    final erro = await ApiService.resetPassword(
      email:     _emailCtrl.text.trim(),
      codigo:    _codigoCtrl.text.trim(),
      novaSenha: _senhaCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (erro != null) {
      _showErro(erro);
      // Código inválido/expirado → volta para etapa do código
      if (erro.toLowerCase().contains('código') ||
          erro.toLowerCase().contains('expirado')) {
        setState(() => _etapa = _Etapa.codigo);
      }
      return;
    }

    _showSucesso('Senha redefinida com sucesso!');
    Navigator.pop(context);
  }

  // ── Reenviar código ─────────────────────────────────────────────
  Future<void> _reenviarCodigo() async {
    setState(() => _loading = true);
    await ApiService.forgotPassword(email: _emailCtrl.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          'Novo código enviado para ${_emailCtrl.text.trim()}',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.white)),
          ),
        ]),
      ),
    );
  }

  void _showSucesso(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(children: [
          const Icon(Icons.check_circle_outline, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.white)),
          ),
        ]),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Campo genérico ──────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    bool? visivel,
    VoidCallback? onToggleVisivel,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller:      controller,
        obscureText:     obscure && !(visivel ?? false),
        keyboardType:    keyboardType,
        inputFormatters: inputFormatters,
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: GoogleFonts.poppins(color: _iconGrey, fontSize: 14),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(icon, color: _iconGrey, size: 22),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 48, minHeight: 48),
          suffixIcon: onToggleVisivel != null
              ? IconButton(
                  icon: Icon(
                    (visivel ?? false)
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: _iconGrey,
                    size: 22,
                  ),
                  onPressed: onToggleVisivel,
                )
              : null,
          filled:    true,
          fillColor: Colors.white.withValues(alpha: 0.95),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _orange, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          errorStyle: GoogleFonts.poppins(
              fontSize: 11, color: const Color(0xFFFFCDD2)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
        validator: validator,
      ),
    );
  }

  // ── Botão principal ─────────────────────────────────────────────
  Widget _buildBotao(String label, VoidCallback onPressed) {
    return Container(
      width:  double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _orange.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _orange,
          disabledBackgroundColor: _orange.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(
                height: 22,
                width:  22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize:   16,
                  fontWeight: FontWeight.bold,
                  color:      Colors.white,
                ),
              ),
      ),
    );
  }

  // ── Indicador de etapas ─────────────────────────────────────────
  Widget _buildIndicador() {
    final etapas = [_Etapa.email, _Etapa.codigo, _Etapa.novaSenha];
    final atual  = etapas.indexOf(_etapa);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final ativa = i <= atual;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width:  ativa ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: ativa
                ? Colors.white
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }

  // ── Conteúdo de cada etapa ──────────────────────────────────────
  Widget _buildConteudoEtapa() {
    switch (_etapa) {
      // ─── Etapa 1: e-mail ───
      case _Etapa.email:
        return Form(
          key: _formKeyEmail,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Esqueci minha senha',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize:   24,
                  fontWeight: FontWeight.bold,
                  color:      Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Informe seu e-mail cadastrado e\nenviaremos um código de verificação.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 32),
              _buildField(
                controller:   _emailCtrl,
                hint:         'E-mail',
                icon:         Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Informe o e-mail';
                  }
                  if (!RegExp(r'.+@.+\..+').hasMatch(v.trim())) {
                    return 'E-mail inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
              _buildBotao('Enviar código', _enviarCodigo),
            ],
          ),
        );

      // ─── Etapa 2: código ───
      case _Etapa.codigo:
        return Form(
          key: _formKeyCodigo,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Código de verificação',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize:   24,
                  fontWeight: FontWeight.bold,
                  color:      Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  children: [
                    const TextSpan(text: 'Enviamos um código para\n'),
                    TextSpan(
                      text: _emailCtrl.text.trim(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Campo código com estilo OTP
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller:      _codigoCtrl,
                  keyboardType:    TextInputType.number,
                  textAlign:       TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  style: GoogleFonts.poppins(
                    fontSize:      28,
                    fontWeight:    FontWeight.bold,
                    letterSpacing: 12,
                    color:         const Color(0xFF333333),
                  ),
                  decoration: InputDecoration(
                    hintText:  '------',
                    hintStyle: GoogleFonts.poppins(
                      fontSize:      28,
                      letterSpacing: 10,
                      color:         _iconGrey.withValues(alpha: 0.4),
                    ),
                    filled:    true,
                    fillColor: Colors.white.withValues(alpha: 0.95),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: Colors.transparent),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: _orange, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: Colors.redAccent),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: Colors.redAccent, width: 1.5),
                    ),
                    errorStyle: GoogleFonts.poppins(
                        fontSize: 11, color: const Color(0xFFFFCDD2)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length != 6) {
                      return 'Digite o código de 6 dígitos';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 28),
              _buildBotao('Verificar código', _verificarCodigo),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _loading ? null : _reenviarCodigo,
                child: Text(
                  'Não recebi o código — reenviar',
                  style: GoogleFonts.poppins(
                    fontSize:            13,
                    fontWeight:          FontWeight.w500,
                    color:               Colors.white,
                    decoration:          TextDecoration.underline,
                    decorationColor:     Colors.white,
                    decorationThickness: 1.2,
                  ),
                ),
              ),
            ],
          ),
        );

      // ─── Etapa 3: nova senha ───
      case _Etapa.novaSenha:
        return Form(
          key: _formKeySenha,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nova senha',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize:   24,
                  fontWeight: FontWeight.bold,
                  color:      Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Escolha uma nova senha para sua conta.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 32),
              _buildField(
                controller:      _senhaCtrl,
                hint:            'Nova senha',
                icon:            Icons.lock_outline,
                obscure:         true,
                visivel:         _senhaVisivel,
                onToggleVisivel: () =>
                    setState(() => _senhaVisivel = !_senhaVisivel),
                validator: (v) {
                  if (v == null || v.length < 6) {
                    return 'Mínimo 6 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildField(
                controller:      _confirmaCtrl,
                hint:            'Confirmar nova senha',
                icon:            Icons.lock_person_outlined,
                obscure:         true,
                visivel:         _confirmaVisivel,
                onToggleVisivel: () => setState(
                    () => _confirmaVisivel = !_confirmaVisivel),
                validator: (v) {
                  if (v != _senhaCtrl.text) {
                    return 'As senhas não coincidem';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
              _buildBotao('Redefinir senha', _redefinirSenha),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFA726), Color(0xFFFFEB3B)],
          begin:  Alignment.topCenter,
          end:    Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 160,
                  errorBuilder: (_, __, ___) =>
                      const SizedBox(height: 60),
                ),
                const SizedBox(height: 16),

                _buildIndicador(),
                const SizedBox(height: 28),

                // Conteúdo animado entre etapas
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.08, 0),
                        end:   Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_etapa),
                    child: _buildConteudoEtapa(),
                  ),
                ),

                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    if (_etapa == _Etapa.email) {
                      Navigator.pop(context);
                    } else if (_etapa == _Etapa.codigo) {
                      setState(() => _etapa = _Etapa.email);
                    } else {
                      setState(() => _etapa = _Etapa.codigo);
                    }
                  },
                  child: Text(
                    _etapa == _Etapa.email ? 'Voltar ao login' : 'Voltar',
                    style: GoogleFonts.poppins(
                      fontSize:            14,
                      fontWeight:          FontWeight.w600,
                      color:               Colors.white,
                      decoration:          TextDecoration.underline,
                      decorationColor:     Colors.white,
                      decorationThickness: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
