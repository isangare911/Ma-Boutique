import 'package:flutter/material.dart';

import '../../../../core/permissions/permission_guard.dart';
import '../../../../core/permissions/permissions.dart';
import '../../../../core/services/data_refresh_notifier.dart';
import '../../../../core/services/shop_settings_service.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/credit.dart';
import '../../../../data/models/credit_payment.dart';
import '../../../../data/repositories/credit_repository.dart';

class CreditDetailScreen extends StatefulWidget {
  final Credit credit;

  const CreditDetailScreen({super.key, required this.credit});

  @override
  State<CreditDetailScreen> createState() => _CreditDetailScreenState();
}

class _CreditDetailScreenState extends State<CreditDetailScreen> {
  final CreditRepository _repository = CreditRepository();

  late Credit _credit;
  List<CreditPayment> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _credit = widget.credit;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final freshCredit = await _repository.getCreditById(_credit.id);
      final payments = await _repository.getPaymentsByCredit(_credit.id);

      if (!mounted) return;

      setState(() {
        if (freshCredit != null) _credit = freshCredit;
        _payments = payments;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  double get _remaining => _credit.remainingAmount;

  Color _statusColor(BuildContext context) {
    if (_credit.isPaid) return AppColors.successTheme(context);
    if (_credit.isOverdue) return AppColors.dangerTheme(context);
    if (_credit.isDueSoon) return AppColors.warningTheme(context);
    return AppColors.green(context);
  }

  String get _statusText {
    if (_credit.isPaid) return 'Payé';
    if (_credit.isOverdue) return 'En retard';
    if (_credit.isDueSoon) return 'Bientôt dû';
    return 'En cours';
  }

  // ═══════════════════════════════════════════════════════════
  // ENREGISTRER UN REMBOURSEMENT
  // ═══════════════════════════════════════════════════════════
  Future<void> _registerPayment() async {
    // 🔒 Sécurité : vérifier la permission
    if (!Permissions.can(Permission.collectCreditPayment)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Vous n\'avez pas la permission d\'encaisser un paiement',
          ),
          backgroundColor: AppColors.dangerTheme(context),
        ),
      );
      return;
    }

    final controller = TextEditingController();
    String paymentMethod = 'Espèces';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Enregistrer un remboursement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Solde restant: ${AppFormatters.formatCurrency(_remaining)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.dangerTheme(context),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Montant à payer',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.money),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Mode de paiement'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: paymentMethod,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Espèces', child: Text('Espèces')),
                  DropdownMenuItem(
                      value: 'Orange Money', child: Text('Orange Money')),
                  DropdownMenuItem(
                      value: 'Moov Money', child: Text('Moov Money')),
                  DropdownMenuItem(value: 'Virement', child: Text('Virement')),
                ],
                onChanged: (v) => setDialogState(() => paymentMethod = v!),
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
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      final amount = double.tryParse(controller.text) ?? 0;

