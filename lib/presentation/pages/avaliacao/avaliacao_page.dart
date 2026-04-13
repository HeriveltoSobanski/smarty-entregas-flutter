import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../data/session_store.dart';

const Color _cor = Color(0xFFF5841F);

class AvaliacaoPage extends StatefulWidget {
  final int    idPedido;
  final int    idEmpresa;
  final String nomeEmpresa;
  final int?   idMotoboy;
  final String? nomeMotoboy;

  const AvaliacaoPage({
    super.key,
    required this.idPedido,
    required this.idEmpresa,
    required this.nomeEmpresa,
    this.idMotoboy,
    this.nomeMotoboy,
  });

  @override
  State<AvaliacaoPage> createState() => _AvaliacaoPageState();
}

class _AvaliacaoPageState extends State<AvaliacaoPage> {
  int  _notaEmpresa  = 0;
  int  _notaMotoboy  = 0;
  final _comentarioCtrl = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  bool get _temMotoboy =>
      widget.idMotoboy != null &&
      widget.nomeMotoboy != null &&
      widget.nomeMotoboy!.isNotEmpty;

  Future<void> _enviar() async {
    if (_notaEmpresa == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avalie o restaurante para continuar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _enviando = true);

    final erro = await ApiService.enviarAvaliacao(
      idPedido:    widget.idPedido,
      idUsuario:   SessionStore.idUsuario!,
      idEmpresa:   widget.idEmpresa,
      notaEmpresa: _notaEmpresa,
      idMotoboy:   _temMotoboy ? widget.idMotoboy : null,
      notaMotoboy: (_temMotoboy && _notaMotoboy > 0) ? _notaMotoboy : null,
      comentario:  _comentarioCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _enviando = false);

    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro), backgroundColor: Colors.red),
      );
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _cor,
        foregroundColor: Colors.white,
        title: const Text('Avaliar pedido',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle,
                      color: Colors.green, size: 40),
                ),
                const SizedBox(height: 12),
                const Text('Pedido entregue!',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Como foi a sua experiência?',
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade600)),
              ]),
            ),
            const SizedBox(height: 28),

            // Avaliação da empresa
            _secaoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.store_outlined, color: _cor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(widget.nomeEmpresa,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text('Como você avalia o restaurante?',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(height: 12),
                  _Estrelas(
                    valor: _notaEmpresa,
                    onChanged: (v) => setState(() => _notaEmpresa = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Avaliação do motoboy (se houver)
            if (_temMotoboy) ...[
              _secaoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.delivery_dining,
                          color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(widget.nomeMotoboy!,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text('Como você avalia o entregador? (opcional)',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(height: 12),
                    _Estrelas(
                      valor: _notaMotoboy,
                      onChanged: (v) => setState(() => _notaMotoboy = v),
                      cor: Colors.blue,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Comentário
            _secaoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.comment_outlined,
                        color: Colors.grey.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text('Comentário (opcional)',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.grey.shade700)),
                  ]),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _comentarioCtrl,
                    maxLines: 3,
                    maxLength: 300,
                    decoration: InputDecoration(
                      hintText: 'Conte como foi o pedido...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: _cor, width: 1.5)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Botões
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _enviando ? null : _enviar,
                child: _enviando
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white)))
                    : const Text('Enviar avaliação',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil('/home', (_) => false),
                child: Text('Pular por agora',
                    style: TextStyle(color: Colors.grey.shade500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secaoCard({required Widget child}) => Container(
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
}

// ── Widget de estrelas ───────────────────────────────────────────
class _Estrelas extends StatelessWidget {
  final int valor;
  final ValueChanged<int> onChanged;
  final Color cor;

  const _Estrelas({
    required this.valor,
    required this.onChanged,
    this.cor = _cor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final estrela = i + 1;
        return GestureDetector(
          onTap: () => onChanged(estrela),
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(
              estrela <= valor ? Icons.star_rounded : Icons.star_outline_rounded,
              color: estrela <= valor ? Colors.amber : Colors.grey.shade300,
              size: 36,
            ),
          ),
        );
      }),
    );
  }
}

// ── Widget público reutilizável para exibir nota ─────────────────
class NotaEstrelas extends StatelessWidget {
  final double nota;
  final int    total;
  final double tamanho;

  const NotaEstrelas({
    super.key,
    required this.nota,
    required this.total,
    this.tamanho = 14,
  });

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, color: Colors.amber, size: tamanho + 2),
        const SizedBox(width: 3),
        Text(
          nota.toStringAsFixed(1),
          style: TextStyle(
              fontSize: tamanho,
              fontWeight: FontWeight.bold,
              color: Colors.black87),
        ),
        const SizedBox(width: 3),
        Text(
          '($total)',
          style: TextStyle(fontSize: tamanho - 1, color: Colors.grey),
        ),
      ],
    );
  }
}
