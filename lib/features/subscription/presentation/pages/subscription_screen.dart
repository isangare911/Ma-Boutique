import 'package:flutter/material.dart';

import '../../../../core/services/subscription_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/subscription.dart';
import 'mobile_payment_screen.dart';
import 'pending_approval_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  /// ⚡ Si true, on affiche un bandeau "Bienvenue" (nouvel abonné).
  /// Si false, on est dans le flux normal (renouvellement).
  final bool isNewUser;

  const SubscriptionScreen({
    super.key,
    this.isNewUser = false,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<SubscriptionPlan> _plans = [];
  bool _isLoadingPlans = true;
  bool _isRequestingTrial = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
    // ⚡ Ne PAS appeler refreshSubscription ici — ça déclenche un setState pendant le build
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

  // ═══════════════════════════════════════════════════════════
  // DEMANDER UN ESSAI GRATUIT
  // ═══════════════════════════════════════════════════════════
  Future<void> _requestFreeTrial() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demander un essai gratuit ?'),
        content: const Text(
          'Votre demande sera envoyée à l\'administrateur. '
          'Vous serez notifié dès qu\'elle sera approuvée.\n\n'
          'Vous pouvez aussi contacter directement le support '
          'pour accélérer le traitement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Envoyer la demande'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRequestingTrial = true);

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    setState(() => _isRequestingTrial = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const PendingApprovalScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Abonnement'),
        automaticallyImplyLeading: !widget.isNewUser,
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
                // ⚡ Bandeau "Bienvenue" si nouveau
                if (widget.isNewUser) ...[
                  _buildWelcomeBanner(context),
                  const SizedBox(height: 24),
                ],

                // ⚡ Carte de statut (sauf si PENDING_VALIDATION)
                if (sub != null && sub.status != 'PENDING_VALIDATION')
                  _buildStatusCard(context, sub),
                if (sub != null && sub.status != 'PENDING_VALIDATION')
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

                // ⚡ Section essai gratuit
                _buildFreeTrialSection(context),

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
  // BANDEAU BIENVENUE
  // ═══════════════════════════════════════════════════════════
  Widget _buildWelcomeBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.green(context),
            AppColors.green(context).withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.celebration,
                color: AppColors.onGreen(context),
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Bienvenue !',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onGreen(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Pour commencer à utiliser Ma Boutique, choisissez un plan d\'abonnement.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.onGreen(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ou demandez un essai gratuit en bas de cette page.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.onGreen(context).withOpacity(0.9),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SECTION ESSAI GRATUIT
  // ═══════════════════════════════════════════════════════════
  Widget _buildFreeTrialSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warningTheme(context).withOpacity(0.4),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningTheme(context).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.card_giftcard,
                  color: AppColors.warningTheme(context),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Essai gratuit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Vous préférez tester avant de payer ? Demandez un essai gratuit. '
            'L\'administrateur validera votre demande et vous recevrez une '
            'confirmation dès que votre compte sera activé.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSec(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isRequestingTrial ? null : _requestFreeTrial,
            icon: _isRequestingTrial
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.warningTheme(context),
                    ),
                  )
                : const Icon(Icons.card_giftcard),
            label: Text(
              _isRequestingTrial
                  ? 'Envoi en cours...'
                  : 'Demander un essai gratuit',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              side: BorderSide(color: AppColors.warningTheme(context)),
              foregroundColor: AppColors.warningTheme(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CARTE STATUT ABONNEMENT
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatusCard(BuildContext context, Subscription sub) {
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
