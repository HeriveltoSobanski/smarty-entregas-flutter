import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/cart/cart.dart';
import '../../core/theme/app_theme.dart';

// Rastreia qual produto está com o seletor aberto (apenas um por vez)
final _produtoSelecionado = ValueNotifier<String?>(null);

class ProductCard extends StatelessWidget {
  final String nome;
  final String preco;
  final String imgPath;

  // Informações extras (opcionais) para visual mais rico
  final String? restaurante;
  final double? nota;
  final String? tempoEntrega;
  final bool entregaGratis;

  const ProductCard({
    super.key,
    required this.nome,
    required this.preco,
    required this.imgPath,
    this.restaurante,
    this.nota,
    this.tempoEntrega,
    this.entregaGratis = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: _produtoSelecionado,
      builder: (context, selecionado, _) {
        final mostrarControles = selecionado == nome;

        return AnimatedBuilder(
          animation: Cart.instance,
          builder: (context, _) {
            final qty = Cart.instance.quantidadeDe(nome);

            return GestureDetector(
              onTap: () => _produtoSelecionado.value =
                  mostrarControles ? null : nome,
              child: Container(
                width: 150,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Imagem com badge opcional
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                          child: Image.asset(
                            imgPath,
                            height: 100,
                            width: 150,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 100,
                              width: 150,
                              color: const Color(0xFFF0F0F0),
                              child: const Icon(Icons.fastfood,
                                  color: AppColors.primary, size: 38),
                            ),
                          ),
                        ),
                        // Badge "Entrega grátis"
                        if (entregaGratis)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Entrega grátis',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        // Badge de quantidade no carrinho
                        if (qty > 0)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$qty',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nome do produto
                          Text(
                            nome,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // Nome do restaurante (se fornecido)
                          if (restaurante != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              restaurante!,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],

                          // Avaliação + tempo de entrega
                          if (nota != null || tempoEntrega != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (nota != null) ...[
                                  const Icon(Icons.star,
                                      color: Color(0xFFFFC107), size: 12),
                                  const SizedBox(width: 2),
                                  Text(
                                    nota!.toStringAsFixed(1),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                                if (nota != null && tempoEntrega != null)
                                  Text(
                                    ' • ',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                if (tempoEntrega != null) ...[
                                  const Icon(Icons.access_time,
                                      color: AppColors.textSecondary, size: 11),
                                  const SizedBox(width: 2),
                                  Text(
                                    tempoEntrega!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],

                          const SizedBox(height: 4),

                          // Preço
                          Text(
                            preco,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Controles de quantidade
                          if (mostrarControles)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _BotaoQtd(
                                  icon: Icons.remove,
                                  onTap: qty > 0
                                      ? () {
                                          Cart.instance.remover(nome);
                                          if (qty == 1) {
                                            _produtoSelecionado.value = null;
                                          }
                                        }
                                      : null,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  child: Text(
                                    '$qty',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                _BotaoQtd(
                                  icon: Icons.add,
                                  onTap: () => Cart.instance
                                      .adicionar(nome, preco, imgPath),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _BotaoQtd extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _BotaoQtd({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: disabled ? AppColors.divider : AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
