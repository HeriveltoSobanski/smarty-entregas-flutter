import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../register/register_page.dart';
import '../trabalhe_conosco/trabalhe_conosco_page.dart';
import '../pagina_esqueci_senha/pagina_esqueci_senha.dart';
import '../../../services/api_service.dart';
import '../../../services/social_auth_service.dart';
import '../../../services/push_notification_service.dart';
import '../../../data/session_store.dart';
import '../../../data/auth_storage.dart';

class PaginaLogin extends StatefulWidget {
  const PaginaLogin({super.key});

  @override
  State<PaginaLogin> createState() => _PaginaLoginState();
}

class _PaginaLoginState extends State<PaginaLogin> {
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _senhaCtrl  = TextEditingController();
  final _emailFocus = FocusNode();
  final _senhaFocus = FocusNode();

  bool    _loading      = false;
  bool    _obscureSenha = true;
  String? _erro;

  static const _orange = Color(0xFFF5841F);
  static const _grey   = Color(0xFF757575);
  static const _fieldBg = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() => setState(() {}));
    _senhaFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    _emailFocus.dispose();
    _senhaFocus.dispose();
    super.dispose();
  }

  Future<void> _fazerLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _erro = null; });

    Map<String, dynamic> resp;
    try {
      resp = await ApiService.login(
        email: _emailCtrl.text.trim(),
        senha: _senhaCtrl.text,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _erro    = e.toString().replaceFirst('Exception: ', '');
      });
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);

    final user        = resp['user'] as Map<String, dynamic>? ?? {};
    final tipoUsuario = user['tipo_usuario']?.toString() ?? 'cliente';
    final idEmpresa   = user['id_empresa'] is int
        ? user['id_empresa'] as int
        : int.tryParse(user['id_empresa']?.toString() ?? '0') ?? 0;

    final idUsuario = user['id_usuario'] is int
        ? user['id_usuario'] as int
        : int.tryParse(user['id_usuario']?.toString() ?? '0') ?? 0;
    final token = resp['token']?.toString() ?? '';

    SessionStore.set(
      idUsuario:   idUsuario,
      email:       user['email']?.toString() ?? '',
      nome:        user['nome']?.toString()  ?? '',
      tipoUsuario: tipoUsuario,
      idEmpresa:   idEmpresa > 0 ? idEmpresa : null,
      token:       token,
    );

    if (token.isNotEmpty) {
      await AuthStorage.save(
        token:       token,
        idUsuario:   idUsuario,
        email:       user['email']?.toString() ?? '',
        nome:        user['nome']?.toString()  ?? '',
        tipoUsuario: tipoUsuario,
        idEmpresa:   idEmpresa > 0 ? idEmpresa : null,
      );
    }

    PushNotificationService.registrarAposLogin();
    if (!mounted) return;
    if (tipoUsuario == 'empresa') {
      Navigator.pushReplacementNamed(context, '/empresa');
    } else if (tipoUsuario == 'motoboy') {
      Navigator.pushReplacementNamed(context, '/motoboy');
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _loginComSocial(Map<String, dynamic> resp) async {
    final user        = resp['user'] as Map<String, dynamic>? ?? {};
    final tipoUsuario = user['tipo_usuario']?.toString() ?? 'cliente';
    final idEmpresa   = user['id_empresa'] is int
        ? user['id_empresa'] as int
        : int.tryParse(user['id_empresa']?.toString() ?? '0') ?? 0;
    final idUsuario   = user['id_usuario'] is int
        ? user['id_usuario'] as int
        : int.tryParse(user['id_usuario']?.toString() ?? '0') ?? 0;
    final token = resp['token']?.toString() ?? '';

    SessionStore.set(
      idUsuario:   idUsuario,
      email:       user['email']?.toString() ?? '',
      nome:        user['nome']?.toString()  ?? '',
      tipoUsuario: tipoUsuario,
      idEmpresa:   idEmpresa > 0 ? idEmpresa : null,
      token:       token,
    );
    if (token.isNotEmpty) {
      await AuthStorage.save(
        token:       token,
        idUsuario:   idUsuario,
        email:       user['email']?.toString() ?? '',
        nome:        user['nome']?.toString()  ?? '',
        tipoUsuario: tipoUsuario,
        idEmpresa:   idEmpresa > 0 ? idEmpresa : null,
      );
    }
    PushNotificationService.registrarAposLogin();
    if (!mounted) return;
    if (tipoUsuario == 'empresa') {
      Navigator.pushReplacementNamed(context, '/empresa');
    } else if (tipoUsuario == 'motoboy') {
      Navigator.pushReplacementNamed(context, '/motoboy');
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _loginGoogle() async {
    setState(() { _loading = true; _erro = null; });
    try {
      final idToken = await SocialAuthService.signInWithGoogle();
      if (idToken == null) { setState(() => _loading = false); return; }
      final resp = await ApiService.loginGoogle(idToken);
      await _loginComSocial(resp);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _erro    = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loginFacebook() async {
    setState(() { _loading = true; _erro = null; });
    try {
      final token = await SocialAuthService.signInWithFacebook();
      if (token == null) { setState(() => _loading = false); return; }
      final resp = await ApiService.loginFacebook(token);
      await _loginComSocial(resp);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _erro    = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  InputDecoration _fieldDeco({
    required String   hint,
    required IconData icon,
    required FocusNode focus,
    Widget? suffix,
  }) {
    final active = focus.hasFocus;
    return InputDecoration(
      hintText:  hint,
      hintStyle: GoogleFonts.poppins(color: const Color(0xFF9E9E9E), fontSize: 14),
      prefixIcon: Icon(icon, color: active ? _orange : const Color(0xFF9E9E9E), size: 20),
      suffixIcon: suffix,
      filled:    true,
      fillColor: _fieldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _orange, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      errorStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final logoHeight   = (screenHeight * 0.22).clamp(100.0, 200.0);

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/bg_login.png'),
          fit: BoxFit.fill,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),

                    // Logo
                    Center(
                      child: Image.asset(
                        'assets/logo.png',
                        height: logoHeight,
                        errorBuilder: (_, __, ___) =>
                            SizedBox(height: logoHeight),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Título
                    Text(
                      'Bem-vindo de volta!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize:   22,
                        fontWeight: FontWeight.bold,
                        color:      const Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // E-mail
                    TextFormField(
                      controller:   _emailCtrl,
                      focusNode:    _emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF212121)),
                      decoration: _fieldDeco(
                        hint:  'Ex: nome@email.com',
                        icon:  Icons.email_outlined,
                        focus: _emailFocus,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                        if (!RegExp(r'.+@.+\..+').hasMatch(v.trim())) return 'E-mail inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Senha
                    TextFormField(
                      controller:  _senhaCtrl,
                      focusNode:   _senhaFocus,
                      obscureText: _obscureSenha,
                      style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF212121)),
                      decoration: _fieldDeco(
                        hint:  'Digite sua senha',
                        icon:  Icons.lock_outline,
                        focus: _senhaFocus,
                        suffix: IconButton(
                          icon: Icon(
                            _obscureSenha
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: _senhaFocus.hasFocus ? _orange : const Color(0xFF9E9E9E),
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

                    // Esqueci minha senha
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PaginaEsqueciSenha()),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 0, vertical: 4),
                        ),
                        child: Text(
                          'Esqueci minha senha',
                          style: GoogleFonts.poppins(
                            fontSize:   13,
                            fontWeight: FontWeight.w500,
                            color:      _orange,
                          ),
                        ),
                      ),
                    ),

                    // Erro
                    if (_erro != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.redAccent, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _erro!,
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ] else
                      const SizedBox(height: 12),

                    // Botão Entrar
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _fazerLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _orange,
                          disabledBackgroundColor: _orange.withValues(alpha: 0.6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                          shadowColor: _orange.withValues(alpha: 0.4),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 22,
                                width:  22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : Text(
                                'Entrar',
                                style: GoogleFonts.poppins(
                                  fontSize:   16,
                                  fontWeight: FontWeight.bold,
                                  color:      Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Registrar-se
                    Center(
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const PaginaRegistro()),
                                ),
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: _grey),
                            children: [
                              const TextSpan(text: 'Ainda não tem conta? '),
                              TextSpan(
                                text: 'Registrar-se',
                                style: GoogleFonts.poppins(
                                  fontSize:   13,
                                  fontWeight: FontWeight.w700,
                                  color:      _orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Divisor "Ou entre com"
                    Row(
                      children: [
                        Expanded(
                            child: Divider(
                                color: Colors.grey.shade300, thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Ou entre com',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: _grey),
                          ),
                        ),
                        Expanded(
                            child: Divider(
                                color: Colors.grey.shade300, thickness: 1)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Botão Facebook
                    _socialBtn(
                      label: 'Continuar com Facebook',
                      icon: _FacebookIcon(),
                      onPressed: _loading ? null : _loginFacebook,
                    ),
                    const SizedBox(height: 10),

                    // Botão Google
                    _socialBtn(
                      label: 'Continuar com Google',
                      icon: _GoogleIcon(),
                      onPressed: _loading ? null : _loginGoogle,
                    ),
                    const SizedBox(height: 24),

                    // Trabalhe conosco
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TrabalheConoscoPage()),
                        ),
                        child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: _grey),
                              children: [
                                const TextSpan(text: 'Seja um parceiro: '),
                                TextSpan(
                                  text: 'Trabalhe Conosco →',
                                  style: GoogleFonts.poppins(
                                    fontSize:   13,
                                    fontWeight: FontWeight.w700,
                                    color:      _orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    const Spacer(),
                  ],
                ),
              ),
                ),
              ),
            ),
          ),
        ),
      );
  }

  Widget _socialBtn({required String label, required Widget icon, VoidCallback? onPressed}) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300, width: 1.2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
          disabledForegroundColor: const Color(0xFF424242).withValues(alpha: 1),
          disabledBackgroundColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize:   14,
                fontWeight: FontWeight.w500,
                color:      const Color(0xFF424242),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ícone Facebook ──────────────────────────────────────────────────────────
class _FacebookIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/facebook-logo.png', width: 24, height: 24);
  }
}

// ── Ícone Google ────────────────────────────────────────────────────────────
class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/google-logo.png', width: 24, height: 24);
  }
}
