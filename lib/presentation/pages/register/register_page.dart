import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../../../services/api_service.dart';
import '../../../data/session_store.dart';
import '../../../data/auth_storage.dart';

// ── CPF Validator ─────────────────────────────────────────────────────────────

bool _cpfValido(String cpf) {
  cpf = cpf.replaceAll(RegExp(r'\D'), '');
  if (cpf.length != 11) return false;
  if (RegExp(r'^(\d)\1+$').hasMatch(cpf)) return false;

  int sum = 0;
  for (int i = 0; i < 9; i++) { sum += int.parse(cpf[i]) * (10 - i); }
  int d1 = (sum * 10) % 11;
  if (d1 >= 10) d1 = 0;
  if (d1 != int.parse(cpf[9])) return false;

  sum = 0;
  for (int i = 0; i < 10; i++) { sum += int.parse(cpf[i]) * (11 - i); }
  int d2 = (sum * 10) % 11;
  if (d2 >= 10) d2 = 0;
  return d2 == int.parse(cpf[10]);
}

// ─────────────────────────────────────────────────────────────────────────────

class PaginaRegistro extends StatefulWidget {
  const PaginaRegistro({super.key});

  @override
  State<PaginaRegistro> createState() => _PaginaRegistroState();
}

class _PaginaRegistroState extends State<PaginaRegistro> {
  // ── PageView ──────────────────────────────────────────────────────────────
  final _pageCtrl = PageController();
  int _step = 0;

  final _form0 = GlobalKey<FormState>();
  final _form1 = GlobalKey<FormState>();
  final _form2 = GlobalKey<FormState>();

  // ── Controllers ──────────────────────────────────────────────────────────
  final _nomeCtrl    = TextEditingController();
  final _cpfCtrl     = TextEditingController();
  final _telCtrl     = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _senhaCtrl   = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // ── Focus nodes ──────────────────────────────────────────────────────────
  final _nomeFocus    = FocusNode();
  final _cpfFocus     = FocusNode();
  final _telFocus     = FocusNode();
  final _emailFocus   = FocusNode();
  final _senhaFocus   = FocusNode();
  final _confirmFocus = FocusNode();

