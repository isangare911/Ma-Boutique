import 'package:flutter/material.dart';

import '../../features/subscription/presentation/pages/subscription_screen.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';

class SubscriptionGuard {
  /// Vérifie si l'utilisateur peut effectuer une action.
  /// Retourne `true` si autorisé, sinon affiche un dialog et retourne `false`.
  static Future<bool> canPerformAction(
    BuildContext context, {
    required String actionName,
  }) async {
    // ⚡ 1. Vérifier la manipulation de date
    final isManipulated =
        await SubscriptionService.instance.isDateManipulated();

    if (isManipulated) {
      if (context.mounted) {
        await _showManipulationDialog(context);
      }
      return false;
    }

    // ⚡ 2. Vérifier l'abonnement
    if (!SubscriptionService.instance.canSell) {
      if (context.mounted) {
        await _showExpiredDialog(context, actionName);
      }
      return false;
    }

    return true;
  }

  // ═══════════════════════════════════════════════════════════
  // DIALOG : ABONNEMENT EXPIRÉ / GRÂCE
  // ═══════════════════════════════════════════════════════════
  static Future<void> _showExpiredDialog(
    BuildContext context,
    String actionName,
  ) async {
    final status = SubscriptionService.instance.subscription?.status;
    final daysRemaining = SubscriptionService.instance.daysRemaining;

    String title;
    String message;
    IconData icon;
    Color color;

    if (status == 'GRACE_PERIOD') {
      title = 'Période de grâce';
      message = 'Votre abonnement est expiré depuis peu. Vous avez encore '
          'quelques jours pour régulariser votre situation avant que '
          'les ventes soient complètement bloquées.';
      icon = Icons.warning_amber_rounded;
      color = AppColors.warningTheme(context);
    } else {
      title = 'Abonnement expiré';
      message = 'Votre abonnement est expiré. '
          'Renouvelez-le pour continuer à utiliser "$actionName".';
      icon = Icons.lock_outline;
      color = AppColors.dangerTheme(context);
    }

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 14)),
            if (daysRemaining > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: color, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '$daysRemaining jour${daysRemaining > 1 ? "s" : ""} restant${daysRemaining > 1 ? "s" : ""}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SubscriptionScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green(context),
              foregroundColor: AppColors.onGreen(context),
            ),
            child: const Text('Renouveler'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DIALOG : MANIPULATION DE DATE
  // ═══════════════════════════════════════════════════════════
  static Future<void> _showManipulationDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false, // ⚡ Empêcher la fermeture
        child: AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.gpp_bad,
                color: AppColors.dangerTheme(context),
                size: 28,
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('Sécurité')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'La date de votre téléphone a été modifiée de manière '
                'suspecte. Pour des raisons de sécurité, votre session '
                'va être fermée.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerTheme(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Veuillez corriger la date dans les paramètres de votre '
                  'téléphone puis vous reconnecter.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                // ⚡ Forcer la déconnexion
                await AuthService.instance.logout();
                // ⚡ Redémarrer vers le login
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/',
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dangerTheme(context),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
              ),
              child: const Text('Se déconnecter'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HELPER : Afficher un message court (sans dialog)
  // ═══════════════════════════════════════════════════════════
  static void showBlockedSnackBar(BuildContext context, String actionName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Abonnement expiré — Impossible d\'effectuer "$actionName"',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.dangerTheme(context),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Renouveler',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SubscriptionScreen(),
              ),
            );
          },
        ),
      ),
    );
  }
}
