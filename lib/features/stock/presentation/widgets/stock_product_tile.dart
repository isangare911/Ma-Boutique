import 'package:flutter/material.dart';

import '../../../../core/permissions/permission_guard.dart';
import '../../../../core/permissions/permissions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/product.dart';

class StockProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAddStock;

  const StockProductTile({
    super.key,
    required this.product,
    required this.onTap,
    required this.onAddStock,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = product.quantity == 0;
    final isLowStock =
        product.quantity > 0 && product.quantity <= product.alertThreshold;

    // 🔒 Le tap n'est actif que si l'utilisateur peut modifier le stock
    final canEdit = Permissions.can(Permission.editStock);

    return GestureDetector(
      onTap: canEdit ? onTap : null,
      child: Container(
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
                  Text(
                    'Prix: ${AppFormatters.formatCurrency(product.sellingPrice)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSec(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildStockBadge(context, isOutOfStock, isLowStock),
                ],
              ),
            ),

            // 🔒 Bouton "Ajouter au stock" — uniquement si editStock
            PermissionGuard(
              permission: Permission.editStock,
              child: IconButton(
                onPressed: onAddStock,
                icon: const Icon(Icons.add_circle_outline, size: 28),
                color: AppColors.green(context),
                tooltip: 'Ajouter au stock',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockBadge(
      BuildContext context, bool isOutOfStock, bool isLowStock) {
    Color color;
    String text;
    IconData icon;

    if (isOutOfStock) {
      color = AppColors.dangerTheme(context);
      text = 'Rupture';
      icon = Icons.cancel_outlined;
    } else if (isLowStock) {
      color = AppColors.warningTheme(context);
      text = 'Stock faible: ${product.quantity}';
      icon = Icons.warning_amber_rounded;
    } else {
      color = AppColors.successTheme(context);
      text = 'Stock: ${product.quantity}';
      icon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
