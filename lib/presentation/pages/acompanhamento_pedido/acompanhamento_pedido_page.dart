import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/utils/app_logger.dart';
import '../../../services/api_service.dart';
import '../avaliacao/avaliacao_page.dart';
import '../suporte/suporte_page.dart';
import '../cancelar_pedido/cancelar_pedido_page.dart';

const Color _laranja = Color(0xFFF5841F);

// Status IDs: 1=Aguardando, 2=Preparando, 3=A caminho, 4=Entregue, 5=Cancelado
class AcompanhamentoPedidoPage extends StatefulWidget {
  final int    idPedido;
  final int    idEmpresa;
  final String nomeEmpresa;
  final String enderecoEntrega;

  const AcompanhamentoPedidoPage({
    super.key,
    required this.idPedido,
    required this.idEmpresa,
    required this.nomeEmpresa,
    required this.enderecoEntrega,
  });

  @override
  State<AcompanhamentoPedidoPage> createState() =>
      _AcompanhamentoPedidoPageState();
}

class _AcompanhamentoPedidoPageState
    extends State<AcompanhamentoPedidoPage> {
  Map<String, dynamic>? _pedido;
  bool   _carregando = true;
  Timer? _timer;
  bool   _navegouAvaliacao = false;
  int    _ultimoStatus = 0;

  static const _intervalMin     = 6;
  static const _intervalMax     = 30;
  static const _intervalMaxErro = 60;
  int _intervalAtual = _intervalMin;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _agendarPoll(int segundos) {
    _timer?.cancel();
    _timer = Timer(Duration(seconds: segundos), _carregar);
  }

  Future<void> _carregar() async {
    Map<String, dynamic>? data;
    try {
      data = await ApiService.getPedidoDetalhes(widget.idPedido);
    } catch (e, st) {
      AppLogger.e('AcompanhamentoPedido', e, st);
      // Backoff em erro: dobra intervalo até máximo de 60s
      _intervalAtual = (_intervalAtual * 2).clamp(_intervalMin, _intervalMaxErro);
      if (mounted) {
        setState(() => _carregando = false);
        _agendarPoll(_intervalAtual);
      }
      return;
    }

    if (!mounted) return;
    if (data != null) {
      final novoStatus = data['id_status'] is int
          ? data['id_status'] as int
          : int.tryParse(data['id_status']?.toString() ?? '') ?? 1;

      final statusMudou = novoStatus != _ultimoStatus;

      if (novoStatus == 4 || novoStatus == 5) {
        // Status terminal — para polling
        _timer?.cancel();
      } else if (statusMudou) {
        // Mudança detectada — reseta para intervalo mínimo
        _intervalAtual = _intervalMin;
        _agendarPoll(_intervalAtual);
      } else {
        // Sem mudança — aumenta intervalo 1.5x até máximo de 30s
        _intervalAtual = (_intervalAtual * 1.5).round().clamp(_intervalMin, _intervalMax);
        _agendarPoll(_intervalAtual);
      }

      setState(() {
        _pedido       = data;
        _carregando   = false;
        _ultimoStatus = novoStatus;
      });

      // Quando entregue, mostra pop-up e navega para avaliação (só uma vez)
      if (novoStatus == 4 && !_navegouAvaliacao && mounted) {
        _navegouAvaliacao = true;
        final idMotoboy = data['id_motoboy'] is int
            ? data['id_motoboy'] as int
            : int.tryParse(data['id_motoboy']?.toString() ?? '');
        final nomeMotoboy = data['motoboy_nome']?.toString();

        final avaliar = await _mostrarDialogEntregue();
        if (!mounted) return;

        if (avaliar == true) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AvaliacaoPage(
                idPedido:    widget.idPedido,
                idEmpresa:   widget.idEmpresa,
                nomeEmpresa: widget.nomeEmpresa,
                idMotoboy:   idMotoboy,
                nomeMotoboy: nomeMotoboy,
              ),
            ),
          );
        }
      }
    } else {
      // API retornou null — trata como erro transitório
      _intervalAtual = (_intervalAtual * 2).clamp(_intervalMin, _intervalMaxErro);
      setState(() => _carregando = false);
      _agendarPoll(_intervalAtual);
    }
  }

  // ── Passos do progresso (ids de status) ─────────────────────────
  static const _passos = [
    _Passo(id: 1, label: 'Aguardando',  icon: Icons.access_time,          cor: Colors.grey),
    _Passo(id: 2, label: 'Preparando',  icon: Icons.local_fire_department, cor: Colors.orange),
    _Passo(id: 3, label: 'A caminho',   icon: Icons.delivery_dining,       cor: Colors.blue),
    _Passo(id: 4, label: 'Entregue',    icon: Icons.check_circle,          cor: Color(0xFF4CAF50)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _laranja,
        foregroundColor: Colors.white,
        title: Text('Pedido #${widget.idPedido}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _intervalAtual = _intervalMin;
              setState(() => _carregando = true);
              _carregar();
            },
          ),
        ],
      ),
      body: _carregando && _pedido == null
          ? const Center(child: CircularProgressIndicator(color: _laranja))
          : _buildConteudo(),
    );
  }

  Widget _buildConteudo() {
    if (_pedido == null) {
      return const Center(
        child: Text('Não foi possível carregar o pedido.',
            style: TextStyle(color: Colors.grey)),
      );
    }

    final idStatus    = _ultimoStatus;
    final cancelado   = idStatus == 5;
    final quasePronto = _pedido!['quase_pronto'] == true;
    final motoboy     = _pedido!['motoboy_nome']?.toString();
    final motoboyTel  = _pedido!['motoboy_telefone']?.toString();
    final pagamento   = _pedido!['forma_pagamento']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        // ── Banner cancelado ───────────────────────────────────
        if (cancelado)
          _card(
            cor: Colors.red.shade50,
            borda: Colors.red.shade300,
            child: const Row(children: [
              Icon(Icons.cancel, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Pedido cancelado',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.red)),
                  Text('Entre em contato com o restaurante.',
                      style: TextStyle(fontSize: 13, color: Colors.red)),
                ]),
              ),
            ]),
          ),

        // ── Banner quase pronto ────────────────────────────────
        if (quasePronto && idStatus == 2) ...[
          _card(
            cor: Colors.deepOrange.shade50,
            borda: Colors.deepOrange.shade200,
            child: const Row(children: [
              Icon(Icons.notifications_active,
                  color: Colors.deepOrange, size: 26),
              SizedBox(width: 12),
              Expanded(
                child: Text('Seu pedido está quase pronto!\nO motoboy será chamado em breve.',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.deepOrange)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
        ],

        // ── Stepper de progresso ───────────────────────────────
        if (!cancelado)
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Status do pedido',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 16),
                ..._passos.asMap().entries.map((entry) {
                  final i    = entry.key;
                  final paso = entry.value;
                  final ativo    = idStatus == paso.id;
                  final concluido = idStatus > paso.id;
                  final cor = concluido || ativo ? paso.cor : Colors.grey.shade300;

                  return Column(children: [
                    Row(children: [
                      // Ícone do passo
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cor.withValues(alpha: concluido || ativo ? 0.15 : 0.05),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cor,
                            width: ativo ? 2.5 : 1.5,
                          ),
                        ),
                        child: Icon(
                          concluido ? Icons.check : paso.icon,
                          color: cor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(paso.label,
                                style: TextStyle(
                                  fontWeight: ativo
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: ativo ? 15 : 14,
                                  color: concluido || ativo
                                      ? Colors.black87
                                      : Colors.grey,
                                )),
                            if (ativo)
                              Text(_descricaoStatus(idStatus),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      if (ativo)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: paso.cor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('Agora',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: paso.cor)),
                        ),
                    ]),
                    // Linha conectora
                    if (i < _passos.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 19),
                        child: Container(
                          width: 2,
                          height: 24,
                          color: idStatus > paso.id
                              ? paso.cor.withValues(alpha: 0.4)
                              : Colors.grey.shade200,
                        ),
                      ),
                  ]);
                }),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // ── Info do motoboy ────────────────────────────────────
        if (motoboy != null && motoboy.isNotEmpty && idStatus == 3)
          _card(
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delivery_dining,
                    color: Colors.blue, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Entregador',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(motoboy,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  if (motoboyTel != null && motoboyTel.isNotEmpty)
                    Text(motoboyTel,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.grey)),
                ]),
              ),
            ]),
          ),

        if (motoboy != null && motoboy.isNotEmpty && idStatus == 3)
          const SizedBox(height: 12),

        // ── Restaurante ────────────────────────────────────────
        _card(
          child: _infoRow(
            icon: Icons.store_outlined,
            label: 'Restaurante',
            value: widget.nomeEmpresa,
          ),
        ),
        const SizedBox(height: 12),

        // ── Endereço ───────────────────────────────────────────
        _card(
          child: _infoRow(
            icon: Icons.location_on_outlined,
            label: 'Endereço de entrega',
            value: widget.enderecoEntrega,
          ),
        ),
        const SizedBox(height: 12),

        // ── Pagamento ──────────────────────────────────────────
        if (pagamento.isNotEmpty)
          _card(
            child: _infoRow(
              icon: Icons.payment,
              label: 'Pagamento',
              value: _labelPagamento(pagamento),
            ),
          ),

        if (pagamento.isNotEmpty) const SizedBox(height: 12),

        // ── Indicador de atualização automática ───────────────
        if (idStatus != 4 && idStatus != 5)
          Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 8),
              Text('Atualizando automaticamente...',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500)),
            ]),
          ),

        // ── Botão cancelar (apenas aguardando) ────────────────────
        if (idStatus == 1) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final total = (_pedido!['total'] is num)
                      ? (_pedido!['total'] as num).toDouble()
                      : double.tryParse(
                              _pedido!['total']?.toString() ?? '') ??
                          0.0;
                  final cancelado = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CancelarPedidoPage(
                        idPedido: widget.idPedido,
                        nomeEmpresa: widget.nomeEmpresa,
                        total: total,
                      ),
                    ),
                  );
                  if (cancelado == true && mounted) {
                    setState(() => _carregando = true);
                    _carregar();
                  }
                },
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancelar pedido'),
              ),
            ),
          ),
        ],

        // ── Botão suporte (cancelado ou aguardando há muito tempo) ─
        if (idStatus == 5 || idStatus == 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SuportePage(idPedido: widget.idPedido),
                ),
              ),
              icon: const Icon(Icons.support_agent, size: 18),
              label: const Text('Preciso de ajuda com este pedido'),
            ),
          ),

        // ── Botão voltar ao início quando entregue ─────────────
        if (idStatus == 4) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(context)
                  .pushNamedAndRemoveUntil('/home', (_) => false),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Voltar ao início',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],

        const SizedBox(height: 16),
      ],
    );
  }

  Future<bool?> _mostrarDialogEntregue() => showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: Colors.green, size: 38),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pedido entregue!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Seu pedido chegou. Como foi sua experiência?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _laranja,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Avaliar agora',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Avaliar depois',
                    style: TextStyle(color: Colors.grey.shade500)),
              ),
            ],
          ),
        ),
      );

  String _descricaoStatus(int id) {
    switch (id) {
      case 1: return 'Aguardando confirmação do restaurante';
      case 2: return 'O restaurante está preparando seu pedido';
      case 3: return 'O entregador está a caminho';
      case 4: return 'Pedido entregue com sucesso!';
      default: return '';
    }
  }

  String _labelPagamento(String slug) {
    switch (slug) {
      case 'pix':           return 'Pix';
      case 'cartao_entrega': return 'Cartão na entrega';
      case 'dinheiro':      return 'Dinheiro';
      default:              return slug;
    }
  }

  Widget _card({
    required Widget child,
    Color? cor,
    Color? borda,
  }) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cor ?? Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: borda != null ? Border.all(color: borda) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );

  Widget _infoRow({
    required IconData icon,
    required String   label,
    required String   value,
  }) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: _laranja),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]);
}

// ── Modelo interno de passo ──────────────────────────────────────
class _Passo {
  final int      id;
  final String   label;
  final IconData icon;
  final Color    cor;
  const _Passo({required this.id, required this.label,
                required this.icon, required this.cor});
}
