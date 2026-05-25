import 'package:flutter/material.dart';
import '../../../core/utils/app_logger.dart';
import '../../../services/api_service.dart';
import '../../../data/session_store.dart';
import '../../widgets/shimmer_card.dart';
import '../avaliacao/avaliacao_page.dart';

const Color _laranja = Color(0xFFF5841F);

class DetalhesPedidoPage extends StatefulWidget {
  final int idPedido;
  final String nomeEmpresa;

  const DetalhesPedidoPage({
    super.key,
    required this.idPedido,
    required this.nomeEmpresa,
  });

  @override
  State<DetalhesPedidoPage> createState() => _DetalhesPedidoPageState();
}

class _DetalhesPedidoPageState extends State<DetalhesPedidoPage> {
  Map<String, dynamic>? _pedido;
  bool _loading = true;
  String? _erro;
  // null = ainda carregando, true = já avaliou, false = não avaliou
  bool? _jaAvaliou;
  int?  _notaEmpresaDada;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() { _loading = true; _erro = null; });
    final data = await ApiService.getPedidoDetalhes(widget.idPedido);
    if (!mounted) return;
    if (data == null) {
      setState(() { _loading = false; _erro = 'Não foi possível carregar o pedido.'; });
      return;
    }

    setState(() { _pedido = data; _loading = false; });

    // Verifica avaliação apenas se entregue
    final idStatus = data['id_status'] is int
        ? data['id_status'] as int
        : int.tryParse(data['id_status']?.toString() ?? '') ?? 1;
    if (idStatus == 4) {
      final idUsuario = SessionStore.idUsuario;
      if (idUsuario != null) {
        final av = await ApiService.verificarAvaliacao(
          idPedido:  widget.idPedido,
          idUsuario: idUsuario,
        );
        if (mounted) {
          setState(() {
            _jaAvaliou = av?['avaliado'] == true;
            _notaEmpresaDada = av?['nota_empresa'] is int
                ? av!['nota_empresa'] as int
                : int.tryParse(av?['nota_empresa']?.toString() ?? '');
          });
        }
      }
    }
  }

  Color _corStatus(int id) {
    switch (id) {
      case 1: return Colors.grey;
      case 2: return Colors.orange;
      case 3: return Colors.blue;
      case 4: return const Color(0xFF4CAF50);
      case 5: return Colors.red;
      case 6: return Colors.purple;
      default: return Colors.grey;
    }
  }

  IconData _iconeStatus(int id) {
    switch (id) {
      case 1: return Icons.access_time;
      case 2: return Icons.local_fire_department;
      case 3: return Icons.delivery_dining;
      case 4: return Icons.check_circle;
      case 5: return Icons.cancel;
      case 6: return Icons.delivery_dining;
      default: return Icons.help_outline;
    }
  }

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
      ),
      body: _loading
          ? _buildSkeleton()
          : _erro != null
              ? _buildErro()
              : _buildConteudo(),
    );
  }

  Widget _buildSkeleton() => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBlock(height: 80, radius: 12),
            const SizedBox(height: 16),
            const ShimmerBlock(height: 20, width: 140),
            const SizedBox(height: 12),
            const ShimmerBlock(height: 120, radius: 12),
            const SizedBox(height: 16),
            const ShimmerBlock(height: 20, width: 100),
            const SizedBox(height: 12),
            const ShimmerBlock(height: 60, radius: 12),
            const SizedBox(height: 8),
            const ShimmerBlock(height: 60, radius: 12),
            const SizedBox(height: 16),
            const ShimmerBlock(height: 80, radius: 12),
          ],
        ),
      );

  Widget _buildErro() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(_erro!, style: const TextStyle(color: Colors.grey, fontSize: 15)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _laranja, foregroundColor: Colors.white),
            onPressed: _carregar,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ]),
      );

  Widget _buildConteudo() {
    final p = _pedido!;
    final idStatus = p['id_status'] is int
        ? p['id_status'] as int
        : int.tryParse(p['id_status']?.toString() ?? '') ?? 1;
    final status     = p['status']?.toString() ?? '';
    final totalRaw   = p['valor_total'];
    final total      = totalRaw is num
        ? totalRaw.toDouble()
        : double.tryParse(totalRaw?.toString() ?? '') ?? 0.0;
    final endereco   = p['endereco_entrega']?.toString() ?? '';
    final observacao = p['observacao']?.toString() ?? '';
    final criadoEm   = p['criado_em']?.toString() ?? '';
    final itens      = (p['itens'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final cor        = _corStatus(idStatus);
    final quasePronto = p['quase_pronto'] == true;

    // Formata data
    String dataFormatada = '';
    try {
      final dt = DateTime.parse(criadoEm).toLocal();
      dataFormatada =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
          '  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e, st) {
      AppLogger.e('DetalhesPedido', e, st);
      dataFormatada = criadoEm;
    }

    return RefreshIndicator(
      onRefresh: _carregar,
      color: _laranja,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Status ─────────────────────────────────────────────
          _card(
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconeStatus(idStatus), color: cor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(status,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: cor)),
                  if (dataFormatada.isNotEmpty)
                    Text(dataFormatada,
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ),
              if (quasePronto)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.notifications_active, color: Colors.white, size: 13),
                    SizedBox(width: 4),
                    Text('Quase Pronto!',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
            ]),
          ),
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

          // ── Endereço de entrega ────────────────────────────────
          if (endereco.isNotEmpty) ...[
            _card(
              child: _infoRow(
                icon: Icons.location_on_outlined,
                label: 'Endereço de entrega',
                value: endereco,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Itens do pedido ────────────────────────────────────
          _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Itens do pedido',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              if (itens.isEmpty)
                const Text('Nenhum item encontrado.',
                    style: TextStyle(color: Colors.grey))
              else
                ...itens.map((item) {
                  final nome = item['produto']?.toString() ?? '';
                  final qtd  = item['quantidade'] is int
                      ? item['quantidade'] as int
                      : int.tryParse(item['quantidade']?.toString() ?? '') ?? 1;
                  final precoRaw = item['preco_unit'];
                  final preco = precoRaw is num
                      ? precoRaw.toDouble()
                      : double.tryParse(precoRaw?.toString() ?? '') ?? 0.0;
                  final obs   = item['observacao']?.toString() ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _laranja.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text('$qtd',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _laranja,
                                    fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nome,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 14)),
                              if (obs.isNotEmpty)
                                Text(obs,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Text(
                          'R\$ ${(preco * qtd).toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    'R\$ ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF4CAF50)),
                  ),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Observação ─────────────────────────────────────────
          if (observacao.isNotEmpty) ...[
            _card(
              child: _infoRow(
                icon: Icons.notes_outlined,
                label: 'Observação',
                value: observacao,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Avaliação (só para pedidos entregues) ──────────────
          if (idStatus == 4) ...[
            _card(
              child: _jaAvaliou == null
                  // Carregando
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                            color: _laranja, strokeWidth: 2),
                      ))
                  : _jaAvaliou == true
                      // Já avaliou — mostra estrelas dadas
                      ? Row(children: [
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Você já avaliou este pedido',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                if (_notaEmpresaDada != null)
                                  Row(
                                    children: List.generate(5, (i) => Icon(
                                      i < _notaEmpresaDada!
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      color: i < _notaEmpresaDada!
                                          ? Colors.amber
                                          : Colors.grey.shade300,
                                      size: 20,
                                    )),
                                  ),
                              ],
                            ),
                          ),
                        ])
                      // Não avaliou — botão para avaliar
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () async {
                              final idEmpresa = p['id_empresa'] is int
                                  ? p['id_empresa'] as int
                                  : int.tryParse(
                                          p['id_empresa']?.toString() ?? '') ??
                                      0;
                              final idMotoboy = p['id_motoboy'] is int
                                  ? p['id_motoboy'] as int
                                  : int.tryParse(
                                      p['id_motoboy']?.toString() ?? '');
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AvaliacaoPage(
                                    idPedido:    widget.idPedido,
                                    idEmpresa:   idEmpresa,
                                    nomeEmpresa: widget.nomeEmpresa,
                                    idMotoboy:   idMotoboy,
                                    nomeMotoboy: p['motoboy_nome']?.toString(),
                                  ),
                                ),
                              );
                              _carregar(); // recarrega para mostrar nota
                            },
                            icon: const Icon(Icons.star_outline_rounded),
                            label: const Text('Avaliar pedido',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
    required String label,
    required String value,
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
