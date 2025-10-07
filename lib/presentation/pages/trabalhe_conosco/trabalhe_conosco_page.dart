import 'package:flutter/material.dart';

class TrabalheConoscoPage extends StatefulWidget {
  const TrabalheConoscoPage({super.key});

  @override
  State<TrabalheConoscoPage> createState() => _TrabalheConoscoPageState();
}

class _TrabalheConoscoPageState extends State<TrabalheConoscoPage> {
  String tipoUsuario = 'Motoboy';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFA726), Color(0xFFFFEB3B)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                // Ativa o scroll apenas se a tela for pequena
                physics: constraints.maxHeight < 700
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),

                          // Logo
                          Image.asset(
                            'assets/logo.png',
                            height: constraints.maxHeight < 700 ? 130 : 180,
                            errorBuilder: (context, error, stackTrace) {
                              return const Text(
                                'Logo não encontrada',
                                style: TextStyle(color: Colors.white),
                              );
                            },
                          ),
                          const SizedBox(height: 20),

                          // Seletor Empresa | Motoboy
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => tipoUsuario = 'Empresa'),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: tipoUsuario == 'Empresa'
                                            ? Colors.orange
                                            : Colors.transparent,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(12),
                                          bottomLeft: Radius.circular(12),
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Center(
                                        child: Text(
                                          'Empresa',
                                          style: TextStyle(
                                            color: tipoUsuario == 'Empresa'
                                                ? Colors.white
                                                : Colors.brown,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => tipoUsuario = 'Motoboy'),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: tipoUsuario == 'Motoboy'
                                            ? Colors.orange
                                            : Colors.transparent,
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(12),
                                          bottomRight: Radius.circular(12),
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Center(
                                        child: Text(
                                          'Motoboy',
                                          style: TextStyle(
                                            color: tipoUsuario == 'Motoboy'
                                                ? Colors.white
                                                : Colors.brown,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),

                          const Text(
                            'Registro',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.brown,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Campos
                          _campoTexto('Nome completo'),
                          const SizedBox(height: 12),
                          _campoTexto('E-mail'),
                          const SizedBox(height: 12),
                          _campoTexto(
                              tipoUsuario == 'Motoboy' ? 'CPF' : 'CNPJ'),
                          const SizedBox(height: 12),
                          _campoTexto('Telefone'),
                          const SizedBox(height: 12),
                          _campoTexto('Confirmar senha', obscure: true),
                          const SizedBox(height: 25),

                          // Botão cadastrar
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      tipoUsuario == 'Motoboy'
                                          ? 'Motoboy cadastrado com sucesso!'
                                          : 'Empresa cadastrada com sucesso!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                              child: const Text(
                                'Cadastrar',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),

                          // Voltar
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Voltar',
                              style: TextStyle(
                                color: Colors.brown,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Campo de texto padrão
  Widget _campoTexto(String label,
      {bool obscure = false,
      TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: label,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
