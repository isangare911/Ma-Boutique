import 'package:flutter/material.dart';

import '../../features/subscription/presentation/pages/subscription_screen.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';

class SubscriptionBanner extends StatelessWidget {
  const SubscriptionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SubscriptionService.instance,
      builder: (context, _) {
        final sub = SubscriptionService.instance.subscription;

        if (sub == null) return const SizedBox.shrink();

        // Afficher seulement si l'essai approche de la fin ou si en période de grâce
        final showBanner = (sub.isTrial && sub.daysRemaining <= 7) ||
            sub.isGracePeriod ||
            sub.isExpired;

        if (!showBanner) return const SizedBox.shrink();

        Color color;
        String message;
        IconData icon;
        bool showAction = true;

        if (sub.isExpired) {
          color = AppColors.dangerTheme(context);
          icon = Icons.cancel;
          message = 'Abonnement expiré — Ventes bloquées';
        } else if (sub.isGracePeriod) {
          color = AppColors.warningTheme(context);
          icon = Icons.warning_amber_rounded;
          message = 'Période de grâce — Renouvelez vite';
        } else if (sub.daysRemaining == 0) {
          color = AppColors.dangerTheme(context);
          icon = Icons.error_outline;
          message = 'Votre essai expire aujourd\'hui';
        } else {
          color = AppColors.warningTheme(context);
          icon = Icons.schedule;
          message =
              'Essai gratuit — ${sub.daysRemaining} jour${sub.daysRemaining > 1 ? "s" : ""} restant${sub.daysRemaining > 1 ? "s" : ""}';
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SubscriptionScreen(),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                if (showAction)
                  Icon(Icons.arrow_forward_ios, color: color, size: 14),
              ],
            ),
          ),
        );
      },
    );
  }
}
