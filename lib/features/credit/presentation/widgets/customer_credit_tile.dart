import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/credit.dart';

class CustomerCreditTile extends StatelessWidget {
  final Credit credit;
  final VoidCallback onTap;

  const CustomerCreditTile({
    super.key,
    required this.credit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Détermine la couleur et le statut
    Color statusColor;
    String statusText;

    if (credit.isPaid) {
      statusColor = AppColors.successTheme(context);
      statusText = 'Payé';
    } else if (credit.isOverdue) {
      statusColor = AppColors.dangerTheme(context);
      statusText = 'En retard';
    } else if (credit.isDueSoon) {
      statusColor = AppColors.warningTheme(context);
      statusText = 'Bientôt dû';
    } else {
      statusColor = AppColors.green(context);
      statusText = 'En cours';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          children: [
            // Ligne supérieure : Avatar + Nom + Montant
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.greenLight(context),
                  child: Text(
                    credit.customer.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.green(context),
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        credit.customer.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text(context),
                        ),
                      ),
                      if (credit.customer.phone != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          credit.customer.phone!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSec(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppFormatters.formatCurrency(credit.remainingAmount),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(height: 1, color: AppColors.border(context)),
            const SizedBox(height: 8),

            // Ligne inférieure : Détails
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(
                  context,
                  'Total',
                  AppFormatters.formatCurrency(credit.totalAmount),
                ),
                _buildInfoItem(
                  context,
                  'Payé',
                  AppFormatters.formatCurrency(credit.paidAmount),
                ),
                _buildInfoItem(
                  context,
                  'Échéance',
                  AppFormatters.formatDate(credit.dueDate),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textSec(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.text(context),
          ),
        ),
      ],
    );
  }
}
