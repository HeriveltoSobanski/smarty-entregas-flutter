import 'dart:async';
import 'package:flutter/material.dart';

import '../../../data/session_store.dart';
import '../../../services/api_service.dart';
import '../mapa_entrega/mapa_entrega_page.dart';

const Color _cor = Color(0xFFFFA726);

// =============================================================
// PÁGINA PRINCIPAL DO MOTOBOY
// =============================================================
class PaginaMotoboy extends StatefulWidget {
  const PaginaMotoboy({super.key});

  @override
  State<PaginaMotoboy> createState() => _PaginaMotoboyState();
}

class _PaginaMotoboyState extends State<PaginaMotoboy> {
  int _aba = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _cor,
        elevation: 0,
        title: Text(
          SessionStore.nome ?? 'Motoboy',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () {
            SessionStore.clear();
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/login', (_) => false);
          },
        ),
      ),
      body: IndexedStack(
        index: _aba,
        children: const [
          _TabEntregas(),
          _TabRelatorio(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _aba,
        onTap: (i) => setState(() => _aba = i),
        selectedItemColor: _cor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.delivery_dining), label: 'Entregas'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart), label: 'Relatório'),
        ],
      ),
    );
  }
}

// =============================================================
// TAB: ENTREGAS
// Toggle disponível/offline + Em Espera + Em Rota
// =============================================================
class _TabEntregas extends StatefulWidget {
  const _TabEntregas();

  @override
  State<_TabEntregas> createState() => _TabEntregasState();
}

class _TabEntregasState extends State<_TabEntregas> {
  List<Map<String, dynamic>> _emEspera = []; // status 6 — aguardando motoboy
  List<Map<String, dynamic>> _emRota   = []; // status 3 — a caminho
  bool   _carregando  = true;
  String _meuStatus   = 'offline'; // 'offline' | 'disponivel' | 'em_rota'
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _carregar();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _carregar(silencioso: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _carregando = true);
    final id = SessionStore.idUsuario;
    final results = await Future.wait([
      ApiService.getEntregasDisponiveis(),
      if (id != null) ApiService.getEntregasEmRota(id),
    ]);
    if (mounted) {
      setState(() {
        _emEspera   = results[0];
        _emRota     = results.length > 1 ? results[1] : [];
        if (!silencioso) _carregando = false;
      });
    }
    if (silencioso && mounted) setState(() => _carregando = false);
  }

  Future<void> _toggleDisponivel(bool valor) async {
    final id = SessionStore.idUsuario;
    if (id == null) return;
    final novoStatus = valor ? 'disponivel' : 'offline';
    await ApiService.atualizarMeuStatusMotoboy(id, novoStatus);
    setState(() => _meuStatus = novoStatus);
  }

  Future<void> _aceitar(Map<String, dynamic> pedido) async {
    final id = SessionStore.idUsuario;
    if (id == null) return;
    final idPedido = pedido['id_pedido'] is int
        ? pedido['id_pedido'] as int
        : int.parse(pedido['id_pedido'].toString());
    final erro = await ApiService.aceitarEntrega(
        idPedido: idPedido, idMotoboy: id);
    if (!mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(erro), backgroundColor: Colors.red));
      return;
    }
    await ApiService.atualizarMeuStatusMotoboy(id, 'em_rota');
    setState(() => _meuStatus = 'em_rota');
    _carregar();
    // Abre o mapa com a rota
    _abrirMapa(pedido);
  }

  void _abrirMapa(Map<String, dynamic> pedido) {
    final idPedido = pedido['id_pedido'] is int
        ? pedido['id_pedido'] as int
        : int.tryParse(pedido['id_pedido']?.toString() ?? '') ?? 0;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapaEntregaPage(
          enderecoOrigem:  pedido['empresa_endereco']?.toString() ?? '',
          enderecoDestino: pedido['endereco_entrega']?.toString() ?? '',
          nomeEmpresa:     pedido['empresa']?.toString() ?? '',
          idPedido:        idPedido,
        ),
      ),
    );
  }

  Future<void> _atualizarStatus(int idPedido, int idStatus) async {
    await ApiService.atualizarStatusMotoboy(idPedido, idStatus);
    // Se entregue ou cancelado e não tem mais em rota, volta para disponivel
    if (idStatus == 4 || idStatus == 5) {
      final id = SessionStore.idUsuario;
      if (id != null && _emRota.length <= 1) {
        await ApiService.atualizarMeuStatusMotoboy(id, 'disponivel');
        setState(() => _meuStatus = 'disponivel');
      }
    }
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator(color: _cor));
    }

    final disponivel = _meuStatus == 'disponivel' || _meuStatus == 'em_rota';

    return RefreshIndicator(
      onRefresh: _carregar,
      color: _cor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Toggle disponível ───────────────────────────────
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _meuStatus == 'em_rota'
                          ? Colors.blue
                          : disponivel
                              ? Colors.green
                              : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _meuStatus == 'em_rota'
                              ? 'Em Rota'
                              : disponivel
                                  ? 'Disponível'
                                  : 'Offline',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          _meuStatus == 'em_rota'
                              ? 'Você está em uma entrega'
                              : disponivel
                                  ? 'Você aparece para receber chamados'
                                  : 'Você não receberá novos pedidos',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: disponivel,
                    onChanged: _meuStatus == 'em_rota' ? null : _toggleDisponivel,
                    activeThumbColor: _cor,
                    activeTrackColor: _cor.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Em Rota (minhas entregas ativas) ─────────────────
          if (_emRota.isNotEmpty) ...[
            _secaoTitulo('Em Rota', Icons.directions_bike, Colors.blue),
            const SizedBox(height: 8),
            ..._emRota.map((p) => _CardEntregaAtiva(
                  pedido: p,
                  onAtualizar: _atualizarStatus,
                  onVerMapa: () => _abrirMapa(p),
                )),
            const SizedBox(height: 16),
          ],

          // ── Em Espera (aguardando motoboy) ───────────────────
          _secaoTitulo(
            'Em Espera${_emEspera.isNotEmpty ? ' (${_emEspera.length})' : ''}',
            Icons.inbox,
            _cor,
          ),
          const SizedBox(height: 8),
          if (!disponivel)
            _emptyState('Fique disponível para receber chamados de entrega.')
          else if (_emEspera.isEmpty)
            _emptyState('Nenhuma entrega aguardando motoboy.\nPuxe para atualizar.')
          else
            ..._emEspera.map((p) => _CardEntregaDisponivel(
                  pedido: p,
                  onAceitar: () => _aceitar(p),
                )),
        ],
      ),
    );
  }

  Widget _secaoTitulo(String texto, IconData icon, Color cor) => Row(
        children: [
          Icon(icon, color: cor, size: 18),
          const SizedBox(width: 6),
          Text(texto,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: cor)),
        ],
      );

  Widget _emptyState(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(msg,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        ),
      );
}

