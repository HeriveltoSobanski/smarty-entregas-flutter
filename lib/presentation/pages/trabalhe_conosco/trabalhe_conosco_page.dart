import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../../../services/api_service.dart';

// ── CPF validator ─────────────────────────────────────────────────────────────

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

class TrabalheConoscoPage extends StatefulWidget {
  const TrabalheConoscoPage({super.key});

  @override
  State<TrabalheConoscoPage> createState() => _TrabalheConoscoPageState();
}

class _TrabalheConoscoPageState extends State<TrabalheConoscoPage> {
  // ── tab ──────────────────────────────────────────────────────────────────
  String _tipo = 'Empresa';

  // ── step por tab ─────────────────────────────────────────────────────────
  int _stepEmpresa  = 0;
  int _stepMotoboy  = 0;
  int get _step => _tipo == 'Empresa' ? _stepEmpresa : _stepMotoboy;

  final _pageCtrlEmpresa = PageController();
  final _pageCtrlMotoboy = PageController();
  PageController get _pageCtrl =>
      _tipo == 'Empresa' ? _pageCtrlEmpresa : _pageCtrlMotoboy;

  // ── form keys ─────────────────────────────────────────────────────────────
  final _eForm0 = GlobalKey<FormState>();
  final _eForm1 = GlobalKey<FormState>();
  final _mForm0 = GlobalKey<FormState>();
  final _mForm1 = GlobalKey<FormState>();

  // ── controllers ──────────────────────────────────────────────────────────
  // Empresa
  final _eNomeCtrl     = TextEditingController();
  final _eCnpjCtrl     = TextEditingController();
  final _eTelCtrl      = TextEditingController();
  final _eEmailCtrl    = TextEditingController();
  final _eSenhaCtrl    = TextEditingController();
  final _eConfirmCtrl  = TextEditingController();

  // Motoboy
  final _mNomeCtrl    = TextEditingController();
  final _mCpfCtrl     = TextEditingController();
  final _mCnhCtrl     = TextEditingController();
  final _mTelCtrl     = TextEditingController();
  final _mEmailCtrl   = TextEditingController();
  final _mSenhaCtrl   = TextEditingController();

  // ── focus nodes ───────────────────────────────────────────────────────────
  final _eNomeFocus    = FocusNode();
  final _eCnpjFocus    = FocusNode();
  final _eTelFocus     = FocusNode();
  final _eEmailFocus   = FocusNode();
  final _eSenhaFocus   = FocusNode();
  final _eConfirmFocus = FocusNode();

  final _mNomeFocus  = FocusNode();
  final _mCpfFocus   = FocusNode();
  final _mCnhFocus   = FocusNode();
  final _mTelFocus   = FocusNode();
  final _mEmailFocus = FocusNode();
  final _mSenhaFocus = FocusNode();

