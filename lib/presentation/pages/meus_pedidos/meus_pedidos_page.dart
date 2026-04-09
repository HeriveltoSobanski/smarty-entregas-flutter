import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../data/session_store.dart';

const Color _laranja = Color(0xFFF5841F);

class MeusPedidosPage extends StatefulWidget {
  const MeusPedidosPage({super.key});

  @override
  State<MeusPedidosPage> createState() => _MeusPedidosPageState();
}

class _MeusPedidosPageState extends State<MeusPedidosPage> {
  List<Map<String, dynamic>> _pedidos = [];
  bool _loading = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() { _loading = true; _erro = null; });
    final idUsuario = SessionStore.idUsuario;
    if (idUsuario == null) {
      setState(() { _loading = false; _erro = 'Usuário não autenticado.'; });
      return;
    }
    final lista = await ApiService.getPedidosByCliente(idUsuario);
    if (mounted) setState(() { _pedidos = lista; _loading = false; });
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
        elevation: 0,
        title: const Text('Meus Pedidos',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _carregar,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _laranja))
          : _erro != null
              ? Center(child: Text(_erro!, style: const TextStyle(color: Colors.red)))
              : _pedidos.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('Nenhum pedido ainda',
                            style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _carregar,
                      color: _laranja,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _pedidos.length,
                        itemBuilder: (_, i) {
                          final p = _pedidos[i];
                          final idStatus = p['id_status'] is int
                              ? p['id_status'] as int
                              : int.tryParse(p['id_status']?.toString() ?? '') ?? 1;
                          final status = p['status']?.toString() ?? '';
                          final empresa = p['empresa']?.toString() ?? '';
                          final totalRaw = p['valor_total'];
                          final total = totalRaw is num
                              ? totalRaw.toDouble()
                              : double.tryParse(totalRaw?.toString() ?? '') ?? 0.0;
                          final cor = _corStatus(idStatus);
                          final quasePronto = p['quase_pronto'] == true;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: cor.withValues(alpha: 0.1),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                ),
                                child: Row(children: [
                                  Icon(_iconeStatus(idStatus), color: cor, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(status,
                                      style: TextStyle(color: cor, fontWeight: FontWeight.bold))),
                                  if (quasePronto)
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.deepOrange,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(Icons.notifications_active, color: Colors.white, size: 12),
                                        SizedBox(width: 3),
                                        Text('Quase Pronto!', style: TextStyle(
                                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ]),
                                    ),
                                  Text('#${p['id_pedido']}',
                                      style: TextStyle(color: cor, fontWeight: FontWeight.bold)),
                                ]),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(children: [
                                      const Icon(Icons.store, size: 18, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(empresa,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    ]),
                                    Text('R\$ ${total.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Color(0xFF4CAF50))),
                                  ],
                                ),
                              ),
                            ]),
                          );
                        },
                      ),
                    ),
    );
  }
}
