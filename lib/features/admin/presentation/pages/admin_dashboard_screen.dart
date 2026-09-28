import 'package:flutter/material.dart';

import '../../../../core/services/admin_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/admin_models.dart';
import 'admin_payments_screen.dart';
import 'admin_shops_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminStats? _stats;
  List<AdminShop> _shops = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  /// ⚡ Charge stats + boutiques en parallèle
  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final results = await Future.wait([
      AdminService.instance.getStats(),
      AdminService.instance.getShops(),
    ]);

    if (!mounted) return;

    final stats = results[0] as AdminStats?;
    final shops = results[1] as List<AdminShop>;

    setState(() {
      _stats = stats;
      _shops = shops;
      _isLoading = false;
      if (stats == null) {
        _error = 'Erreur de chargement des statistiques';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Dashboard Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Quitter le mode admin',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.green(context),
              ),
            )
          : _error != null
              ? _buildError()
              : _buildDashboard(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 60,
              color: AppColors.dangerTheme(context),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.text(context)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    if (_stats == null) return const SizedBox.shrink();

    // ⚡ Calculs des alertes
    final expiringSoon = _shops
        .where((s) =>
            s.status != 'EXPIRED' &&
            s.daysRemaining > 0 &&
            s.daysRemaining <= 7)
        .toList()
      ..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

    final longExpired = _shops.where((s) => s.status == 'EXPIRED').toList();

    final hasAlerts = expiringSoon.isNotEmpty ||
        longExpired.isNotEmpty ||
        _stats!.pendingReview > 0;

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: AppColors.green(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══════════════════════════════════════════════════
            // 🔔 ALERTES
            // ═══════════════════════════════════════════════════
            if (hasAlerts) ...[
              _buildAlertsSection(expiringSoon, longExpired),
              const SizedBox(height: 24),
            ],

            // ═══════════════════════════════════════════════════
            // CARTE PRINCIPALE (MRR)
            // ═══════════════════════════════════════════════════
            _buildMainRevenueCard(),

            const SizedBox(height: 24),

            // Actions rapides
            Text(
              'Actions rapides',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 12),
            _buildQuickActions(),

            const SizedBox(height: 24),

            // Stats boutiques
            Text(
              'Boutiques',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 12),
            _buildShopsStats(),

            const SizedBox(height: 24),

            // Revenus par plan
            if (_stats!.revenueByPlan.isNotEmpty) ...[
              Text(
                'Revenus par plan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 12),
              _buildRevenueByPlan(),
              const SizedBox(height: 24),
            ],

            // Revenus par méthode
            if (_stats!.revenueByMethod.isNotEmpty) ...[
              Text(
                'Revenus par méthode',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 12),
              _buildRevenueByMethod(),
              const SizedBox(height: 24),
            ],

            // Détails
            Text(
              'Détails des revenus',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 12),
            _buildRevenueDetails(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔔 SECTION ALERTES
  // ═══════════════════════════════════════════════════════════
  Widget _buildAlertsSection(
    List<AdminShop> expiringSoon,
    List<AdminShop> longExpired,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.notifications_active,
              color: AppColors.warningTheme(context),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Alertes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Paiements en attente
        if (_stats!.pendingReview > 0)
          _buildAlertTile(
            icon: Icons.pending_actions,
            color: AppColors.warningTheme(context),
            title:
                '${_stats!.pendingReview} paiement${_stats!.pendingReview > 1 ? "s" : ""} en attente',
            subtitle: 'À valider dans l\'onglet paiements',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminPaymentsScreen(),
                ),
              );
              _loadAll();
            },
          ),

        // Boutiques expirant bientôt
        if (expiringSoon.isNotEmpty)
          _buildAlertTile(
            icon: Icons.schedule,
            color: AppColors.dangerTheme(context),
            title:
                '${expiringSoon.length} boutique${expiringSoon.length > 1 ? "s" : ""} expire dans 7 jours',
            subtitle: expiringSoon.length == 1
                ? '${expiringSoon.first.name} — J-${expiringSoon.first.daysRemaining}'
                : 'La plus urgente : ${expiringSoon.first.name} (J-${expiringSoon.first.daysRemaining})',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminShopsScreen(
                    initialTab: 0,
                    initialSort: 'days_asc',
                  ),
                ),
              );
              _loadAll();
            },
          ),

        // Boutiques expirées
        if (longExpired.isNotEmpty)
          _buildAlertTile(
            icon: Icons.cancel,
            color: AppColors.textSec(context),
            title:
                '${longExpired.length} boutique${longExpired.length > 1 ? "s" : ""} expirée${longExpired.length > 1 ? "s" : ""}',
            subtitle: 'À relancer ou désactiver',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminShopsScreen(initialTab: 4),
                ),
              );
              _loadAll();
            },
          ),
      ],
    );
  }

  Widget _buildAlertTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
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
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSec(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: color,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CARTE PRINCIPALE (MRR)
  // ═══════════════════════════════════════════════════════════
  Widget _buildMainRevenueCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.green(context),
            AppColors.green(context).withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.green(context).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.onGreen(context).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.trending_up,
                  color: AppColors.onGreen(context),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'MRR (Revenus mensuels)',
                style: TextStyle(
                  color: AppColors.onGreenSec(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            AppFormatters.formatCurrency(_stats!.mrr),
            style: TextStyle(
              color: AppColors.onGreen(context),
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ce mois-ci',
            style: TextStyle(
              color: AppColors.onGreenSec(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          Divider(
            color: AppColors.onGreen(context).withOpacity(0.3),
            height: 1,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  'Cette semaine',
                  AppFormatters.formatCurrency(_stats!.weeklyRevenue),
                ),
              ),
              Expanded(
                child: _buildMiniStat(
                  'Total encaissé',
                  AppFormatters.formatCurrency(_stats!.totalRevenue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.onGreenSec(context),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: AppColors.onGreen(context),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ACTIONS RAPIDES
  // ═══════════════════════════════════════════════════════════
  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            icon: Icons.storage,
            label: 'Boutiques',
            count: _stats!.totalShops,
            color: Colors.blue,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminShopsScreen()),
              );
              _loadAll();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            icon: Icons.pending_actions,
            label: 'En attente',
            count: _stats!.pendingReview,
            color: _stats!.pendingReview > 0
                ? AppColors.warningTheme(context)
                : AppColors.textSec(context),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminPaymentsScreen(),
                ),
              );
              _loadAll();
            },
            highlight: _stats!.pendingReview > 0,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                highlight ? color.withOpacity(0.5) : AppColors.border(context),
            width: highlight ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                if (highlight)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSec(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // STATS BOUTIQUES
  // ═══════════════════════════════════════════════════════════
  Widget _buildShopsStats() {
    return Row(
      children: [
        Expanded(
          child: _buildShopStatCard(
            label: 'Actives',
            value: _stats!.activeShops,
            color: AppColors.successTheme(context),
            icon: Icons.check_circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildShopStatCard(
            label: 'Essai',
            value: _stats!.trialShops,
            color: Colors.blue,
            icon: Icons.card_giftcard,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildShopStatCard(
            label: 'Grâce',
            value: _stats!.graceShops,
            color: AppColors.warningTheme(context),
            icon: Icons.hourglass_bottom,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildShopStatCard(
            label: 'Expirées',
            value: _stats!.expiredShops,
            color: AppColors.dangerTheme(context),
            icon: Icons.cancel,
          ),
        ),
      ],
    );
  }

  Widget _buildShopStatCard({
    required String label,
    required int value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSec(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // REVENUS PAR PLAN
  // ═══════════════════════════════════════════════════════════
  Widget _buildRevenueByPlan() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: _stats!.revenueByPlan.map((item) {
          final totalRevenue = _stats!.revenueByPlan.fold<double>(
            0,
            (sum, i) => sum + i.total,
          );
          final ratio = totalRevenue > 0 ? item.total / totalRevenue : 0.0;
          final color = _getPlanColor(item.plan);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.planName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${item.count})',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSec(context),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      AppFormatters.formatCurrency(item.total),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: AppColors.border(context),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getPlanColor(String plan) {
    switch (plan) {
      case 'ESSENTIEL':
        return Colors.blue;
      case 'PRO':
        return AppColors.green(context);
      case 'BUSINESS':
        return Colors.purple;
      default:
        return AppColors.textSec(context);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // REVENUS PAR MÉTHODE
  // ═══════════════════════════════════════════════════════════
  Widget _buildRevenueByMethod() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: _stats!.revenueByMethod.map((item) {
          final totalRevenue = _stats!.revenueByMethod.fold<double>(
            0,
            (sum, i) => sum + i.total,
          );
          final ratio = totalRevenue > 0 ? item.total / totalRevenue : 0.0;
          final color = _getMethodColor(item.method);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getMethodIcon(item.method),
                          color: color,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.methodName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${item.count})',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSec(context),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      AppFormatters.formatCurrency(item.total),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: AppColors.border(context),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getMethodColor(String method) {
    switch (method) {
      case 'ORANGE_MONEY':
        return const Color(0xFFFF6600);
      case 'WAVE':
        return const Color(0xFF1DC8FF);
      case 'MOOV_MONEY':
        return const Color(0xFF0066B3);
      default:
        return AppColors.textSec(context);
    }
  }

  IconData _getMethodIcon(String method) {
    switch (method) {
      case 'ORANGE_MONEY':
        return Icons.phone_android;
      case 'WAVE':
        return Icons.waves;
      case 'MOOV_MONEY':
        return Icons.phone_android;
      default:
        return Icons.payment;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // DÉTAILS REVENUS
  // ═══════════════════════════════════════════════════════════
  Widget _buildRevenueDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            'Paiements approuvés',
            '${_stats!.totalPayments}',
            AppColors.successTheme(context),
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            'En attente de validation',
            '${_stats!.pendingReview}',
            _stats!.pendingReview > 0
                ? AppColors.warningTheme(context)
                : AppColors.textSec(context),
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            'Rejetés',
            '${_stats!.rejectedPayments}',
            _stats!.rejectedPayments > 0
                ? AppColors.dangerTheme(context)
                : AppColors.textSec(context),
          ),
          Divider(height: 32, color: AppColors.border(context)),
          _buildDetailRow(
            'Nouveaux ce mois',
            '+${_stats!.newShopsThisMonth}',
            AppColors.green(context),
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            'Nouveaux cette semaine',
            '+${_stats!.newShopsThisWeek}',
            AppColors.green(context),
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            'Taux de réabonnement',
            '${_stats!.renewalRate.toStringAsFixed(1)}%',
            AppColors.green(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: AppColors.textSec(context)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
