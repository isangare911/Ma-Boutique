import 'package:flutter/material.dart';

import '../../../../core/services/subscription_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/subscription.dart';
import 'mobile_payment_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<SubscriptionPlan> _plans = [];
  bool _isLoadingPlans = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
    // Rafraîchir l'abonnement au démarrage
    SubscriptionService.instance.refreshSubscription();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoadingPlans = true);
    final plans = await SubscriptionService.instance.getAvailablePlans();
    if (mounted) {
      setState(() {
        _plans = plans;
        _isLoadingPlans = false;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ACTIVER UN PLAN (via Mobile Money)
  // ═══════════════════════════════════════════════════════════
  Future<void> _activatePlan(SubscriptionPlan plan) async {
    // ⚡ Rediriger vers l'écran de paiement Mobile Money
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MobilePaymentScreen(
          plan: plan.code,
          planName: plan.name,
          amount: plan.priceMonthly,
        ),
      ),
    );

    // Si le paiement a réussi, rafraîchir l'abonnement
    if (result == true && mounted) {
      await SubscriptionService.instance.refreshSubscription();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Abonnement ${plan.name} activé'),
            backgroundColor: AppColors.successTheme(context),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Abonnement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => SubscriptionService.instance.refreshSubscription(),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: SubscriptionService.instance,
        builder: (context, _) {
          final sub = SubscriptionService.instance.subscription;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sub != null) _buildStatusCard(context, sub),
                const SizedBox(height: 24),

                Text(
                  'Plans disponibles',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 12),

                if (_isLoadingPlans)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: CircularProgressIndicator(
                        color: AppColors.green(context),
                      ),
                    ),
                  )
                else
                  ..._plans.map((plan) => _buildPlanCard(context, plan)),

                const SizedBox(height: 24),

                // Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.greenLight(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: AppColors.green(context)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Après expiration, vous aurez 7 jours de période de grâce '
                          'pour régulariser votre situation. Après cela, les ventes '
                          'seront bloquées mais vos données resteront accessibles.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.text(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CARTE STATUT ABONNEMENT
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatusCard(BuildContext context, Subscription sub) {
    // Couleur selon le statut
    Color statusColor;
    IconData statusIcon;

    if (sub.isTrial) {
      statusColor = Colors.blue;
      statusIcon = Icons.card_giftcard;
    } else if (sub.isActiveStatus) {
      statusColor = AppColors.successTheme(context);
      statusIcon = Icons.check_circle;
    } else if (sub.isGracePeriod) {
      statusColor = AppColors.warningTheme(context);
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = AppColors.dangerTheme(context);
      statusIcon = Icons.cancel;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.statusName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Plan: ${sub.planName}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.text(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Jours restants
          if (sub.canSell) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Jours restants',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSec(context),
                  ),
                ),
                Text(
                  '${sub.daysRemaining} jours',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Barre de progression (sur 30 jours)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (sub.daysRemaining / 30).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: statusColor.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation(statusColor),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: statusColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Renouvelez votre abonnement pour continuer à vendre',
                      style: TextStyle(
                        fontSize: 13,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (sub.end != null) ...[
            const SizedBox(height: 12),
            Text(
              'Expire le ${AppFormatters.formatDate(sub.end!)}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSec(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CARTE PLAN
  // ═══════════════════════════════════════════════════════════
  Widget _buildPlanCard(BuildContext context, SubscriptionPlan plan) {
    final currentPlan = SubscriptionService.instance.subscription?.plan;
    final isCurrent = currentPlan == plan.code;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isCurrent ? AppColors.green(context) : AppColors.border(context),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                plan.name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                ),
              ),
              if (isCurrent)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.greenLight(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Actuel',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.green(context),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppFormatters.formatCurrency(plan.priceMonthly.toDouble()),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.green(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Text(
                  '/mois',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSec(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Features
          ...plan.features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: AppColors.green(context), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.text(context),
                        ),
                      ),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: 16),

          // Bouton
          ElevatedButton(
            onPressed: () => _activatePlan(plan),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrent
                  ? AppColors.textSec(context)
                  : AppColors.green(context),
              foregroundColor:
                  isCurrent ? Colors.white : AppColors.onGreen(context),
            ),
            child: Text(isCurrent ? 'Changer de plan' : 'Choisir ce plan'),
          ),
        ],
      ),
    );
  }
}
