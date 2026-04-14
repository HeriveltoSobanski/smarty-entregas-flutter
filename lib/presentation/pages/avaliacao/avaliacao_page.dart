import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../data/session_store.dart';

const Color _cor = Color(0xFFF5841F);

class AvaliacaoPage extends StatefulWidget {
  final int     idPedido;
  final int     idEmpresa;
  final String  nomeEmpresa;
  final int?    idMotoboy;
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
  // Notas
  int _notaEmpresa = 0;
  int _notaMotoboy = 0;

  // Critérios entregador
  bool _rapidez   = false;
  bool _educacao  = false;
  bool _cuidado   = false;

  // Critérios restaurante
  bool _sabor         = false;
  bool _embalagem     = false;
  bool _pedidoCorreto = false;

  // Comentários
  final _comentarioEmpresaCtrl  = TextEditingController();
  final _comentarioEntregaCtrl  = TextEditingController();

  bool _enviando = false;

  @override
  void dispose() {
    _comentarioEmpresaCtrl.dispose();
    _comentarioEntregaCtrl.dispose();
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
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _enviando = true);

    final erro = await ApiService.enviarAvaliacao(
      idPedido:         widget.idPedido,
      idUsuario:        SessionStore.idUsuario!,
      idEmpresa:        widget.idEmpresa,
      notaEmpresa:      _notaEmpresa,
      idMotoboy:        _temMotoboy ? widget.idMotoboy : null,
      notaMotoboy:      (_temMotoboy && _notaMotoboy > 0) ? _notaMotoboy : null,
      comentario:       _comentarioEmpresaCtrl.text.trim(),
      comentarioEntrega: _temMotoboy ? _comentarioEntregaCtrl.text.trim() : null,
      rapidez:          (_temMotoboy && _notaMotoboy > 0 && _rapidez)  ? true : null,
      educacao:         (_temMotoboy && _notaMotoboy > 0 && _educacao) ? true : null,
      cuidado:          (_temMotoboy && _notaMotoboy > 0 && _cuidado)  ? true : null,
      sabor:            (_notaEmpresa > 0 && _sabor)         ? true : null,
      embalagem:        (_notaEmpresa > 0 && _embalagem)     ? true : null,
      pedidoCorreto:    (_notaEmpresa > 0 && _pedidoCorreto) ? true : null,
    );

    if (!mounted) return;
    setState(() => _enviando = false);

    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro), backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            _card(
              child: Column(children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle,
                      color: Colors.green, size: 36),
                ),
                const SizedBox(height: 10),
                const Text('Pedido entregue!',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Como foi a sua experiência?',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600)),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Avaliação do restaurante ─────────────────────────
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _secaoTitulo(
                    Icons.store_outlined, _cor, widget.nomeEmpresa,
                    'Como você avalia o restaurante?'),
                  const SizedBox(height: 12),
                  _Estrelas(
                    valor: _notaEmpresa,
                    onChanged: (v) => setState(() => _notaEmpresa = v),
                  ),
                  // Critérios aparecem após selecionar nota
                  if (_notaEmpresa > 0) ...[
                    const SizedBox(height: 14),
                    const Text('O que você achou?',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 6,
                      children: [
                        _Chip('Sabor incrível', Icons.restaurant,
                            _sabor, (v) => setState(() => _sabor = v)),
                        _Chip('Embalagem boa', Icons.inventory_2_outlined,
                            _embalagem, (v) => setState(() => _embalagem = v)),
                        _Chip('Pedido correto', Icons.check_box_outlined,
                            _pedidoCorreto, (v) => setState(() => _pedidoCorreto = v)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _campoComentario(
                      controller: _comentarioEmpresaCtrl,
                      hint: 'Comentário sobre o restaurante (opcional)...',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Avaliação do entregador ──────────────────────────
            if (_temMotoboy)
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _secaoTitulo(
                      Icons.delivery_dining, Colors.blue,
                      widget.nomeMotoboy!,
                      'Como você avalia o entregador? (opcional)'),
                    const SizedBox(height: 12),
                    _Estrelas(
                      valor: _notaMotoboy,
                      onChanged: (v) => setState(() => _notaMotoboy = v),
                      cor: Colors.blue,
                    ),
                    if (_notaMotoboy > 0) ...[
                      const SizedBox(height: 14),
                      const Text('O que você achou?',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 6,
                        children: [
                          _Chip('Entrega rápida', Icons.speed,
                              _rapidez, (v) => setState(() => _rapidez = v),
                              corAtiva: Colors.blue),
                          _Chip('Muito educado', Icons.sentiment_satisfied_alt,
                              _educacao, (v) => setState(() => _educacao = v),
                              corAtiva: Colors.blue),
                          _Chip('Cuidou do pedido', Icons.inventory_outlined,
                              _cuidado, (v) => setState(() => _cuidado = v),
                              corAtiva: Colors.blue),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _campoComentario(
                        controller: _comentarioEntregaCtrl,
                        hint: 'Comentário sobre a entrega (opcional)...',
                      ),
                    ],
                  ],
                ),
              ),

            if (_temMotoboy) const SizedBox(height: 12),

            // ── Botões ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                onPressed: _enviando ? null : _enviar,
                child: _enviando
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(Colors.white)))
                    : const Text('Enviar avaliação',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil('/home', (_) => false),
                child: Text('Pular por agora',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _secaoTitulo(
      IconData icon, Color cor, String nome, String subtitulo) {
    return Row(children: [
      Icon(icon, color: cor, size: 20),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nome,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          Text(subtitulo,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ]),
      ),
    ]);
  }

  Widget _campoComentario({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: 2,
      maxLength: 200,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        counterStyle: TextStyle(color: Colors.grey.shade400, fontSize: 11),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _cor, width: 1.5)),
        contentPadding: const EdgeInsets.all(12),
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
                offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      );
}

// ── Chip de critério ─────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String   label;
  final IconData icon;
  final bool     selecionado;
  final ValueChanged<bool> onChanged;
  final Color    corAtiva;

  const _Chip(this.label, this.icon, this.selecionado, this.onChanged,
      {this.corAtiva = _cor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!selecionado),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selecionado
              ? corAtiva.withValues(alpha: 0.12)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selecionado ? corAtiva : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 14,
              color: selecionado ? corAtiva : Colors.grey.shade500),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: selecionado
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: selecionado ? corAtiva : Colors.grey.shade600)),
        ]),
      ),
    );
  }
}

// ── Estrelas ─────────────────────────────────────────────────────
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Icon(
                key: ValueKey(estrela <= valor),
                estrela <= valor
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: estrela <= valor ? Colors.amber : Colors.grey.shade300,
                size: 38,
              ),
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