// ── Card: entrega disponível ─────────────────────────────────
class _CardEntregaDisponivel extends StatelessWidget {
  final Map<String, dynamic> pedido;
  final VoidCallback onAceitar;
  const _CardEntregaDisponivel(
      {required this.pedido, required this.onAceitar});

  @override
  Widget build(BuildContext context) {
    final valor = double.tryParse(
            pedido['valor_total']?.toString() ?? '0') ??
        0;
    final endereco = pedido['endereco_entrega']?.toString() ?? '';
    final itens    = pedido['itens']?.toString() ?? '';
    final empresa  = pedido['empresa']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pedido #${pedido['id_pedido']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _cor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('R\$ ${valor.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: _cor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _linha(Icons.store_outlined, empresa),
            if (itens.isNotEmpty) _linha(Icons.fastfood_outlined, itens),
            if (endereco.isNotEmpty)
              _linha(Icons.location_on_outlined, endereco),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onAceitar,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Aceitar entrega',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linha(IconData icon, String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 5),
            Expanded(
                child: Text(texto,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[700]))),
          ],
        ),
      );
}

// ── Card: entrega ativa (em andamento) ──────────────────────
class _CardEntregaAtiva extends StatelessWidget {
  final Map<String, dynamic> pedido;
  final Future<void> Function(int idPedido, int idStatus) onAtualizar;
  final VoidCallback onVerMapa;
  const _CardEntregaAtiva(
      {required this.pedido, required this.onAtualizar, required this.onVerMapa});

  @override
  Widget build(BuildContext context) {
    final idPedido = pedido['id_pedido'] is int
        ? pedido['id_pedido'] as int
        : int.tryParse(pedido['id_pedido']?.toString() ?? '') ?? 0;
    final idStatus = pedido['id_status'] is int
        ? pedido['id_status'] as int
        : int.tryParse(pedido['id_status']?.toString() ?? '') ?? 3;
    final valor    = double.tryParse(
            pedido['valor_total']?.toString() ?? '0') ??
        0;
    final endereco = pedido['endereco_entrega']?.toString() ?? '';
    final empresa  = pedido['empresa']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pedido #$idPedido',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(pedido['status']?.toString() ?? '',
                      style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _linha(Icons.store_outlined, empresa),
            if (endereco.isNotEmpty)
              _linha(Icons.location_on_outlined, endereco),
            _linha(Icons.attach_money,
                'Valor: R\$ ${valor.toStringAsFixed(2)}  •  Taxa: R\$ 5,00'),
            const SizedBox(height: 10),
            // Botão Ver Mapa (linha própria)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue[700],
                  side: BorderSide(color: Colors.blue[700]!),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onVerMapa,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Ver Mapa / Navegar'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (idStatus == 3)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => onAtualizar(idPedido, 4),
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text('Entregue',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => onAtualizar(idPedido, 5),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _linha(IconData icon, String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 5),
            Expanded(
                child: Text(texto,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[700]))),
          ],
        ),
      );
}

// =============================================================
// TAB: RELATÓRIO DE GANHOS
// =============================================================
class _TabRelatorio extends StatefulWidget {
  const _TabRelatorio();

