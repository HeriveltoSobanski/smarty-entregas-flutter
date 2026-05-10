import 'package:flutter/material.dart';
import '../../../core/utils/app_logger.dart';
import '../../../services/api_service.dart';

const Color _laranja = Color(0xFFF5841F);

const _motivos = [
  'Pedido duplicado',
  'Mudei de ideia',
  'Tempo de espera muito longo',
  'Erro nos itens do pedido',
  'Outro motivo',
];

class CancelarPedidoPage extends StatefulWidget {
  final int idPedido;
  final String nomeEmpresa;
  final double total;

  const CancelarPedidoPage({
    super.key,
    required this.idPedido,
    required this.nomeEmpresa,
    required this.total,
  });

  @override
  State<CancelarPedidoPage> createState() => _CancelarPedidoPageState();
}

class _CancelarPedidoPageState extends State<CancelarPedidoPage> {
  int? _motivoIndex;
  bool _cancelando = false;

  Future<void> _confirmar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_outlined,
                  color: Colors.red, size: 38),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cancelar pedido?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Esta ação não pode ser desfeita. O restaurante será notificado.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sim, cancelar',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Manter pedido',
                  style: TextStyle(color: Colors.grey.shade600)),
            ),
          ],
        ),
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _cancelando = true);

    try {
      await ApiService.atualizarStatusPedido(widget.idPedido, 5);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido cancelado com sucesso.'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e, st) {
      AppLogger.e('CancelarPedido', e, st);
      if (!mounted) return;
      setState(() => _cancelando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Não foi possível cancelar. Tente novamente ou entre em contato com o suporte.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        title: Text('Cancelar pedido #${widget.idPedido}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Aviso ─────────────────────────────────────────────
          _card(
            cor: Colors.orange.shade50,
            borda: Colors.orange.shade200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    color: Colors.orange.shade700, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'O cancelamento só é permitido enquanto o restaurante ainda não começou a preparar seu pedido.',
                    style: TextStyle(
                        fontSize: 13, color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Resumo do pedido ───────────────────────────────────
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Resumo do pedido',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                _infoRow(
                    icon: Icons.store_outlined,
                    label: 'Restaurante',
                    value: widget.nomeEmpresa),
                const SizedBox(height: 8),
                _infoRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'Total',
                    value:
                        'R\$ ${widget.total.toStringAsFixed(2).replaceAll('.', ',')}'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Motivo ─────────────────────────────────────────────
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Motivo do cancelamento',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text('Selecione um motivo para prosseguir',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                RadioGroup<int>(
                  groupValue: _motivoIndex,
                  onChanged: (v) => setState(() => _motivoIndex = v),
                  child: Column(
                    children: _motivos.asMap().entries.map((e) => RadioListTile<int>(
                          value: e.key,
                          title: Text(e.value,
                              style: const TextStyle(fontSize: 14)),
                          activeColor: Colors.red,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        )).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Botão cancelar ─────────────────────────────────────
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _motivoIndex == null ? Colors.grey.shade300 : Colors.red,
                foregroundColor: _motivoIndex == null
                    ? Colors.grey.shade500
                    : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: _motivoIndex == null ? 0 : 2,
              ),
              onPressed:
                  (_cancelando || _motivoIndex == null) ? null : _confirmar,
              icon: _cancelando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cancel_outlined),
              label: Text(
                _cancelando ? 'Cancelando...' : 'Cancelar pedido',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Botão manter ───────────────────────────────────────
          SizedBox(
            height: 50,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _laranja,
                side: BorderSide(color: _laranja),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed:
                  _cancelando ? null : () => Navigator.of(context).pop(false),
              child: const Text('Manter pedido',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _card({required Widget child, Color? cor, Color? borda}) => Container(
        width: double.infinity,
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

  Widget _infoRow(
          {required IconData icon,
          required String label,
          required String value}) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: _laranja),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]);
}
