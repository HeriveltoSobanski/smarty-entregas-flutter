import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/cart/cart.dart';
import '../../core/theme/app_theme.dart';

class FloatingCart extends StatelessWidget {
  const FloatingCart({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
    if (cart.totalItens == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/checkout'),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: Text(
                  '${cart.totalItens}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              cart.totalFormatado,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
