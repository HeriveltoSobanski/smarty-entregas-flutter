import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class PaginaRegistro extends StatefulWidget {
  const PaginaRegistro({super.key});

  @override
  State<PaginaRegistro> createState() => _PaginaRegistroState();
}

class _PaginaRegistroState extends State<PaginaRegistro> {
  final nomeController = TextEditingController();
  final cpfController = TextEditingController();
  final telefoneController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();

  // Máscara CPF -> 111.111.111-11
  final cpfFormatter = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {'#': RegExp(r'[0-9]')},
  );

  // Telefone -> (11) 11111111  (8 dígitos)
  final telefoneFormatter = MaskTextInputFormatter(
    mask: '(##) ########',
    filter: {'#': RegExp(r'[0-9]')},
  );

  String? erro;
  bool carregando = false;

  InputDecoration campoMinimalista(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.95),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.orange, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    );
  }

  Future<void> _registrarCliente() async {
    setState(() {
      erro = null;
      carregando = true;
    });

    try {
      final uri = Uri.parse('http://localhost:8080/register/cliente');

      final body = jsonEncode({
        'nome': nomeController.text.trim(),
        'cpf': cpfFormatter.getUnmaskedText(), // só números
        'telefone': telefoneFormatter.getUnmaskedText(), // só números
        'email': emailController.text.trim(),
        'senha': senhaController.text,
      });

      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (!mounted) return;

      if (resp.statusCode == 200) {
        // Registro OK → volta para login
        Navigator.pop(context);
      } else {
        setState(() {
          erro = 'Erro ao registrar cliente (${resp.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        erro = 'Erro interno ao registrar cliente';
      });
    } finally {
      if (mounted) {
        setState(() => carregando = false);
      }
    }
  }

  @override
  void dispose() {
    nomeController.dispose();
    cpfController.dispose();
    telefoneController.dispose();
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFA726), Color(0xFFFFEB3B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 180,
                  errorBuilder: (context, error, stackTrace) {
                    return const Text(
                      'Logo não encontrada',
                      style: TextStyle(color: Colors.white),
                    );
                  },
                ),
                const SizedBox(height: 30),

                const Text(
                  'Registre-se',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 50,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 30),

                TextField(
                  controller: nomeController,
                  decoration: campoMinimalista('Nome'),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: cpfController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [cpfFormatter],
                  decoration: campoMinimalista('CPF'),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: telefoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [telefoneFormatter],
                  decoration: campoMinimalista('Telefone'),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: campoMinimalista('E-mail'),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: senhaController,
                  obscureText: true,
                  decoration: campoMinimalista('Senha'),
                ),
                const SizedBox(height: 16),

                if (erro != null) ...[
                  Text(
                    erro!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: carregando ? null : _registrarCliente,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      carregando ? 'Registrando...' : 'Registrar',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Voltar para Login',
                    style: TextStyle(
                      color: Colors.black,
                      decoration: TextDecoration.underline,
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