  @override
  State<_TabRelatorio> createState() => _TabRelatorioState();
}

class _TabRelatorioState extends State<_TabRelatorio> {
  List<Map<String, dynamic>> _pedidos        = [];
  int    _totalEntregas  = 0;
  double _totalGanho     = 0;
  double _taxaPorEntrega = 5.0;
  bool   _carregando     = true;

  DateTime? _inicio;
  DateTime? _fim;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final id = SessionStore.idUsuario;
    if (id == null) { setState(() => _carregando = false); return; }

    final ini = _inicio != null
        ? '${_inicio!.year.toString().padLeft(4,'0')}-${_inicio!.month.toString().padLeft(2,'0')}-${_inicio!.day.toString().padLeft(2,'0')}'
        : null;
    final fim = _fim != null
        ? '${_fim!.year.toString().padLeft(4,'0')}-${_fim!.month.toString().padLeft(2,'0')}-${_fim!.day.toString().padLeft(2,'0')}'
        : null;

    final data = await ApiService.getHistoricoMotoboy(id,
        inicio: ini, fim: fim);

    if (mounted) {
      setState(() {
        _pedidos       = List<Map<String, dynamic>>.from(data['pedidos'] ?? []);
        _totalEntregas = data['total_entregas'] is int
            ? data['total_entregas'] as int
            : int.tryParse(data['total_entregas']?.toString() ?? '0') ?? 0;
        _totalGanho    = double.tryParse(
                data['total_ganho']?.toString() ?? '0') ??
            0;
        _taxaPorEntrega = double.tryParse(
                data['taxa_por_entrega']?.toString() ?? '5') ??
            5.0;
        _carregando = false;
      });
    }
  }

  Future<void> _selecionarPeriodo() async {
    final agora = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate:  agora,
      initialDateRange: _inicio != null && _fim != null
          ? DateTimeRange(start: _inicio!, end: _fim!)
          : null,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _cor),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() { _inicio = range.start; _fim = range.end; });
      _carregar();
    }
  }

  String _fmtData(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _carregar,
      color: _cor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Filtro de período ────────────────────────────────
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.calendar_today, color: _cor),
              title: Text(
                _inicio != null && _fim != null
                    ? '${_fmtData(_inicio!)} → ${_fmtData(_fim!)}'
                    : 'Filtrar por período',
                style: const TextStyle(fontSize: 14),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_inicio != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18,
                          color: Colors.grey),
                      onPressed: () {
                        setState(() { _inicio = null; _fim = null; });
                        _carregar();
                      },
                    ),
                  const Icon(Icons.chevron_right, color: _cor),
                ],
              ),
              onTap: _selecionarPeriodo,
            ),
          ),
          const SizedBox(height: 16),

          // ── Cards de resumo ──────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _cardResumo(
                  icon:  Icons.delivery_dining,
                  label: 'Entregas',
                  valor: '$_totalEntregas',
                  cor:   _cor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _cardResumo(
                  icon:  Icons.attach_money,
                  label: 'Total ganho',
                  valor: 'R\$ ${_totalGanho.toStringAsFixed(2)}',
                  cor:   Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.grey),
              title: Text(
                  'Taxa por entrega: R\$ ${_taxaPorEntrega.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(height: 16),

          // ── Lista de entregas concluídas ─────────────────────
          if (_carregando)
            const Center(child: CircularProgressIndicator(color: _cor))
          else if (_pedidos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Nenhuma entrega concluída\nno período selecionado.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ),
            )
          else ...[
            const Text('Histórico de entregas',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ..._pedidos.map((p) => _CardHistorico(pedido: p,
                taxaPorEntrega: _taxaPorEntrega)),
          ],
        ],
      ),
    );
  }

  Widget _cardResumo({
    required IconData icon,
    required String   label,
    required String   valor,
    required Color    cor,
  }) =>
      Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: cor, size: 28),
              const SizedBox(height: 6),
              Text(valor,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: cor)),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      );
}

class _CardHistorico extends StatelessWidget {
  final Map<String, dynamic> pedido;
  final double taxaPorEntrega;
  const _CardHistorico(
      {required this.pedido, required this.taxaPorEntrega});

  @override
  Widget build(BuildContext context) {
    final valor   = double.tryParse(
            pedido['valor_total']?.toString() ?? '0') ??
        0;
    final empresa = pedido['empresa']?.toString() ?? '';
    final itens   = pedido['itens']?.toString() ?? '';
    final data    = pedido['criado_em']?.toString() ?? '';
    final dataFmt = data.length >= 16 ? data.substring(0, 16) : data;
    final endereco = pedido['endereco_entrega']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pedido #${pedido['id_pedido']}  •  $empresa',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                if (itens.isNotEmpty)
                  Text(itens,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis),
                if (endereco.isNotEmpty)
                  Text(endereco,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis),
                Text(dataFmt,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[400])),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('R\$ ${taxaPorEntrega.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 15)),
              Text('de R\$ ${valor.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }
}
