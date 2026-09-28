import 'package:flutter/material.dart';

import '../../../../core/services/data_refresh_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/supplier.dart';
import '../../../../data/models/supplier_transaction.dart';
import '../../../../data/repositories/supplier_repository.dart';
import 'add_supplier_screen.dart';

class SupplierDetailScreen extends StatefulWidget {
  final Supplier supplier;

  const SupplierDetailScreen({super.key, required this.supplier});

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  final SupplierRepository _repository = SupplierRepository();

  late Supplier _supplier;
  List<SupplierTransaction> _transactions = [];
  double _balance = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _supplier = widget.supplier;
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final freshSupplier = await _repository.getSupplierById(_supplier.id);
      final transactions =
          await _repository.getTransactionsBySupplier(_supplier.id);
      final balance = await _repository.getSupplierBalance(_supplier.id);

      if (!mounted) return;
      setState(() {
        if (freshSupplier != null) _supplier = freshSupplier;
        _transactions = transactions;
        _balance = balance;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // AJOUTER UNE TRANSACTION
  // ═══════════════════════════════════════════════════════════
  Future<void> _addTransaction() async {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String type = 'PURCHASE'; // achat par défaut
    DateTime date = DateTime.now();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Nouvelle transaction',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),

                // Type de transaction
                const Text(
                  'Type',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildTypeChip(
                        label: 'Achat',
                        icon: Icons.shopping_cart_outlined,
                        value: 'PURCHASE',
                        selected: type == 'PURCHASE',
                        color: AppColors.primary,
                        onTap: () => setModalState(() => type = 'PURCHASE'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTypeChip(
                        label: 'Paiement',
                        icon: Icons.payments_outlined,
                        value: 'PAYMENT',
                        selected: type == 'PAYMENT',
                        color: AppColors.success,
                        onTap: () => setModalState(() => type = 'PAYMENT'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTypeChip(
                        label: 'Dette',
                        icon: Icons.receipt_long_outlined,
                        value: 'DEBT',
                        selected: type == 'DEBT',
                        color: AppColors.warning,
                        onTap: () => setModalState(() => type = 'DEBT'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Montant
                const Text(
                  'Montant (FCFA)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Ex: 25000',
                    prefixIcon: const Icon(Icons.money),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                const Text(
                  'Description (optionnel)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Ex: Achat 10 sacs de riz',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Montant invalide'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                      return;
                    }

                    try {
                      final transaction = SupplierTransaction(
                        id: SupplierTransaction.generateId(),
                        supplierId: _supplier.id,
                        type: type,
                        amount: amount,
                        description: descController.text.trim().isEmpty
                            ? null
                            : descController.text.trim(),
                        transactionDate: date,
                        createdAt: DateTime.now(),
                      );

                      await _repository.addTransaction(transaction);

                      if (!context.mounted) return;
                      Navigator.pop(context, true);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur: $e'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Enregistrer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == true) {
      DataRefreshNotifier.instance.notifyProductsChanged();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction enregistrée'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Widget _buildTypeChip({
    required String label,
    required IconData icon,
    required String value,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? color : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SUPPRIMER UNE TRANSACTION
  // ═══════════════════════════════════════════════════════════
  Future<void> _deleteTransaction(SupplierTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la transaction'),
        content:
            const Text('Voulez-vous vraiment supprimer cette transaction ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.deleteTransaction(transaction.id);
        DataRefreshNotifier.instance.notifyProductsChanged();
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Détail fournisseur'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddSupplierScreen(supplier: _supplier),
                ),
              );
              DataRefreshNotifier.instance.notifyProductsChanged();
              await _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // En-tête fournisseur
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.accent,
                          child: Text(
                            _supplier.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _supplier.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (_supplier.phone != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _supplier.phone!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (_supplier.address != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _supplier.address!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Solde
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _balance > 0
                          ? AppColors.danger.withOpacity(0.1)
                          : _balance < 0
                              ? AppColors.success.withOpacity(0.1)
                              : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _balance > 0
                            ? AppColors.danger.withOpacity(0.3)
                            : _balance < 0
                                ? AppColors.success.withOpacity(0.3)
                                : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _balance > 0
                              ? 'Montant à payer'
                              : _balance < 0
                                  ? 'Avance versée'
                                  : 'Compte soldé',
                          style: TextStyle(
                            fontSize: 13,
                            color: _balance > 0
                                ? AppColors.danger
                                : _balance < 0
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppFormatters.formatCurrency(_balance.abs()),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _balance > 0
                                ? AppColors.danger
                                : _balance < 0
                                    ? AppColors.success
                                    : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bouton ajouter transaction
                  ElevatedButton.icon(
                    onPressed: _addTransaction,
                    icon: const Icon(Icons.add),
                    label: const Text('Nouvelle transaction'),
                  ),
                  const SizedBox(height: 24),

                  // Historique
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Historique des transactions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'Aucune transaction',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    ..._transactions.map(
                      (t) => _buildTransactionTile(t),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildTransactionTile(SupplierTransaction transaction) {
    Color color;
    IconData icon;
    String label;
    String sign;

    if (transaction.isPayment) {
      color = AppColors.success;
      icon = Icons.arrow_upward;
      label = 'Paiement';
      sign = '-';
    } else if (transaction.isPurchase) {
      color = AppColors.primary;
      icon = Icons.shopping_cart_outlined;
      label = 'Achat';
      sign = '+';
    } else {
      color = AppColors.warning;
      icon = Icons.receipt_long_outlined;
      label = 'Dette';
      sign = '+';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (transaction.description != null)
                  Text(
                    transaction.description!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  AppFormatters.formatDate(transaction.transactionDate),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$sign ${AppFormatters.formatCurrency(transaction.amount)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _deleteTransaction(transaction),
            child: const Icon(
              Icons.delete_outline,
              color: AppColors.textSecondary,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