      if (amount <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Montant invalide'),
              backgroundColor: AppColors.dangerTheme(context),
            ),
          );
        }
        return;
      }

      if (amount > _remaining) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Le montant ne peut pas dépasser ${AppFormatters.formatCurrency(_remaining)}',
              ),
              backgroundColor: AppColors.dangerTheme(context),
            ),
          );
        }
        return;
      }

      try {
        final payment = CreditPayment(
          id: CreditPayment.generateId(),
          creditId: _credit.id,
          amount: amount,
          date: DateTime.now(),
          paymentMethod: paymentMethod,
        );

        await _repository.addPayment(payment);
        DataRefreshNotifier.instance.notifyCreditsChanged();
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Remboursement de ${AppFormatters.formatCurrency(amount)} enregistré',
              ),
              backgroundColor: AppColors.successTheme(context),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: AppColors.dangerTheme(context),
            ),
          );
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // RAPPELER PAR WHATSAPP
  // ═══════════════════════════════════════════════════════════
  Future<void> _remindByWhatsApp() async {
    final customer = _credit.customer;

    if (customer.phone == null || customer.phone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ce client n\'a pas de numéro de téléphone'),
          backgroundColor: AppColors.dangerTheme(context),
        ),
      );
      return;
    }

    final shopName = ShopSettingsService.instance.shopName;
    final currency = ShopSettingsService.instance.currency;
    final dueDate = AppFormatters.formatDate(_credit.dueDate);

    final message = WhatsAppService.instance.buildCreditReminder(
      customerName: customer.name,
      shopName: shopName,
      amount: _credit.remainingAmount,
      currency: currency,
      dueDate: dueDate,
      isOverdue: _credit.isOverdue,
    );

    final success = await WhatsAppService.instance.sendMessage(
      phone: customer.phone!,
      message: message,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('WhatsApp n\'est pas installé'),
          backgroundColor: AppColors.dangerTheme(context),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Détail du crédit'),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.green(context),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ═══════════════════════════════════════════════
                  // EN-TÊTE CLIENT
                  // ═══════════════════════════════════════════════
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.greenLight(context),
                          child: Text(
                            _credit.customer.name.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.green(context),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _credit.customer.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text(context),
                          ),
                        ),
                        if (_credit.customer.phone != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _credit.customer.phone!,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSec(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ═══════════════════════════════════════════════
                  // MONTANT RESTANT
                  // ═══════════════════════════════════════════════
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _statusColor(context).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _statusColor(context).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Montant restant à payer',
                          style: TextStyle(
                            fontSize: 13,
                            color: _statusColor(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppFormatters.formatCurrency(_remaining),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: _statusColor(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(context),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _statusText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ═══════════════════════════════════════════════
                  // DÉTAILS
                  // ═══════════════════════════════════════════════
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          context,
                          'Montant total',
                          AppFormatters.formatCurrency(_credit.totalAmount),
                        ),
                        Divider(height: 20, color: AppColors.border(context)),
                        _buildDetailRow(
                          context,
                          'Déjà payé',
                          AppFormatters.formatCurrency(_credit.paidAmount),
                        ),
                        Divider(height: 20, color: AppColors.border(context)),
                        _buildDetailRow(
                          context,
                          'Date du crédit',
                          AppFormatters.formatDate(_credit.createdAt),
                        ),
                        Divider(height: 20, color: AppColors.border(context)),
                        _buildDetailRow(
                          context,
                          "Date d'échéance",
                          AppFormatters.formatDate(_credit.dueDate),
                        ),
                        if (_credit.notes != null) ...[
                          Divider(height: 20, color: AppColors.border(context)),
                          _buildDetailRow(
                            context,
                            'Notes',
                            _credit.notes!,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ═══════════════════════════════════════════════
                  // HISTORIQUE DES REMBOURSEMENTS
                  // ═══════════════════════════════════════════════
                  if (_payments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Historique des remboursements',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._payments.map((p) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: AppColors.successTheme(context),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        AppFormatters.formatCurrency(p.amount),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color:
                                              AppColors.successTheme(context),
                                        ),
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          AppFormatters.formatDate(p.date),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSec(context),
                                          ),
                                        ),
                                        Text(
                                          p.paymentMethod,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSec(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ═══════════════════════════════════════════════
                  // BOUTONS D'ACTION
                  // ═══════════════════════════════════════════════
                  if (!_credit.isPaid) ...[
                    // 🔒 Bouton d'encaissement : seulement si collectCreditPayment
                    PermissionGuard(
                      permission: Permission.collectCreditPayment,
                      child: ElevatedButton.icon(
                        onPressed: _registerPayment,
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Enregistrer un paiement'),
                      ),
                    ),

                    // 🔒 Message info si le comptable n'a qu'un accès lecture (au cas où)
                    PermissionGuard(
                      permission: Permission.viewCredits,
                      fallback: const SizedBox.shrink(),
                      child: !Permissions.can(Permission.collectCreditPayment)
                          ? Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline,
                                      color: Colors.blue, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Consultation seule — contactez le gérant pour encaisser.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 12),

                    // Rappel WhatsApp : accessible à tous ceux qui voient les crédits
                    OutlinedButton.icon(
                      onPressed: _remindByWhatsApp,
                      icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                      label: const Text('Rappeler par WhatsApp'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        side: const BorderSide(color: Color(0xFF25D366)),
                        foregroundColor: const Color(0xFF25D366),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSec(context),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text(context),
            ),
          ),
        ),
      ],
    );
  }
}
