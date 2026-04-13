import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smarty_entregas/services/api_service.dart';

class PaginaRedefinirSenha extends StatefulWidget {
  final String email;
  const PaginaRedefinirSenha({super.key, required this.email});

  @override
  State<PaginaRedefinirSenha> createState() => _PaginaRedefinirSenhaState();
}

class _PaginaRedefinirSenhaState extends State<PaginaRedefinirSenha> {
  final _formKey       = GlobalKey<FormState>();
  final _codigoCtrl    = TextEditingController();
  final _senhaCtrl     = TextEditingController();
  final _confirmaCtrl  = TextEditingController();
  bool _loading        = false;
  bool _senhaVisivel   = false;
  bool _confirmaVisivel = false;

  static const _orange   = Color(0xFFF5841F);
  static const _iconGrey = Color(0xFF757575);

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmaCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final erro = await ApiService.resetPassword(
      email:     widget.email,
      codigo:    _codigoCtrl.text.trim(),
      novaSenha: _senhaCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(erro,
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
            ),
          ]),
        ),
      );
      return;
    }

    // Sucesso — volta até o login
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(children: [
          const Icon(Icons.check_circle_outline, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Senha redefinida com sucesso!',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
          ),
        ]),
        duration: const Duration(seconds: 3),
      ),
    );
    // Fecha tanto esta tela quanto a tela de esqueci-senha
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

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
        controller:       controller,
        obscureText:      obscure && !(visivel ?? false),
        keyboardType:     keyboardType,
        inputFormatters:  inputFormatters,
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
          filled:     true,
          fillColor:  Colors.white.withValues(alpha: 0.95),
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
        ),
        validator: validator,
      ),
    );
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
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 160,
                    errorBuilder: (_, __, ___) => const SizedBox(height: 60),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Redefinir senha',
                    style: GoogleFonts.poppins(
                      fontSize:   24,
                      fontWeight: FontWeight.bold,
                      color:      Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Text(
                    'Informe o código enviado para\n${widget.email}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Código
                  _buildField(
                    controller:     _codigoCtrl,
                    hint:           'Código de 6 dígitos',
                    icon:           Icons.lock_outline,
                    keyboardType:   TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().length != 6) {
                        return 'Informe o código de 6 dígitos';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Nova senha
                  _buildField(
                    controller:        _senhaCtrl,
                    hint:              'Nova senha',
                    icon:              Icons.lock_person_outlined,
                    obscure:           true,
                    visivel:           _senhaVisivel,
                    onToggleVisivel:   () =>
                        setState(() => _senhaVisivel = !_senhaVisivel),
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return 'A senha deve ter pelo menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirmar senha
                  _buildField(
                    controller:       _confirmaCtrl,
                    hint:             'Confirmar nova senha',
                    icon:             Icons.lock_person_outlined,
                    obscure:          true,
                    visivel:          _confirmaVisivel,
                    onToggleVisivel:  () =>
                        setState(() => _confirmaVisivel = !_confirmaVisivel),
                    validator: (v) {
                      if (v != _senhaCtrl.text) {
                        return 'As senhas não coincidem';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  // Botão confirmar
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
                      onPressed: _loading ? null : _confirmar,
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
                              'Redefinir senha',
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
                      'Reenviar código',
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