  // ── Masks ─────────────────────────────────────────────────────────────────
  final _cpfFmt = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {'#': RegExp(r'[0-9]')},
  );
  final _telFmt = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'[0-9]')},
  );

  bool    _obscureSenha   = true;
  bool    _obscureConfirm = true;
  bool    _aceitouTermos  = false;
  bool    _carregando     = false;

  static const _orange   = Color(0xFFF5841F);
  static const _orangeDk = Color(0xFFE67316);
  static const _iconGrey = Color(0xFF757575);

  @override
  void initState() {
    super.initState();
    for (final f in [
      _nomeFocus, _cpfFocus, _telFocus,
      _emailFocus, _senhaFocus, _confirmFocus,
    ]) {
      f.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in [
      _nomeCtrl, _cpfCtrl, _telCtrl,
      _emailCtrl, _senhaCtrl, _confirmCtrl,
    ]) {
      c.dispose();
    }
    for (final f in [
      _nomeFocus, _cpfFocus, _telFocus,
      _emailFocus, _senhaFocus, _confirmFocus,
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  InputDecoration _deco({
    required String    hint,
    required IconData  icon,
    required FocusNode focus,
    Widget?            suffix,
  }) {
    final active = focus.hasFocus;
    return InputDecoration(
      hintText:  hint,
      hintStyle: GoogleFonts.poppins(color: _iconGrey, fontSize: 14),
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Icon(icon,
            color: active ? _orange : _iconGrey, size: 22),
      ),
      prefixIconConstraints:
          const BoxConstraints(minWidth: 48, minHeight: 48),
      suffixIcon: suffix,
      filled:    true,
      fillColor: Colors.white.withValues(alpha: 0.95),
      isDense:   false,
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
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      errorStyle: GoogleFonts.poppins(
          fontSize: 11, color: const Color(0xFFFFCDD2)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  Widget _shadow({required Widget child}) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );

  Widget _primaryBtn({
    required String        label,
    required VoidCallback? onPressed,
  }) =>
      Container(
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
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _orange,
            disabledBackgroundColor: _orange.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: (_carregando && label == 'Registrar')
              ? const SizedBox(
                  height: 22,
                  width:  22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:  AlwaysStoppedAnimation(Colors.white),
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

  Widget _backLink(VoidCallback onTap) => TextButton(
        onPressed: onTap,
        child: Text(
          'Voltar',
          style: GoogleFonts.poppins(
            fontSize:            14,
            fontWeight:          FontWeight.w600,
            color:               Colors.white,
            decoration:          TextDecoration.underline,
            decorationColor:     Colors.white,
            decorationThickness: 1.5,
          ),
        ),
      );

  void _goTo(int page) {
    setState(() => _step = page);
    _pageCtrl.animateToPage(page,
        duration: const Duration(milliseconds: 300),
        curve:    Curves.easeInOut);
  }

  void _next(GlobalKey<FormState> key) {
    if (key.currentState!.validate()) _goTo(_step + 1);
  }

  // ── Snackbar helpers ──────────────────────────────────────────────────────

  void _snack(String msg, {Color bg = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _registrar() async {
    if (!_form2.currentState!.validate()) return;
    if (!_aceitouTermos) {
      _snack('Aceite os termos para continuar.');
      return;
    }

    setState(() => _carregando = true);

    Map<String, dynamic> resp;
    try {
      resp = await ApiService.registerCliente(
        nome:     _nomeCtrl.text.trim(),
        email:    _emailCtrl.text.trim(),
        senha:    _senhaCtrl.text,
        cpf:      _cpfFmt.getUnmaskedText(),
        telefone: _telFmt.getUnmaskedText(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.toLowerCase().contains('e-mail') || msg.toLowerCase().contains('email')) {
        _snack('Este e-mail já está cadastrado.');
      } else if (msg.toLowerCase().contains('cpf')) {
        _snack('Este CPF já está cadastrado.');
      } else {
        _snack(msg);
      }
      return;
    }

    if (!mounted) return;
    setState(() => _carregando = false);

    // Auto-login após registro — salva token e vai direto para o app
    final user       = resp['user'] as Map<String, dynamic>? ?? {};
    final idUsuario  = user['id_usuario'] is int
        ? user['id_usuario'] as int
        : int.tryParse(user['id_usuario']?.toString() ?? '0') ?? 0;
    final email      = user['email']?.toString() ?? _emailCtrl.text.trim();
    final nome       = user['nome']?.toString()  ?? _nomeCtrl.text.trim();
    final token      = resp['token']?.toString() ?? '';

    SessionStore.set(
      idUsuario:   idUsuario,
      email:       email,
      nome:        nome,
      tipoUsuario: 'cliente',
      token:       token,
    );

    if (token.isNotEmpty) {
      await AuthStorage.save(
        token:       token,
        idUsuario:   idUsuario,
        email:       email,
        nome:        nome,
        tipoUsuario: 'cliente',
      );
    }

    if (!mounted) return;

    // Sucesso — dialog de boas-vindas e navega para o app
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width:  72,
              height: 72,
              decoration: BoxDecoration(
                color:  const Color(0xFF4CAF50).withValues(alpha: 0.12),
                shape:  BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: Color(0xFF4CAF50), size: 44),
            ),
            const SizedBox(height: 16),
            Text(
              'Conta criada com sucesso!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize:   18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bem-vindo ao Smarty Entregas!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/home', (_) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Começar',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color:      Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step indicator ────────────────────────────────────────────────────────

  Widget _stepIndicator() {
    const labels = ['Dados', 'Contato', 'Senha'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        if (i.isOdd) {
          final lineIdx = i ~/ 2;
          final done    = _step > lineIdx;
          return Expanded(
            child: Container(
              height: 2,
              color:  Colors.white.withValues(alpha: done ? 1.0 : 0.3),
            ),
          );
        }
        final dotIdx = i ~/ 2;
        final done   = _step >  dotIdx;
        final active = _step == dotIdx;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width:  32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (done || active)
                    ? _orangeDk
                    : Colors.white.withValues(alpha: 0.3),
                border: Border.all(
                  color: (done || active)
                      ? _orangeDk
                      : Colors.white.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text(
                        '${dotIdx + 1}',
                        style: GoogleFonts.poppins(
                          fontSize:   13,
                          fontWeight: FontWeight.bold,
                          color:      Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              labels[dotIdx],
              style: GoogleFonts.poppins(
                fontSize:   11,
                color:      Colors.white,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }

  // ── Pages ─────────────────────────────────────────────────────────────────

  Widget _page0() => Form(
        key: _form0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _shadow(
              child: TextFormField(
                controller: _nomeCtrl,
                focusNode:  _nomeFocus,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _deco(
                  hint:  'Nome completo',
                  icon:  Icons.person_outlined,
                  focus: _nomeFocus,
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 3) {
                    return 'Nome deve ter pelo menos 3 caracteres';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),

            _shadow(
              child: TextFormField(
                controller:     _cpfCtrl,
                focusNode:      _cpfFocus,
                keyboardType:   TextInputType.number,
                inputFormatters: [_cpfFmt],
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _deco(
                  hint:  'CPF',
                  icon:  Icons.badge_outlined,
                  focus: _cpfFocus,
                ),
                validator: (_) {
                  final raw = _cpfFmt.getUnmaskedText();
                  if (raw.length != 11) {
                    return 'CPF deve ter 11 dígitos';
                  }
                  if (!_cpfValido(raw)) {
                    return 'CPF inválido';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),

            _primaryBtn(
              label:     'Continuar',
              onPressed: () => _next(_form0),
            ),
          ],
        ),
      );

  Widget _page1() => Form(
        key: _form1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _shadow(
              child: TextFormField(
                controller:     _telCtrl,
                focusNode:      _telFocus,
                keyboardType:   TextInputType.phone,
                inputFormatters: [_telFmt],
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _deco(
                  hint:  'Telefone',
                  icon:  Icons.phone_outlined,
                  focus: _telFocus,
                ),
                validator: (_) {
                  final d = _telFmt.getUnmaskedText();
                  if (d.length < 10 || d.length > 11) {
                    return 'Telefone inválido (10 ou 11 dígitos)';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),

            _shadow(
              child: TextFormField(
                controller:   _emailCtrl,
                focusNode:    _emailFocus,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _deco(
                  hint:  'E-mail',
                  icon:  Icons.email_outlined,
                  focus: _emailFocus,
                ),
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
            ),
            const SizedBox(height: 24),

            _primaryBtn(
              label:     'Continuar',
              onPressed: () => _next(_form1),
            ),
            const SizedBox(height: 8),
            _backLink(() => _goTo(0)),
          ],
        ),
      );

  Widget _page2() => Form(
        key: _form2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _shadow(
              child: TextFormField(
                controller:  _senhaCtrl,
                focusNode:   _senhaFocus,
                obscureText: _obscureSenha,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _deco(
                  hint:  'Senha',
                  icon:  Icons.lock_outlined,
                  focus: _senhaFocus,
                  suffix: IconButton(
                    icon: Icon(
                      _obscureSenha
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: _senhaFocus.hasFocus ? _orange : _iconGrey,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureSenha = !_obscureSenha),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Informe a senha';
                  if (v.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),

            _shadow(
              child: TextFormField(
                controller:  _confirmCtrl,
                focusNode:   _confirmFocus,
                obscureText: _obscureConfirm,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _deco(
                  hint:  'Confirmar senha',
                  icon:  Icons.lock_outlined,
                  focus: _confirmFocus,
                  suffix: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color:
                          _confirmFocus.hasFocus ? _orange : _iconGrey,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v != _senhaCtrl.text) {
                    return 'As senhas não coincidem';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Checkbox(
                  value:       _aceitouTermos,
                  onChanged:   (v) =>
                      setState(() => _aceitouTermos = v ?? false),
                  activeColor: _orange,
                  checkColor:  Colors.white,
                  side: const BorderSide(color: Colors.white, width: 1.5),
                ),
                Expanded(
                  child: Text(
                    'Li e aceito os termos de uso e política de privacidade',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _primaryBtn(
              label: 'Registrar',
              onPressed:
                  (_carregando || !_aceitouTermos) ? null : _registrar,
            ),
            const SizedBox(height: 8),
            _backLink(() => _goTo(1)),
          ],
        ),
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) _goTo(_step - 1);
      },
      child: Container(
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
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 24),
              child: Column(
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 110,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(height: 60),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Registre-se',
                    style: GoogleFonts.poppins(
                      fontSize:   28,
                      fontWeight: FontWeight.bold,
                      color:      Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _stepIndicator(),
                  const SizedBox(height: 28),

                  // PageView fixo em altura
                  SizedBox(
                    height: 400,
                    child: PageView(
                      controller: _pageCtrl,
                      physics:    const NeverScrollableScrollPhysics(),
                      children: [_page0(), _page1(), _page2()],
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextButton(
                    onPressed: () {
                      if (_step == 0) {
                        Navigator.pop(context);
                      } else {
                        _goTo(_step - 1);
                      }
                    },
                    child: Text(
                      'Voltar para Login',
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
      ),
    );
  }
}