  // ── masks ─────────────────────────────────────────────────────────────────
  final _cnpjFmt = MaskTextInputFormatter(
    mask: '##.###.###/####-##',
    filter: {'#': RegExp(r'[0-9]')},
  );
  final _cpfFmt = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {'#': RegExp(r'[0-9]')},
  );
  final _eTelFmt = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'[0-9]')},
  );
  final _mTelFmt = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'[0-9]')},
  );

  bool _eObscureSenha   = true;
  bool _eObscureConfirm = true;
  bool _mObscureSenha   = true;
  bool _carregando      = false;

  static const _orange   = Color(0xFFF5841F);
  static const _orangeDk = Color(0xFFE67316);
  static const _iconGrey = Color(0xFF757575);

  @override
  void initState() {
    super.initState();
    for (final f in [
      _eNomeFocus, _eCnpjFocus, _eTelFocus,
      _eEmailFocus, _eSenhaFocus, _eConfirmFocus,
      _mNomeFocus, _mCpfFocus, _mCnhFocus,
      _mTelFocus, _mEmailFocus, _mSenhaFocus,
    ]) {
      f.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _pageCtrlEmpresa.dispose();
    _pageCtrlMotoboy.dispose();
    for (final c in [
      _eNomeCtrl, _eCnpjCtrl, _eTelCtrl,
      _eEmailCtrl, _eSenhaCtrl, _eConfirmCtrl,
      _mNomeCtrl, _mCpfCtrl, _mCnhCtrl,
      _mTelCtrl, _mEmailCtrl, _mSenhaCtrl,
    ]) {
      c.dispose();
    }
    for (final f in [
      _eNomeFocus, _eCnpjFocus, _eTelFocus,
      _eEmailFocus, _eSenhaFocus, _eConfirmFocus,
      _mNomeFocus, _mCpfFocus, _mCnhFocus,
      _mTelFocus, _mEmailFocus, _mSenhaFocus,
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  // ── helpers ───────────────────────────────────────────────────────────────

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
          child: (_carregando && label == 'Cadastrar')
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
    if (_tipo == 'Empresa') {
      setState(() => _stepEmpresa = page);
    } else {
      setState(() => _stepMotoboy = page);
    }
    _pageCtrl.animateToPage(page,
        duration: const Duration(milliseconds: 300),
        curve:    Curves.easeInOut);
  }

  void _next(GlobalKey<FormState> key) {
    if (key.currentState!.validate()) _goTo(_step + 1);
  }

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

  Future<void> _showSuccess(String msg) async {
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
              msg,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Agora faça login para continuar.',
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
                  Navigator.of(context).popUntil(
                      (route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Ir para Login',
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

  void _handleApiError(String? erro) {
    if (erro == null) return;
    if (erro.contains('indisponível') || erro.contains('servidor')) {
      _snack('Sem conexão com o servidor. Verifique se o backend está rodando.');
    } else if (erro.toLowerCase().contains('e-mail') ||
        erro.toLowerCase().contains('email')) {
      _snack('Este e-mail já está cadastrado.');
    } else if (erro.toLowerCase().contains('cnpj')) {
      _snack('Este CNPJ já está cadastrado.');
    } else if (erro.toLowerCase().contains('cpf')) {
      _snack('Este CPF já está cadastrado.');
    } else {
      _snack('Erro ao criar conta. Tente novamente.');
    }
  }

  Future<void> _cadastrarEmpresa() async {
    if (!_eForm1.currentState!.validate()) return;
    setState(() => _carregando = true);

    final erro = await ApiService.registerEmpresa(
      nome:     _eNomeCtrl.text.trim(),
      email:    _eEmailCtrl.text.trim(),
      senha:    _eSenhaCtrl.text,
      cnpj:     _cnpjFmt.getUnmaskedText(),
      telefone: _eTelFmt.getUnmaskedText(),
    );

    if (!mounted) return;
    setState(() => _carregando = false);

    if (erro == null) {
      await _showSuccess('Empresa cadastrada com sucesso!');
    } else {
      _handleApiError(erro);
    }
  }

  Future<void> _cadastrarMotoboy() async {
    if (!_mForm1.currentState!.validate()) return;
    setState(() => _carregando = true);

    final erro = await ApiService.registerMotoboy(
      nome:     _mNomeCtrl.text.trim(),
      email:    _mEmailCtrl.text.trim(),
      senha:    _mSenhaCtrl.text,
      cpf:      _cpfFmt.getUnmaskedText(),
      telefone: _mTelFmt.getUnmaskedText(),
    );

    if (!mounted) return;
    setState(() => _carregando = false);

    if (erro == null) {
      await _showSuccess('Cadastro realizado com sucesso!');
    } else {
      _handleApiError(erro);
    }
  }

  // ── step indicator (2 steps) ──────────────────────────────────────────────

  Widget _stepIndicator2(List<String> labels) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        if (i == 1) {
          final done = _step > 0;
          return Expanded(
            child: Container(
              height: 2,
              color:  Colors.white.withValues(alpha: done ? 1.0 : 0.3),
            ),
          );
        }
        final dotIdx = i == 0 ? 0 : 1;
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
                    ? const Icon(Icons.check,
                        size: 16, color: Colors.white)
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
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }

  // ── Empresa forms ─────────────────────────────────────────────────────────

  Widget _empresaPage0() => Form(
        key: _eForm0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _shadow(
              child: TextFormField(
                controller: _eNomeCtrl,
                focusNode:  _eNomeFocus,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _deco(
                  hint:  'Nome fantasia',
                  icon:  Icons.store_outlined,
                  focus: _eNomeFocus,
                ),
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'Mínimo 3 caracteres'
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            _shadow(
              child: TextFormField(
                controller:     _eCnpjCtrl,
                focusNode:      _eCnpjFocus,
                keyboardType:   TextInputType.number,
                inputFormatters: [_cnpjFmt],
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _deco(
                  hint:  'CNPJ',
                  icon:  Icons.business_outlined,
                  focus: _eCnpjFocus,
                ),
                validator: (_) {
                  final d = _cnpjFmt.getUnmaskedText();
                  return d.length != 14 ? 'CNPJ deve ter 14 dígitos' : null;
                },
              ),
            ),
            const SizedBox(height: 16),

            _shadow(
              child: TextFormField(
                controller:     _eTelCtrl,
                focusNode:      _eTelFocus,
                keyboardType:   TextInputType.phone,
                inputFormatters: [_eTelFmt],
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _deco(
                  hint:  'Telefone',
                  icon:  Icons.phone_outlined,
                  focus: _eTelFocus,
                ),
                validator: (_) {
                  final d = _eTelFmt.getUnmaskedText();
                  return (d.length < 10 || d.length > 11)
                      ? 'Telefone inválido (10 ou 11 dígitos)'
                      : null;
                },
              ),
            ),
            const SizedBox(height: 24),

            _primaryBtn(
              label:     'Continuar',
              onPressed: () => _next(_eForm0),
            ),
          ],
        ),
      );

  Widget _empresaPage1() => Form(
        key: _eForm1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _shadow(
              child: TextFormField(
                controller:   _eEmailCtrl,
                focusNode:    _eEmailFocus,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _deco(
                  hint:  'E-mail',
                  icon:  Icons.email_outlined,
                  focus: _eEmailFocus,
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
            const SizedBox(height: 16),

            _shadow(
              child: TextFormField(
                controller:  _eSenhaCtrl,
                focusNode:   _eSenhaFocus,
                obscureText: _eObscureSenha,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _deco(
                  hint:  'Senha',
                  icon:  Icons.lock_outlined,
                  focus: _eSenhaFocus,
                  suffix: IconButton(
                    icon: Icon(
                      _eObscureSenha
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: _eSenhaFocus.hasFocus ? _orange : _iconGrey,
                      size: 20,
                    ),
                    onPressed: () => setState(
                        () => _eObscureSenha = !_eObscureSenha),
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
                controller:  _eConfirmCtrl,
                focusNode:   _eConfirmFocus,
                obscureText: _eObscureConfirm,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _deco(
                  hint:  'Confirmar senha',
                  icon:  Icons.lock_outlined,
                  focus: _eConfirmFocus,
                  suffix: IconButton(
                    icon: Icon(
                      _eObscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color:
                          _eConfirmFocus.hasFocus ? _orange : _iconGrey,
                      size: 20,
                    ),
                    onPressed: () => setState(
                        () => _eObscureConfirm = !_eObscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v != _eSenhaCtrl.text) {
                    return 'As senhas não coincidem';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),

            _primaryBtn(
              label:     'Cadastrar',
              onPressed: _carregando ? null : _cadastrarEmpresa,
            ),
            const SizedBox(height: 8),
            _backLink(() => _goTo(0)),
          ],
        ),
      );

  // ── Motoboy forms ─────────────────────────────────────────────────────────

  Widget _motoboyPage0() => Form(
        key: _mForm0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _shadow(
              child: TextFormField(
                controller: _mNomeCtrl,
                focusNode:  _mNomeFocus,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _deco(
                  hint:  'Nome completo',
                  icon:  Icons.person_outlined,
                  focus: _mNomeFocus,
                ),
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'Mínimo 3 caracteres'
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            _shadow(
              child: TextFormField(
                controller:     _mCpfCtrl,
                focusNode:      _mCpfFocus,
                keyboardType:   TextInputType.number,
                inputFormatters: [_cpfFmt],
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _deco(
                  hint:  'CPF',
                  icon:  Icons.badge_outlined,
                  focus: _mCpfFocus,
                ),
                validator: (_) {
                  final raw = _cpfFmt.getUnmaskedText();
                  if (raw.length != 11) return 'CPF deve ter 11 dígitos';
                  if (!_cpfValido(raw)) return 'CPF inválido';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),

            _shadow(
              child: TextFormField(
                controller: _mCnhCtrl,
                focusNode:  _mCnhFocus,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _deco(
                  hint:  'Número da CNH',
                  icon:  Icons.two_wheeler,
                  focus: _mCnhFocus,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe a CNH' : null,
              ),
            ),
            const SizedBox(height: 24),

            _primaryBtn(
              label:     'Continuar',
              onPressed: () => _next(_mForm0),
            ),
          ],
        ),
      );

  Widget _motoboyPage1() => Form(
        key: _mForm1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _shadow(
              child: TextFormField(
                controller:     _mTelCtrl,
                focusNode:      _mTelFocus,
                keyboardType:   TextInputType.phone,
                inputFormatters: [_mTelFmt],
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _deco(
                  hint:  'Telefone',
                  icon:  Icons.phone_outlined,
                  focus: _mTelFocus,
                ),
                validator: (_) {
                  final d = _mTelFmt.getUnmaskedText();
                  return (d.length < 10 || d.length > 11)
                      ? 'Telefone inválido (10 ou 11 dígitos)'
                      : null;
                },
              ),
            ),
            const SizedBox(height: 16),

            _shadow(
              child: TextFormField(
                controller:   _mEmailCtrl,
                focusNode:    _mEmailFocus,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _deco(
                  hint:  'E-mail',
                  icon:  Icons.email_outlined,
                  focus: _mEmailFocus,
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
            const SizedBox(height: 16),

            _shadow(
              child: TextFormField(
                controller:  _mSenhaCtrl,
                focusNode:   _mSenhaFocus,
                obscureText: _mObscureSenha,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _deco(
                  hint:  'Senha',
                  icon:  Icons.lock_outlined,
                  focus: _mSenhaFocus,
                  suffix: IconButton(
                    icon: Icon(
                      _mObscureSenha
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: _mSenhaFocus.hasFocus ? _orange : _iconGrey,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _mObscureSenha = !_mObscureSenha),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Informe a senha';
                  if (v.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),

            _primaryBtn(
              label:     'Cadastrar',
              onPressed: _carregando ? null : _cadastrarMotoboy,
            ),
            const SizedBox(height: 8),
            _backLink(() => _goTo(0)),
          ],
        ),
      );

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEmpresa = _tipo == 'Empresa';
    final labels    = isEmpresa
        ? ['Dados', 'Acesso']
        : ['Dados', 'Acesso'];

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
                    height: 100,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(height: 60),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Trabalhe Conosco',
                    style: GoogleFonts.poppins(
                      fontSize:   22,
                      fontWeight: FontWeight.bold,
                      color:      Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tab toggle
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: ['Empresa', 'Motoboy'].map((t) {
                        final sel = _tipo == t;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (_tipo == t) return;
                              setState(() { _tipo = t; });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: sel
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: sel
                                    ? [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  t,
                                  style: GoogleFonts.poppins(
                                    color: sel ? _orange : Colors.white,
                                    fontWeight: sel
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Step indicator
                  _stepIndicator2(labels),
                  const SizedBox(height: 24),

                  // PageView
                  SizedBox(
                    height: isEmpresa ? 440 : 460,
                    child: isEmpresa
                        ? PageView(
                            controller: _pageCtrlEmpresa,
                            physics:
                                const NeverScrollableScrollPhysics(),
                            children: [
                              _empresaPage0(),
                              _empresaPage1(),
                            ],
                          )
                        : PageView(
                            controller: _pageCtrlMotoboy,
                            physics:
                                const NeverScrollableScrollPhysics(),
                            children: [
                              _motoboyPage0(),
                              _motoboyPage1(),
                            ],
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
                      'Voltar ao login',
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
