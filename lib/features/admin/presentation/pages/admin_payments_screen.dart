import 'package:flutter/material.dart';

import '../../../../core/services/admin_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/payment.dart';

class AdminPaymentsScreen extends StatefulWidget {
  final String? filterStatus; // PENDING_REVIEW par défaut

  const AdminPaymentsScreen({
    super.key,
    this.filterStatus = 'PENDING_REVIEW',
  });

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Payment> _allPayments = [];
  List<Payment> _filteredPayments = [];
  bool _isLoading = true;
  String? _processingPaymentId;

  final List<String> _statuses = [
    'PENDING_REVIEW',
    'APPROVED',
    'REJECTED',
    'CANCELLED',
  ];

  final List<String> _statusLabels = [
    'En attente',
    'Approuvés',
    'Rejetés',
    'Annulés',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _applyFilter();
    });
    _loadPayments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    setState(() {
      _isLoading = true;
    });

    final payments = await AdminService.instance.getPayments();

    if (!mounted) return;

    setState(() {
      _allPayments = payments;
      _isLoading = false;
    });
    _applyFilter();
  }

  void _applyFilter() {
    final status = _statuses[_tabController.index];

    setState(() {
      _filteredPayments =
          _allPayments.where((p) => p.status == status).toList();
    });
  }

  // ═══════════════════════════════════════════════════════════
  // APPROUVER UN PAIEMENT
  // ═══════════════════════════════════════════════════════════
  Future<void> _approvePayment(Payment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approuver ce paiement ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Code : ${payment.paymentCode}'),
            const SizedBox(height: 4),
            Text('Montant : ${AppFormatters.formatCurrency(payment.amount)}'),
            const SizedBox(height: 4),
            Text('Transaction : ${payment.transactionId ?? "—"}'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successTheme(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '✓ Vérifiez que vous avez bien reçu le paiement sur votre compte Mobile Money AVANT d\'approuver.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.successTheme(context),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successTheme(context),
            ),
            child: const Text('Approuver'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingPaymentId = payment.id);

    final success = await AdminService.instance.approvePayment(payment.id);

    if (!mounted) return;

    setState(() => _processingPaymentId = null);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Paiement ${payment.paymentCode} approuvé'),
          backgroundColor: AppColors.successTheme(context),
        ),
      );
      await _loadPayments();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erreur lors de l\'approbation'),
          backgroundColor: AppColors.dangerTheme(context),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // REJETER UN PAIEMENT
  // ═══════════════════════════════════════════════════════════
  Future<void> _rejectPayment(Payment payment) async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeter ce paiement ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Code : ${payment.paymentCode}'),
            const SizedBox(height: 4),
            Text('Montant : ${AppFormatters.formatCurrency(payment.amount)}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Raison du rejet *',
                hintText: 'Ex: Paiement non reçu',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerTheme(context),
            ),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Raison du rejet requise')),
      );
      return;
    }

    setState(() => _processingPaymentId = payment.id);

    final success = await AdminService.instance.rejectPayment(
      payment.id,
      controller.text.trim(),
    );

    if (!mounted) return;

    setState(() => _processingPaymentId = null);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paiement ${payment.paymentCode} rejeté'),
          backgroundColor: AppColors.dangerTheme(context),
        ),
      );
      await _loadPayments();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erreur lors du rejet'),
          backgroundColor: AppColors.dangerTheme(context),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Paiements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPayments,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.green(context),
          unselectedLabelColor: AppColors.textSec(context),
          indicatorColor: AppColors.green(context),
          indicatorWeight: 3,
          tabs: _statusLabels.map((label) => Tab(text: label)).toList(),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.green(context),
              ),
            )
          : _filteredPayments.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadPayments,
                  color: AppColors.green(context),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredPayments.length,
                    itemBuilder: (context, index) {
                      return _buildPaymentTile(_filteredPayments[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.payments_outlined,
            size: 80,
            color: AppColors.textSec(context).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun paiement',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSec(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _tabController.index == 0
                ? 'Tous les paiements sont traités ✓'
                : 'Aucun paiement dans cette catégorie',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSec(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTile(Payment payment) {
    final isProcessing = _processingPaymentId == payment.id;
    final isPendingReview = payment.status == 'PENDING_REVIEW';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPendingReview
              ? AppColors.warningTheme(context).withOpacity(0.4)
              : AppColors.border(context),
          width: isPendingReview ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getMethodColor(payment.method).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getMethodIcon(payment.method),
                  color: _getMethodColor(payment.method),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.paymentCode,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      payment.methodName,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSec(context),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormatters.formatCurrency(payment.amount),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.green(context),
                    ),
                  ),
                  Text(
                    payment.planName,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSec(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          Divider(height: 1, color: AppColors.border(context)),
          const SizedBox(height: 12),

          // Informations
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.receipt_long,
                  label: 'Transaction',
                  value: payment.transactionId ?? '—',
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.calendar_today,
                  label: 'Date',
                  value: AppFormatters.formatDate(payment.createdAt),
                ),
              ),
            ],
          ),

          // Actions (seulement si PENDING_REVIEW)
          if (isPendingReview) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        isProcessing ? null : () => _rejectPayment(payment),
                    icon: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.close, size: 18),
                    label: const Text('Rejeter'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      side: BorderSide(color: AppColors.dangerTheme(context)),
                      foregroundColor: AppColors.dangerTheme(context),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        isProcessing ? null : () => _approvePayment(payment),
                    icon: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Approuver'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      backgroundColor: AppColors.successTheme(context),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: AppColors.textSec(context)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSec(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.text(context),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
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
}
