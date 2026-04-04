import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/cart/cart.dart';
import '../../core/theme/app_theme.dart';

// ============================================================
// TELA DE CHECKOUT — Finalização de Pedido
// ============================================================

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // --- Estado: forma de pagamento (0=Pix, 1=Crédito, 2=Dinheiro) ---
  int _formaPagamento = 0;

  // --- Estado: cupom ---
  final _cupomController = TextEditingController();
  bool _cupomAplicado = false;
  String _cupomCodigo = '';
  final double _descontoCupom = 10.00;

  // --- Estado: troco ---
  final _trocoController = TextEditingController();

  // --- Estado: observação ---
  final _obsController = TextEditingController();

  // --- Estado: loading do botão ---
  bool _carregando = false;

  // --- Endereço mockado ---
  bool _temEndereco = true;
  final String _endereco = 'Rua das Flores, 123';
  final String _complemento = 'Apto 42 — Centro, Mallet-PR';

  // --- Taxa de entrega ---
  final double _taxaEntrega = 5.00;

  @override
  void dispose() {
    _cupomController.dispose();
    _trocoController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  // Calcula o subtotal dos itens no carrinho
  double get _subtotal => Cart.instance.total;

  // Calcula o desconto (somente se cupom ativo)
  double get _desconto => _cupomAplicado ? _descontoCupom : 0.0;

  // Calcula o total final
  double get _total => (_subtotal + _taxaEntrega - _desconto).clamp(0, double.infinity);

  // Formata valor double para "R$ X,XX"
  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  // Verifica se o botão deve estar ativo
  bool get _podeFinalizar => _temEndereco && !_carregando && Cart.instance.totalItens > 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // Escuta mudanças no carrinho para recalcular totais
      animation: Cart.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildAppBar(),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _secaoEndereco(),
                const SizedBox(height: 16),
                _secaoItens(context),
                const SizedBox(height: 16),
                _secaoCupom(),
                const SizedBox(height: 16),
                _secaoPagamento(),
                const SizedBox(height: 16),
                _secaoObservacoes(),
                const SizedBox(height: 16),
                _secaoResumo(),
                const SizedBox(height: 16),
                _secaoTempo(),
                const SizedBox(height: 24),
              ],
            ),
          ),
          // Botão fixo no rodapé
          bottomNavigationBar: _buildBotaoFinalizar(context),
        );
      },
    );
  }

  // ===================== APP BAR =====================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Finalizar Pedido',
        style: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppColors.divider, height: 1),
      ),
    );
  }

  // ===================== SEÇÃO 1 — ENDEREÇO =====================
  Widget _secaoEndereco() {
    if (!_temEndereco) {
      // Card com borda tracejada para adicionar endereço
      return GestureDetector(
        onTap: () => setState(() => _temEndereco = true),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary,
              width: 1.5,
              style: BorderStyle.solid,
            ),
            boxShadow: _sombraCard,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_circle_outline, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Adicionar endereço de entrega',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _card(
      child: Row(
        children: [
          // Ícone de localização
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_on, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          // Endereço
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entregar em',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  _endereco,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _complemento,
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Botão alterar
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              'Alterar',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== SEÇÃO 2 — ITENS DO PEDIDO =====================
  Widget _secaoItens(BuildContext context) {
    final itens = Cart.instance.itens;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header da seção
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Itens do pedido',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  'Adicionar mais',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.divider, height: 16),

          // Lista de itens com Dismissible para remover
          if (itens.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Nenhum item no carrinho',
                  style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: itens.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: AppColors.divider, height: 16),
              itemBuilder: (context, i) {
                final item = itens[i];
                return Dismissible(
                  key: ValueKey(item.nome),
                  direction: DismissDirection.endToStart,
                  // Fundo vermelho com lixeira ao arrastar
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
                  ),
                  onDismissed: (_) {
                    // Remove todas as unidades do item
                    for (int q = item.quantidade; q > 0; q--) {
                      Cart.instance.remover(item.nome);
                    }
                  },
                  child: _itemPedido(item),
                );
              },
            ),
        ],
      ),
    );
  }

  // Widget de um item individual
  Widget _itemPedido(CartItem item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Imagem do produto
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            item.imgPath,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 60,
              height: 60,
              color: const Color(0xFFF0F0F0),
              child: const Icon(Icons.fastfood, color: AppColors.primary, size: 28),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Nome e restaurante
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.nome,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Smarty Entregas',
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Controle de quantidade
        Row(
          children: [
            // Botão diminuir
            _botaoQtdCheckout(
              icone: Icons.remove,
              laranja: false,
              onTap: () => Cart.instance.remover(item.nome),
            ),
            SizedBox(
              width: 32,
              child: Text(
                '${item.quantidade}',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // Botão aumentar
            _botaoQtdCheckout(
              icone: Icons.add,
              laranja: true,
              onTap: () => Cart.instance.adicionar(item.nome, item.preco, item.imgPath),
            ),
          ],
        ),
        const SizedBox(width: 10),

        // Preço do item
        Text(
          _fmt(item.subtotal),
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  // Botão circular +/- do checkout
  Widget _botaoQtdCheckout({
    required IconData icone,
    required bool laranja,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: laranja ? AppColors.primary : Colors.transparent,
          border: laranja ? null : Border.all(color: AppColors.divider, width: 1.5),
        ),
        child: Icon(icone, color: laranja ? Colors.white : AppColors.textSecondary, size: 16),
      ),
    );
  }

  // ===================== SEÇÃO 3 — CUPOM =====================
  Widget _secaoCupom() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campo de cupom
          Row(
            children: [
              const Icon(Icons.local_offer_outlined, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _cupomController,
                  enabled: !_cupomAplicado,
                  style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Código do cupom',
                    hintStyle:
                        GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              // Botão Aplicar
              GestureDetector(
                onTap: _cupomAplicado
                    ? null
                    : () {
                        final codigo = _cupomController.text.trim().toUpperCase();
                        if (codigo.isNotEmpty) {
                          setState(() {
                            _cupomAplicado = true;
                            _cupomCodigo = codigo;
                          });
                        }
                      },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _cupomAplicado ? AppColors.disabled : AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Aplicar',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Cupom aplicado: badge verde
          if (_cupomAplicado) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: Color(0xFF2E7D32), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cupom $_cupomCodigo aplicado — ${_fmt(_descontoCupom)} OFF',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF2E7D32)),
                    ),
                  ),
                  // Botão remover cupom
                  GestureDetector(
                    onTap: () => setState(() {
                      _cupomAplicado = false;
                      _cupomCodigo = '';
                      _cupomController.clear();
                    }),
                    child: const Icon(Icons.close,
                        color: Color(0xFF2E7D32), size: 18),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===================== SEÇÃO 4 — PAGAMENTO =====================
  Widget _secaoPagamento() {
    final metodos = [
      {'icone': Icons.pix, 'texto': 'Pix'},
      {'icone': Icons.credit_card, 'texto': 'Cartão de crédito'},
      {'icone': Icons.attach_money, 'texto': 'Dinheiro'},
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pagamento',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const Icon(Icons.edit_outlined,
                  color: AppColors.textSecondary, size: 18),
            ],
          ),
          const Divider(color: AppColors.divider, height: 20),

          // Opções de pagamento
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: metodos.length,
            separatorBuilder: (_, __) =>
                const Divider(color: AppColors.divider, height: 16),
            itemBuilder: (_, i) {
              final selecionado = _formaPagamento == i;
              return InkWell(
                onTap: () => setState(() => _formaPagamento = i),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      // Radio button customizado
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selecionado
                                ? AppColors.primary
                                : AppColors.divider,
                            width: 2,
                          ),
                        ),
                        child: selecionado
                            ? Center(
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      // Ícone do método
                      Icon(
                        metodos[i]['icone'] as IconData,
                        color: selecionado
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      // Nome do método
                      Text(
                        metodos[i]['texto'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: selecionado
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selecionado
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Campo de troco (apenas para dinheiro, índice 2)
          if (_formaPagamento == 2) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _trocoController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style:
                  GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                prefixText: 'R\$  ',
                prefixStyle: GoogleFonts.poppins(
                    fontSize: 14, color: AppColors.textSecondary),
                hintText: 'Troco para quanto?',
                hintStyle: GoogleFonts.poppins(
                    fontSize: 14, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.divider, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.divider, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===================== SEÇÃO 5 — OBSERVAÇÕES =====================
  Widget _secaoObservacoes() {
    return _card(
      child: TextField(
        controller: _obsController,
        maxLines: 3,
        maxLength: 200,
        style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText:
              'Alguma observação? (ex: sem cebola, portão azul...)',
          hintStyle:
              GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  // ===================== SEÇÃO 6 — RESUMO =====================
  Widget _secaoResumo() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo',
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
          const Divider(color: AppColors.divider, height: 20),

          // Subtotal
          _linhaResumo('Subtotal', _fmt(_subtotal)),
          const SizedBox(height: 8),

          // Taxa de entrega
          _linhaResumo(
            'Taxa de entrega',
            _taxaEntrega == 0 ? 'Grátis' : _fmt(_taxaEntrega),
            corValor:
                _taxaEntrega == 0 ? AppColors.success : AppColors.textPrimary,
          ),
          const SizedBox(height: 8),

          // Desconto (apenas se cupom aplicado)
          if (_cupomAplicado) ...[
            _linhaResumo(
              'Desconto',
              '− ${_fmt(_desconto)}',
              corValor: AppColors.success,
            ),
            const SizedBox(height: 8),
          ],

          // Divider tracejado
          _dividerTracejado(),
          const SizedBox(height: 8),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              Text(
                _fmt(_total),
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Linha de resumo reutilizável
  Widget _linhaResumo(String label, String valor,
      {Color corValor = AppColors.textPrimary}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary)),
        Text(valor,
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w500, color: corValor)),
      ],
    );
  }

  // Divider tracejado
  Widget _dividerTracejado() {
    return LayoutBuilder(
      builder: (_, constraints) {
        const dashW = 6.0;
        const gap = 4.0;
        final total = constraints.maxWidth;
        final count = (total / (dashW + gap)).floor();
        return Row(
          children: List.generate(
            count,
            (_) => Container(
              width: dashW,
              height: 1,
              margin: const EdgeInsets.only(right: gap),
              color: AppColors.divider,
            ),
          ),
        );
      },
    );
  }

  // ===================== SEÇÃO 7 — TEMPO ESTIMADO =====================
  Widget _secaoTempo() {
    return _card(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.access_time, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'Tempo estimado de entrega:',
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 6),
          Text(
            '30-45 min',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ===================== BOTÃO FIXO NO RODAPÉ =====================
  Widget _buildBotaoFinalizar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _podeFinalizar ? AppColors.primary : AppColors.disabled,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _podeFinalizar ? () => _finalizarPedido(context) : null,
          // Ícone ou spinner de loading
          icon: _carregando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.check_circle_outline, size: 20),
          label: Text(
            _carregando
                ? 'Processando...'
                : 'Confirmar Pedido — ${_fmt(_total)}',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // Lógica de finalizar pedido (simula processamento + dialog de confirmação)
  Future<void> _finalizarPedido(BuildContext _) async {
    setState(() => _carregando = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _carregando = false);

    // Dialog de confirmação — usa this.context (State) que é seguro após mounted
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícone animado de check
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: Color(0xFF2E7D32), size: 44),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pedido confirmado!',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Seu pedido #1234 foi enviado.\nAcompanhe pelo app.',
              style: GoogleFonts.poppins(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(context); // Fecha dialog
                  Navigator.pop(context); // Volta para home
                },
                child: Text(
                  'Acompanhar pedido',
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== HELPERS =====================

  // Card padrão reutilizável
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _sombraCard,
      ),
      child: child,
    );
  }

  // Sombra padrão dos cards
  static const List<BoxShadow> _sombraCard = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
}
