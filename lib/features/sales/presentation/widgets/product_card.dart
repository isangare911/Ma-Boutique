import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAdd;

  const ProductCard({
    super.key,
    required this.product,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = product.quantity == 0;
    final isLowStock =
        product.quantity > 0 && product.quantity <= product.alertThreshold;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          // Icône
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.greenLight(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: AppColors.green(context),
            ),
          ),
          const SizedBox(width: 12),

          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      AppFormatters.formatCurrency(product.sellingPrice),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.green(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isOutOfStock)
                      _buildBadge(
                          context, 'Rupture', AppColors.dangerTheme(context))
                    else if (isLowStock)
                      _buildBadge(context, 'Stock: ${product.quantity}',
                          AppColors.warningTheme(context))
                    else
                      _buildBadge(context, 'Stock: ${product.quantity}',
                          AppColors.successTheme(context)),
                  ],
                ),
              ],
            ),
          ),

          // Bouton Ajouter
          IconButton(
            onPressed: isOutOfStock ? null : onAdd,
            icon: const Icon(Icons.add_circle, size: 32),
            color: isOutOfStock
                ? AppColors.textSec(context)
                : AppColors.green(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
