import 'package:flutter/material.dart';

import '../../../data/session_store.dart';
import '../../../services/api_service.dart';
import '../cliente_enderecos/cliente_enderecos_page.dart';

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

  Map<String, dynamic>? _enderecoSel;  // endereço selecionado

  @override
  void initState() {
    super.initState();
    _carregarEnderecos();
  }

  Future<void> _carregarEnderecos() async {
    final id = SessionStore.idUsuario;
    if (id == null) return;
    final lista = await ApiService.getEnderecosCliente(id);
    if (!mounted) return;
    // Pré-seleciona o principal (ou o primeiro)
    final sel = lista.firstWhere(
      (e) => e['principal'] as bool? ?? false,
      orElse: () => lista.isNotEmpty ? lista.first : {},
    );
    setState(() => _enderecoSel = sel.isEmpty ? null : sel);
  }

  Future<void> _selecionarEndereco() async {
    final escolhido = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const ClienteEnderecosPage(modoSelecao: true),
      ),
    );
    if (escolhido != null && mounted) {
      setState(() => _enderecoSel = escolhido);
      // Recarrega lista caso tenha adicionado novo
      _carregarEnderecos().then((_) {
        if (mounted) setState(() => _enderecoSel = escolhido);
      });
    }
  }

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
      final adicionais = item['adicionais']?.toString() ?? '';
      final obs        = item['observacao']?.toString() ?? '';
      final descricao  = [adicionais, obs]
          .where((s) => s.isNotEmpty)
          .join(' | ');
      return {
        'id_produto': item['id_produto'],
        'quantidade': item['quantidade'],
        'preco_unit': _precoItem(item['preco']),
        if (descricao.isNotEmpty) 'observacao': descricao,
      };
    }).toList();

    final endereco = _enderecoSel?['endereco']?.toString().trim() ?? '';
    if (endereco.isEmpty) {
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um endereço de entrega.')),
      );
      return;
    }

    final erro = await ApiService.criarPedido(
      idUsuario:       idUsuario,
      idEmpresa:       idEmpresa is int ? idEmpresa : int.parse(idEmpresa.toString()),
      itens:           itensParaEnvio,
      enderecoEntrega: endereco,
      observacao:      _observacaoCtrl.text.trim(),
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
                      final nome       = item['nome']?.toString() ?? '';
                      final qtd        = item['quantidade'] ?? 1;
                      final preco      = _precoItem(item['preco']);
                      final subtotal   = preco * (qtd is num ? qtd.toInt() : 1);
                      final adicionais = item['adicionais']?.toString() ?? '';
                      final obs        = item['observacao']?.toString() ?? '';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                  if (adicionais.isNotEmpty)
                                    Text(
                                      adicionais,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange[700],
                                          fontStyle: FontStyle.italic),
                                    ),
                                  if (obs.isNotEmpty)
                                    Text(
                                      'Obs: $obs',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                          fontStyle: FontStyle.italic),
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

            // ---- Endereço de entrega ----
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.location_on_outlined, color: _cor, size: 20),
                      SizedBox(width: 8),
                      Text('Endereço de entrega',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 10),
                    // ── Endereço selecionado ─────────────────────
                    InkWell(
                      onTap: _selecionarEndereco,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _enderecoSel != null
                              ? _cor.withValues(alpha: 0.06)
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _enderecoSel != null
                                ? _cor
                                : Colors.red.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _enderecoSel != null
                                  ? Icons.location_on
                                  : Icons.location_off,
                              color: _enderecoSel != null
                                  ? _cor
                                  : Colors.red,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _enderecoSel != null
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _enderecoSel!['apelido']
                                                  ?.toString() ??
                                              'Endereço',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: _cor),
                                        ),
                                        Text(
                                          _enderecoSel!['endereco']
                                                  ?.toString() ??
                                              '',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700]),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    )
                                  : Text(
                                      'Nenhum endereço selecionado.\nToque para adicionar.',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.red[700]),
                                    ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.swap_vert,
                                color: Colors.grey[500], size: 20),
                          ],
                        ),
                      ),
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
