import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/product.dart';

class StockAlertsScreen extends StatelessWidget {
  final List<Product> products;

  const StockAlertsScreen({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    final outOfStock = products.where((p) => p.quantity == 0).toList();
    final lowStock = products
        .where((p) => p.quantity > 0 && p.quantity <= p.alertThreshold)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Alertes stock'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (outOfStock.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                'Ruptures (${outOfStock.length})',
                AppColors.dangerTheme(context),
              ),
              const SizedBox(height: 12),
              ...outOfStock.map(
                  (p) => _buildAlertTile(context, product: p, isRupture: true)),
              const SizedBox(height: 24),
            ],
            if (lowStock.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                'Stock faible (${lowStock.length})',
                AppColors.warningTheme(context),
              ),
              const SizedBox(height: 12),
              ...lowStock.map((p) =>
                  _buildAlertTile(context, product: p, isRupture: false)),
            ],
            if (outOfStock.isEmpty && lowStock.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 80,
                        color: AppColors.successTheme(context).withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune alerte',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tous vos stocks sont suffisants',
                        style: TextStyle(color: AppColors.textSec(context)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertTile(
    BuildContext context, {
    required Product product,
    required bool isRupture,
  }) {
    final color = isRupture
        ? AppColors.dangerTheme(context)
        : AppColors.warningTheme(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isRupture ? Icons.cancel_outlined : Icons.warning_amber_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 2),
                Text(
                  isRupture
                      ? 'Rupture de stock'
                      : 'Stock restant: ${product.quantity} ${product.unit ?? ""}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSec(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: AppColors.textSec(context),
          ),
        ],
      ),
    );
  }
}
