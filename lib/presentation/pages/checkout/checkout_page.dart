import 'package:flutter/material.dart';

import '../../../data/session_store.dart';
import '../../../services/api_service.dart';

const Color _cor = Color(0xFFFFA726);

class CheckoutPage extends StatefulWidget {
  final Map<String, dynamic> empresa;
  final List<Map<String, dynamic>> itens;
  final double total;

  const CheckoutPage({
    super.key,
    required this.empresa,
    required this.itens,
    required this.total,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _observacaoCtrl = TextEditingController();
  bool _carregando = false;

  @override
  void dispose() {
    _observacaoCtrl.dispose();
    super.dispose();
  }

  double _precoItem(dynamic preco) {
    if (preco is num) return preco.toDouble();
    if (preco is String) return double.tryParse(preco) ?? 0.0;
    return 0.0;
  }

  Future<void> _confirmarPedido() async {
    final idUsuario = SessionStore.idUsuario;
    if (idUsuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não autenticado.')),
      );
      return;
    }

    final idEmpresa = widget.empresa['id_empresa'];
    if (idEmpresa == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Empresa inválida.')),
      );
      return;
    }

    setState(() => _carregando = true);

    final itensParaEnvio = widget.itens.map((item) {
      return {
        'id_produto': item['id_produto'],
        'quantidade': item['quantidade'],
        'preco_unit': _precoItem(item['preco']),
      };
    }).toList();

    final erro = await ApiService.criarPedido(
      idUsuario: idUsuario,
      idEmpresa: idEmpresa is int ? idEmpresa : int.parse(idEmpresa.toString()),
      itens: itensParaEnvio,
    );

    setState(() => _carregando = false);

    if (!mounted) return;

    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(erro),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Pedido realizado!'),
        content: const Text('Seu pedido foi realizado com sucesso.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/home', (_) => false);
            },
            child: const Text('OK', style: TextStyle(color: _cor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nomeEmpresa =
        widget.empresa['nome']?.toString() ?? 'Empresa';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _cor,
        elevation: 0,
        title: const Text(
          'Finalizar Pedido',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- Card empresa ----
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.store, color: _cor, size: 32),
                title: const Text(
                  'Restaurante / Loja',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                subtitle: Text(
                  nomeEmpresa,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ---- Card itens ----
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Itens do Pedido',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 20),
                    ...widget.itens.map((item) {
                      final nome = item['nome']?.toString() ?? '';
                      final qtd = item['quantidade'] ?? 1;
                      final preco = _precoItem(item['preco']);
                      final subtotal = preco * (qtd is num ? qtd.toInt() : 1);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nome,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'Qtd: $qtd  ×  R\$ ${preco.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'R\$ ${subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'R\$ ${widget.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _cor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ---- Observação ----
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Observações (opcional)',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _observacaoCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Ex.: sem cebola, ponto da carne...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: _cor, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ---- Botão confirmar ----
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                ),
                onPressed: _carregando ? null : _confirmarPedido,
                icon: _carregando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _carregando ? 'Enviando...' : 'Confirmar Pedido',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
