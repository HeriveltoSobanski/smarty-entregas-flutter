import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/api_service.dart';
import '../../../data/session_store.dart';

const Color _laranja = Color(0xFFF5841F);

class NotificacoesPage extends StatefulWidget {
  const NotificacoesPage({super.key});

  @override
  State<NotificacoesPage> createState() => _NotificacoesPageState();
}

class _NotificacoesPageState extends State<NotificacoesPage> {
  List<Map<String, dynamic>> _notificacoes = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final id = SessionStore.idUsuario;
    if (id == null) { setState(() => _carregando = false); return; }
    final lista = await ApiService.getNotificacoes(id);
    if (!mounted) return;
    setState(() { _notificacoes = lista; _carregando = false; });
  }

  Future<void> _marcarTodasLidas() async {
    final id = SessionStore.idUsuario;
    if (id == null) return;
    await ApiService.marcarTodasNotificacoesLidas(id);
    setState(() {
      for (final n in _notificacoes) { n['lida'] = true; }
    });
  }

  Future<void> _marcarLida(Map<String, dynamic> notif) async {
    if (notif['lida'] == true) return;
    final idNotif = notif['id'] as int?;
    if (idNotif == null) return;
    await ApiService.marcarNotificacaoLida(idNotif);
    setState(() => notif['lida'] = true);
  }

  @override
  Widget build(BuildContext context) {
    final temNaoLidas = _notificacoes.any((n) => n['lida'] != true);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: _laranja,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Notificações',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (temNaoLidas)
            TextButton(
              onPressed: _marcarTodasLidas,
              child: Text('Ler todas',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: _laranja))
          : _notificacoes.isEmpty
              ? _buildVazio()
              : RefreshIndicator(
                  color: _laranja,
                  onRefresh: _carregar,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 14),
                    itemCount: _notificacoes.length,
                    itemBuilder: (_, i) =>
                        _NotifCard(
                          notif: _notificacoes[i],
                          onTap: () => _marcarLida(_notificacoes[i]),
                        ),
                  ),
                ),
    );
  }

  Widget _buildVazio() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Nenhuma notificação',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500)),
            const SizedBox(height: 6),
            Text('Você será avisado sobre\nstatus dos pedidos aqui.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
      );
}

// ── Card de notificação ──────────────────────────────────────────
class _NotifCard extends StatelessWidget {
  final Map<String, dynamic> notif;
  final VoidCallback onTap;

  const _NotifCard({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final lida     = notif['lida'] == true;
    final tipo     = notif['tipo']?.toString() ?? 'status_pedido';
    final titulo   = notif['titulo']?.toString() ?? '';
    final corpo    = notif['corpo']?.toString() ?? '';
    final horario  = _formatarHorario(notif['criado_em']?.toString());

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: lida ? Colors.white : _laranja.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: lida
              ? null
              : Border.all(color: _laranja.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícone
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: _corTipo(tipo).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconeTipo(tipo),
                    color: _corTipo(tipo), size: 20),
              ),
              const SizedBox(width: 12),
              // Texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(titulo,
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: lida
                                    ? FontWeight.w500
                                    : FontWeight.bold,
                                color: Colors.black87)),
                      ),
                      if (!lida)
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: _laranja,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ]),
                    const SizedBox(height: 3),
                    Text(corpo,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.4)),
                    const SizedBox(height: 6),
                    Text(horario,
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey.shade400)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _corTipo(String tipo) {
    switch (tipo) {
      case 'motoboy':   return Colors.blue;
      case 'promocao':  return Colors.green;
      default:          return _laranja;
    }
  }

  IconData _iconeTipo(String tipo) {
    switch (tipo) {
      case 'motoboy':   return Icons.delivery_dining;
      case 'promocao':  return Icons.local_offer_outlined;
      default:          return Icons.receipt_long_outlined;
    }
  }

  String _formatarHorario(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final agora = DateTime.now();
      final diff  = agora.difference(dt);
      if (diff.inMinutes < 1)  return 'Agora';
      if (diff.inMinutes < 60) return 'Há ${diff.inMinutes} min';
      if (diff.inHours   < 24) return 'Há ${diff.inHours}h';
      if (diff.inDays    < 7)  return 'Há ${diff.inDays} dias';
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}';
    } catch (_) {
      return '';
    }
  }
}
