import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../../../services/api_service.dart';

class TrabalheConoscoPage extends StatefulWidget {
  const TrabalheConoscoPage({super.key});

  @override
  State<TrabalheConoscoPage> createState() => _TrabalheConoscoPageState();
}

class _TrabalheConoscoPageState extends State<TrabalheConoscoPage> {
  String _tipo = 'Empresa';
  bool _carregando = false;
  String? _erro;

  // Controladores
  final _nomeCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _docCtrl      = TextEditingController(); // CNPJ ou CPF
  final _telefoneCtrl = TextEditingController();
  final _senhaCtrl    = TextEditingController();

  // Máscaras
  final _cnpjFmt = MaskTextInputFormatter(
    mask: '##.###.###/####-##',
    filter: {'#': RegExp(r'[0-9]')},
  );
  final _cpfFmt = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {'#': RegExp(r'[0-9]')},
  );
  final _telFmt = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'[0-9]')},
  );

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _docCtrl.dispose();
    _telefoneCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  void _limparCampos() {
    _nomeCtrl.clear();
    _emailCtrl.clear();
    _docCtrl.clear();
    _telefoneCtrl.clear();
    _senhaCtrl.clear();
    _cnpjFmt.clear();
    _cpfFmt.clear();
    _telFmt.clear();
  }

  Future<void> _cadastrar() async {
    setState(() {
      _erro = null;
      _carregando = true;
    });

    final nome     = _nomeCtrl.text.trim();
    final email    = _emailCtrl.text.trim();
    final doc      = _tipo == 'Empresa'
        ? _cnpjFmt.getMaskedText()   // XX.XXX.XXX/XXXX-XX
        : _cpfFmt.getMaskedText();   // XXX.XXX.XXX-XX
    final telefone = _telFmt.getMaskedText(); // (XX) XXXXX-XXXX
    final senha    = _senhaCtrl.text;

    // Validações
    if (nome.isEmpty || email.isEmpty || senha.isEmpty) {
      setState(() {
        _erro = 'Nome, e-mail e senha são obrigatórios.';
        _carregando = false;
      });
      return;
    }
    if (_tipo == 'Empresa' && doc.replaceAll(RegExp(r'\D'), '').length < 14) {
      setState(() {
        _erro = 'CNPJ incompleto (14 dígitos necessários).';
        _carregando = false;
      });
      return;
    }
    if (_tipo == 'Motoboy' && doc.replaceAll(RegExp(r'\D'), '').length < 11) {
      setState(() {
        _erro = 'CPF incompleto (11 dígitos necessários).';
        _carregando = false;
      });
      return;
    }
    if (telefone.replaceAll(RegExp(r'\D'), '').length < 11) {
      setState(() {
        _erro = 'Telefone incompleto.';
        _carregando = false;
      });
      return;
    }
    if (senha.length < 6) {
      setState(() {
        _erro = 'Senha deve ter pelo menos 6 caracteres.';
        _carregando = false;
      });
      return;
    }

    String? erroApi;

    if (_tipo == 'Empresa') {
      erroApi = await ApiService.registerEmpresa(
        nome:      nome,
        email:     email,
        senha:     senha,
        cnpj:      doc,
        telefone:  telefone,
      );
    } else {
      erroApi = await ApiService.registerCliente(
        nome:      nome,
        email:     email,
        senha:     senha,
        cpf:       doc,
        telefone:  telefone,
      );
    }

    if (!mounted) return;

    if (erroApi != null) {
      setState(() {
        _erro = erroApi;
        _carregando = false;
      });
      return;
    }

    setState(() => _carregando = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tipo == 'Empresa'
              ? 'Empresa cadastrada! Faça login para continuar.'
              : 'Cadastro realizado! Faça login para continuar.',
        ),
        backgroundColor: Colors.green,
      ),
    );

    // Volta para login
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  InputDecoration _deco(String label) => InputDecoration(
        hintText: label,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.orange, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isEmpresa = _tipo == 'Empresa';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFA726), Color(0xFFFFEB3B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 150,
                  errorBuilder: (_, __, ___) => const SizedBox(height: 60),
                ),
                const SizedBox(height: 16),

                // Toggle Empresa | Motoboy
                Container(
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: ['Empresa', 'Motoboy'].map((t) {
                      final sel = _tipo == t;
                      final isFirst = t == 'Empresa';
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _limparCampos();
                            setState(() {
                              _tipo = t;
                              _erro = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: sel ? Colors.orange : Colors.transparent,
                              borderRadius: BorderRadius.only(
                                topLeft: isFirst
                                    ? const Radius.circular(12)
                                    : Radius.zero,
                                bottomLeft: isFirst
                                    ? const Radius.circular(12)
                                    : Radius.zero,
                                topRight: !isFirst
                                    ? const Radius.circular(12)
                                    : Radius.zero,
                                bottomRight: !isFirst
                                    ? const Radius.circular(12)
                                    : Radius.zero,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                t,
                                style: TextStyle(
                                  color: sel ? Colors.white : Colors.brown,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  isEmpresa ? 'Cadastro de Empresa' : 'Cadastro de Motoboy',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown,
                  ),
                ),
                const SizedBox(height: 20),

                // Nome fantasia ou Nome completo
                TextField(
                  controller: _nomeCtrl,
                  decoration:
                      _deco(isEmpresa ? 'Nome fantasia *' : 'Nome completo *'),
                ),
                const SizedBox(height: 12),

                // E-mail
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _deco('E-mail *'),
                ),
                const SizedBox(height: 12),

                // CNPJ ou CPF
                TextField(
                  controller: _docCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [isEmpresa ? _cnpjFmt : _cpfFmt],
                  decoration: _deco(isEmpresa ? 'CNPJ *' : 'CPF *'),
                ),
                const SizedBox(height: 12),

                // Telefone
                TextField(
                  controller: _telefoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [_telFmt],
                  decoration: _deco('Telefone * (XX) XXXXX-XXXX'),
                ),
                const SizedBox(height: 12),

                // Senha
                TextField(
                  controller: _senhaCtrl,
                  obscureText: true,
                  decoration: _deco('Senha * (mín. 6 caracteres)'),
                ),
                const SizedBox(height: 16),

                if (_erro != null) ...[
                  Text(_erro!,
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _carregando ? null : _cadastrar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _carregando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Cadastrar',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Voltar',
                    style: TextStyle(color: Colors.brown, fontSize: 16),
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
