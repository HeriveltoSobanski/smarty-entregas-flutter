import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PaginaEsqueciSenha extends StatefulWidget {
  const PaginaEsqueciSenha({super.key});

  @override
  State<PaginaEsqueciSenha> createState() => _PaginaEsqueciSenhaState();
}

class _PaginaEsqueciSenhaState extends State<PaginaEsqueciSenha> {
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _emailFocus = FocusNode();
  bool _loading = false;

  static const _orange   = Color(0xFFF5841F);
  static const _iconGrey = Color(0xFF757575);

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void _enviar() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Se este e-mail estiver cadastrado, '
                  'enviaremos o link de redefinição.',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = _emailFocus.hasFocus;

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
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 200,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(height: 80),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Esqueci minha senha',
                    style: GoogleFonts.poppins(
                      fontSize:   24,
                      fontWeight: FontWeight.bold,
                      color:      Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Informe seu e-mail cadastrado e enviaremos '
                    'um link para redefinir sua senha.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Campo e-mail
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
                      controller:   _emailCtrl,
                      focusNode:    _emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        hintText:  'E-mail',
                        hintStyle: GoogleFonts.poppins(
                            color: _iconGrey, fontSize: 14),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.email_outlined,
                              color: active ? _orange : _iconGrey, size: 22),
                        ),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 48, minHeight: 48),
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
                            fontSize: 11,
                            color: const Color(0xFFFFCDD2)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 18),
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

                  // Botão enviar
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
                      onPressed: _loading ? null : _enviar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _orange,
                        disabledBackgroundColor:
                            _orange.withValues(alpha: 0.6),
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
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Text(
                              'Enviar link de redefinição',
                              style: GoogleFonts.poppins(
                                fontSize:   16,
                                fontWeight: FontWeight.bold,
                                color:      Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextButton(
                    onPressed: () => Navigator.pop(context),
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
