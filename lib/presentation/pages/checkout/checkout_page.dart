import 'dart:math';
import '../../../presentation/navigation/app_routes.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/cart/cart.dart';

import '../../../data/session_store.dart';
import '../../../services/api_service.dart';
import '../../../services/mp_card_service.dart';
import '../cliente_enderecos/cliente_enderecos_page.dart';
import '../acompanhamento_pedido/acompanhamento_pedido_page.dart';
import '../pagamento/pix_page.dart';

// ── Cálculo de taxa de entrega por distância ─────────────────────────────────
double calcularDistanciaKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
      sin(dLon / 2) * sin(dLon / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

/// Taxa = taxa_minima do restaurante (mín R$ 7,00) + R$ 1,00/km (somente ida)
double calcularTaxaEntrega(double distKm, {double taxaMinima = 7.0}) =>
    taxaMinima + distKm;

/// Tempo estimado em minutos = preparo do restaurante + trânsito (~30 km/h)
int calcularTempoEstimado(int tempoPreparo, double distKm) =>
    tempoPreparo + (distKm * 2).ceil();

const Color _cor = Color(0xFFFFA726);

class CheckoutPage extends StatefulWidget {
  final Map<String, dynamic> empresa;

  const CheckoutPage({
    super.key,
    required this.empresa,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

// Opções de pagamento
enum _Pagamento { pix, cartaoCredito, cartaoDebito, dinheiro }

extension _PagamentoExt on _Pagamento {
  String get label {
    switch (this) {
      case _Pagamento.pix:           return 'PIX';
      case _Pagamento.cartaoCredito: return 'Cartão de crédito';
      case _Pagamento.cartaoDebito:  return 'Cartão de débito';
      case _Pagamento.dinheiro:      return 'Dinheiro';
    }
  }
  String get slug {
    switch (this) {
      case _Pagamento.pix:           return 'pix';
      case _Pagamento.cartaoCredito: return 'cartao_credito';
      case _Pagamento.cartaoDebito:  return 'cartao_debito';
      case _Pagamento.dinheiro:      return 'dinheiro';
    }
  }
  IconData get icon {
    switch (this) {
      case _Pagamento.pix:           return Icons.qr_code;
      case _Pagamento.cartaoCredito: return Icons.credit_card;
      case _Pagamento.cartaoDebito:  return Icons.credit_card_outlined;
      case _Pagamento.dinheiro:      return Icons.attach_money;
    }
  }
  bool get precisaFormularioCartao =>
      this == _Pagamento.cartaoCredito || this == _Pagamento.cartaoDebito;
}

class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _observacaoCtrl  = TextEditingController();
  final TextEditingController _trocoCtrl       = TextEditingController();
  final TextEditingController _cupomCtrl       = TextEditingController();
  // Formulário de cartão
  final TextEditingController _cardNumeroCtrl  = TextEditingController();
  final TextEditingController _cardNomeCtrl    = TextEditingController();
  final TextEditingController _cardValidadeCtrl = TextEditingController();
  final TextEditingController _cardCvvCtrl     = TextEditingController();
  final TextEditingController _cardCpfCtrl     = TextEditingController();

  bool _carregando      = false;
  bool _validandoCupom  = false;

  Map<String, dynamic>? _enderecoSel;
  _Pagamento? _pagamento;

  // Cupom
  String? _cupomAplicado;
  double  _desconto = 0.0;
  String? _cupomErro;

  // Taxa e tempo calculados a partir da distância
  double _taxaEntrega  = 7.0;
  int    _tempoMinutos = 30;

  void _recalcularEntrega(Map<String, dynamic> endereco) {
    final latEmp = widget.empresa['latitude'];
    final lonEmp = widget.empresa['longitude'];
    final latEnd = endereco['latitude'];
    final lonEnd = endereco['longitude'];
    final tempoPreparo = (widget.empresa['tempo_preparo'] is int
        ? widget.empresa['tempo_preparo'] as int
        : int.tryParse(widget.empresa['tempo_preparo']?.toString() ?? '') ?? 30);
    final taxaMinima = widget.empresa['taxa_minima'] is num
        ? (widget.empresa['taxa_minima'] as num).toDouble()
        : double.tryParse(widget.empresa['taxa_minima']?.toString() ?? '') ?? 7.0;

    if (latEmp is num && lonEmp is num && latEnd is num && lonEnd is num) {
      final dist = calcularDistanciaKm(
        latEmp.toDouble(), lonEmp.toDouble(),
        latEnd.toDouble(), lonEnd.toDouble(),
      );
      setState(() {
        _taxaEntrega  = calcularTaxaEntrega(dist, taxaMinima: taxaMinima);
        _tempoMinutos = calcularTempoEstimado(tempoPreparo, dist);
      });
    } else {
      // Restaurante ou endereço sem coordenadas — usa mínimo da empresa
      setState(() {
        _taxaEntrega  = taxaMinima;
        _tempoMinutos = tempoPreparo + 30;
      });
    }
  }

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
    if (lista == null) return;
    // Pré-seleciona o principal (ou o primeiro)
    final sel = lista.firstWhere(
      (e) => e['principal'] as bool? ?? false,
      orElse: () => lista.isNotEmpty ? lista.first : {},
    );
    if (!mounted) return;
    setState(() => _enderecoSel = sel.isEmpty ? null : sel);
    if (_enderecoSel != null) _recalcularEntrega(_enderecoSel!);
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
      _recalcularEntrega(escolhido);
      // Recarrega lista caso tenha adicionado novo
      _carregarEnderecos().then((_) {
        if (mounted) {
          setState(() => _enderecoSel = escolhido);
          _recalcularEntrega(escolhido);
        }
      });
    }
  }

  Future<void> _aplicarCupom() async {
    final codigo = _cupomCtrl.text.trim();
    if (codigo.isEmpty) return;
    setState(() { _validandoCupom = true; _cupomErro = null; });

    final result = await ApiService.validarCupom(
      codigo:      codigo,
      valorPedido: context.read<Cart>().total,
    );

    if (!mounted) return;
    if (result.containsKey('erro')) {
      setState(() {
        _cupomErro     = result['erro'] as String;
        _cupomAplicado = null;
        _desconto      = 0.0;
        _validandoCupom = false;
      });
    } else {
      setState(() {
        _cupomAplicado  = result['codigo'] as String?;
        _desconto       = (result['desconto'] as num?)?.toDouble() ?? 0.0;
        _cupomErro      = null;
        _validandoCupom = false;
      });
    }
  }

  void _removerCupom() {
    setState(() {
      _cupomAplicado = null;
      _desconto      = 0.0;
      _cupomErro     = null;
      _cupomCtrl.clear();
    });
  }

  @override
  void dispose() {
    _observacaoCtrl.dispose();
    _trocoCtrl.dispose();
    _cupomCtrl.dispose();
    _cardNumeroCtrl.dispose();
    _cardNomeCtrl.dispose();
    _cardValidadeCtrl.dispose();
    _cardCvvCtrl.dispose();
    _cardCpfCtrl.dispose();
    super.dispose();
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

    final cart = context.read<Cart>();
    if (cart.itens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione itens ao carrinho antes de finalizar.')),
      );
      return;
    }

    setState(() => _carregando = true);

    final itensParaEnvio = cart.itens.map((item) {
      final descricao = [item.resumoAdicionais, item.observacao ?? '']
          .where((s) => s.isNotEmpty)
          .join(' | ');
      final ids = item.adicionaisIds;
      return {
        'id_produto': item.idProduto,
        'quantidade': item.quantidade,
        'preco_unit': item.preco,
        if (descricao.isNotEmpty) 'observacao': descricao,
        if (ids.isNotEmpty) 'adicionais': ids,
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

    if (_pagamento == null) {
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a forma de pagamento.')),
      );
      return;
    }

    double? troco;
    if (_pagamento == _Pagamento.dinheiro) {
      final t = double.tryParse(_trocoCtrl.text.replaceAll(',', '.'));
      final total = cart.total;
      if (t != null && t < total) {
        setState(() => _carregando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            'Troco inválido. O valor deve ser maior que R\$ ${total.toStringAsFixed(2)}.')),
        );
        return;
      }
      troco = t;
    }

    // Valida e tokeniza cartão antes de enviar ao backend
    String? mpCardToken;
    if (_pagamento!.precisaFormularioCartao) {
      if (_cardNumeroCtrl.text.replaceAll(' ', '').length < 16 ||
          _cardNomeCtrl.text.trim().isEmpty ||
          _cardValidadeCtrl.text.length < 5 ||
          _cardCvvCtrl.text.length < 3 ||
          _cardCpfCtrl.text.replaceAll(RegExp(r'\D'), '').length < 11) {
        setState(() => _carregando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preencha todos os dados do cartão.'), backgroundColor: Colors.red),
        );
        return;
      }
      try {
        final partes = _cardValidadeCtrl.text.split('/');
        final tokenData = await MpCardService.tokenizarCartao(
          numero:        _cardNumeroCtrl.text,
          mesExpiracao:  partes[0],
          anoExpiracao:  partes.length > 1 ? '20${partes[1]}' : '',
          cvv:           _cardCvvCtrl.text,
          nomePortador:  _cardNomeCtrl.text.trim(),
          cpf:           _cardCpfCtrl.text,
        );
        mpCardToken = tokenData['token'] as String?;
      } catch (e) {
        setState(() => _carregando = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro no cartão: $e'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    final result = await ApiService.criarPedido(
      idUsuario:       idUsuario,
      idEmpresa:       idEmpresa is int ? idEmpresa : int.parse(idEmpresa.toString()),
      itens:           itensParaEnvio,
      enderecoEntrega: endereco,
      observacao:      _observacaoCtrl.text.trim(),
      formaPagamento:  _pagamento!.slug,
      trocoPara:       troco,
      codigoCupom:     _cupomAplicado,
      idEndereco:      _enderecoSel?['id_endereco'] is int
                           ? _enderecoSel!['id_endereco'] as int
                           : int.tryParse(_enderecoSel?['id_endereco']?.toString() ?? ''),
      mpCardToken:     mpCardToken,
    );

    setState(() => _carregando = false);
    if (!mounted) return;

    if (result.containsKey('erro')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['erro'] as String), backgroundColor: Colors.red),
      );
      return;
    }

    final idPedidoRaw = result['id_pedido'];
    final idPedido = idPedidoRaw is int
        ? idPedidoRaw
        : int.tryParse(idPedidoRaw?.toString() ?? '');
    if (idPedido == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido criado, mas resposta inesperada do servidor.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final nomeEmpresa  = widget.empresa['nome']?.toString() ?? '';
    final idEmpresaInt = idEmpresa is int ? idEmpresa : int.tryParse(idEmpresa.toString()) ?? 0;
    final subtotal     = cart.total;
    final itensDisplay = cart.itens.map((i) => i.toItemCheckout()).toList();
    cart.limpar();

    if (!mounted) return;

    // PIX: vai para tela de QR code
    if (_pagamento == _Pagamento.pix) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PagamentoPixPage(
            idPedido:        idPedido,
            idEmpresa:       idEmpresaInt,
            nomeEmpresa:     nomeEmpresa,
            enderecoEntrega: endereco,
            qrCodePix:       result['qr_code_pix']?.toString() ?? '',
            qrCodeBase64:    result['qr_code_base64']?.toString() ?? '',
            idPagamentoMp:   result['id_pagamento_mp']?.toString() ?? '',
            valorTotal:      subtotal + _taxaEntrega - _desconto,
          ),
        ),
      );
      return;
    }

    // Cartão ou dinheiro: vai para tela de confirmação
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _PedidoConfirmadoPage(
          idPedido:        idPedido,
          idEmpresa:       idEmpresaInt,
          nomeEmpresa:     nomeEmpresa,
          enderecoEntrega: endereco,
          itens:           itensDisplay,
          subtotal:        subtotal,
          taxaEntrega:     _taxaEntrega,
          desconto:        _desconto,
          tempoMinutos:    _tempoMinutos,
          pagamento:       _pagamento!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
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
                    ...cart.itens.map((item) {
                      final nome       = item.nome;
                      final qtd        = item.quantidade;
                      final preco      = item.preco;
                      final subtotal   = item.subtotal;
                      final adicionais = item.resumoAdicionais;
                      final obs        = item.observacao ?? '';

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
                          'R\$ ${cart.total.toStringAsFixed(2)}',
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

            // ---- Forma de pagamento ----
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.payment, color: _cor, size: 20),
                      const SizedBox(width: 8),
                      const Text('Forma de pagamento',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      if (_pagamento == null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text('obrigatório',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.red.shade700)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 12),
                    ..._Pagamento.values.map((op) {
                      final sel = _pagamento == op;
                      return GestureDetector(
                        onTap: () => setState(() => _pagamento = op),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: sel
                                ? _cor.withValues(alpha: 0.08)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: sel ? _cor : Colors.grey.shade300,
                              width: sel ? 2 : 1,
                            ),
                          ),
                          child: Row(children: [
                            Icon(op.icon,
                                color: sel ? _cor : Colors.grey,
                                size: 22),
                            const SizedBox(width: 12),
                            Text(op.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: sel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: sel ? _cor : Colors.black87,
                                )),
                            const Spacer(),
                            if (sel)
                              const Icon(Icons.check_circle,
                                  color: _cor, size: 20),
                          ]),
                        ),
                      );
                    }),
                    // Campo de troco
                    if (_pagamento == _Pagamento.dinheiro) ...[
                      const SizedBox(height: 4),
                      TextField(
                        controller: _trocoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Troco para quanto? (opcional)',
                          hintText: 'Ex.: 50,00 (deixe vazio se não precisar)',
                          prefixText: 'R\$ ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _cor, width: 2),
                          ),
                          isDense: true,
                        ),
                      ),
                    ],
                    // Formulário de cartão (crédito ou débito)
                    if (_pagamento != null && _pagamento!.precisaFormularioCartao) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 4),
                      const Text('Dados do cartão',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _cor)),
                      const SizedBox(height: 10),
                      _cardField(
                        controller: _cardNumeroCtrl,
                        label: 'Número do cartão',
                        hint: '0000 0000 0000 0000',
                        tipo: TextInputType.number,
                        maxLength: 19,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _CardNumberFormatter(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _cardField(
                        controller: _cardNomeCtrl,
                        label: 'Nome no cartão',
                        hint: 'Como aparece no cartão',
                        tipo: TextInputType.name,
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: _cardField(
                            controller: _cardValidadeCtrl,
                            label: 'Validade',
                            hint: 'MM/AA',
                            tipo: TextInputType.number,
                            maxLength: 5,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              _ExpiryFormatter(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _cardField(
                            controller: _cardCvvCtrl,
                            label: 'CVV',
                            hint: '123',
                            tipo: TextInputType.number,
                            maxLength: 4,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            obscure: true,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      _cardField(
                        controller: _cardCpfCtrl,
                        label: 'CPF do titular',
                        hint: '000.000.000-00',
                        tipo: TextInputType.number,
                        maxLength: 14,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _CpfFormatter(),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ---- Cupom de desconto ----
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
                      Icon(Icons.local_offer_outlined, color: _cor, size: 20),
                      SizedBox(width: 8),
                      Text('Cupom de desconto',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 10),
                    if (_cupomAplicado != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _cupomAplicado!,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.green),
                                  ),
                                  Text(
                                    'Desconto de R\$ ${_desconto.toStringAsFixed(2)}',
                                    style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _removerCupom,
                              icon: const Icon(Icons.close, color: Colors.red, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _cupomCtrl,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                hintText: 'Digite o código do cupom',
                                errorText: _cupomErro,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: _cor, width: 2),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _cor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              onPressed: _validandoCupom ? null : _aplicarCupom,
                              child: _validandoCupom
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text('Aplicar',
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
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

  Widget _cardField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType tipo = TextInputType.text,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    bool obscure = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) =>
      TextField(
        controller: controller,
        keyboardType: tipo,
        obscureText: obscure,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          counterText: '',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _cor, width: 2),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      );
}

// Formata número do cartão em grupos de 4 dígitos
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue novo) {
    final digits = novo.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return novo.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

// Formata validade como MM/AA
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue novo) {
    final digits = novo.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 4; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return novo.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

// Formata CPF como 000.000.000-00
class _CpfFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue novo) {
    final digits = novo.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 11; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return novo.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

// ── Tela de confirmação pós-pedido ───────────────────────────────
class _PedidoConfirmadoPage extends StatelessWidget {
  final int    idPedido;
  final int    idEmpresa;
  final String nomeEmpresa;
  final String enderecoEntrega;
  final List<Map<String, dynamic>> itens;
  final double subtotal;
  final double taxaEntrega;
  final double desconto;
  final int    tempoMinutos;
  final _Pagamento pagamento;

  const _PedidoConfirmadoPage({
    required this.idPedido,
    required this.idEmpresa,
    required this.nomeEmpresa,
    required this.enderecoEntrega,
    required this.itens,
    required this.subtotal,
    required this.taxaEntrega,
    required this.desconto,
    required this.tempoMinutos,
    required this.pagamento,
  });

  double _precoItem(dynamic preco) {
    if (preco is num) return preco.toDouble();
    if (preco is String) return double.tryParse(preco) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // ── Ícone de sucesso ──
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 48),
              ),
              const SizedBox(height: 16),
              const Text('Pedido realizado!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Seu pedido foi enviado para $nomeEmpresa',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _cor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Pedido #$idPedido',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _cor)),
              ),
              const SizedBox(height: 24),

              // ── Resumo ──
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Resumo do pedido',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const Divider(height: 20),
                    ...itens.map((item) {
                      final nome  = item['nome']?.toString() ?? '';
                      final qtd   = item['quantidade'] ?? 1;
                      final preco = _precoItem(item['preco']);
                      final sub   = preco * (qtd is num ? qtd.toInt() : 1);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text('${qtd}x ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            Expanded(child: Text(nome,
                                style: const TextStyle(fontSize: 13))),
                            Text('R\$ ${sub.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal',
                            style: TextStyle(fontSize: 13, color: Colors.black54)),
                        Text('R\$ ${subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13, color: Colors.black54)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Taxa de entrega',
                            style: TextStyle(fontSize: 13, color: Colors.black54)),
                        Text('R\$ ${taxaEntrega.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13, color: Colors.black54)),
                      ],
                    ),
                    if (desconto > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Desconto (cupom)',
                              style: TextStyle(fontSize: 13, color: Colors.green)),
                          Text('- R\$ ${desconto.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('R\$ ${(subtotal + taxaEntrega - desconto).toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: _cor)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Detalhes ──
              _card(
                child: Column(
                  children: [
                    _infoRow(Icons.location_on_outlined, 'Entrega em', enderecoEntrega),
                    const SizedBox(height: 10),
                    _infoRow(pagamento.icon, 'Pagamento', pagamento.label),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Próximos passos ──
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Próximos passos',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    _passo('1', 'Aguardando confirmação do restaurante'),
                    _passo('2', 'Preparando seu pedido'),
                    _passo('3', 'Saindo para entrega'),
                    _passo('4', 'Entregue!'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Botão acompanhar ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => AcompanhamentoPedidoPage(
                        idPedido:        idPedido,
                        idEmpresa:       idEmpresa,
                        nomeEmpresa:     nomeEmpresa,
                        enderecoEntrega: enderecoEntrega,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.delivery_dining),
                  label: const Text('Acompanhar pedido',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
                  child: Text('Voltar ao início',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      );

  Widget _infoRow(IconData icon, String label, String valor) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _cor, size: 18),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            Text(valor,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ],
      );

  Widget _passo(String num, String texto) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: _cor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(num,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _cor)),
            ),
          ),
          const SizedBox(width: 10),
          Text(texto, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ]),
      );
}
