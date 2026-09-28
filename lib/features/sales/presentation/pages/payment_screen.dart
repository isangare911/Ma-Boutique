import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/subscription_guard.dart';
import '../../../../data/models/cart_item.dart';
import '../../../../data/models/sale.dart';
import '../../../../data/models/sale_item.dart';
import '../../../../data/repositories/sale_repository.dart';
import 'receipt_screen.dart';

class PaymentScreen extends StatefulWidget {
  final List<CartItem> cart;
  final double total;

  const PaymentScreen({
    super.key,
    required this.cart,
    required this.total,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedPayment = 'Espèces';
  bool _isProcessing = false;
  final SaleRepository _repository = SaleRepository();

  final List<Map<String, dynamic>> _paymentMethods = [
    {'label': 'Espèces', 'icon': Icons.money, 'color': AppColors.success},
    {
      'label': 'Orange Money',
      'icon': Icons.phone_android,
      'color': Colors.orange
    },
    {'label': 'Moov Money', 'icon': Icons.phone_android, 'color': Colors.blue},
    {
      'label': 'Carte bancaire',
      'icon': Icons.credit_card,
      'color': Colors.purple
    },
  ];

  Future<void> _validatePayment() async {
    // ⚡ Vérifier l'abonnement AVANT d'encaisser
    final canProceed = await SubscriptionGuard.canPerformAction(
      context,
      actionName: 'Vente',
    );
    if (!canProceed) return;

    setState(() => _isProcessing = true);

    try {
      final saleId = Sale.generateId();
      final saleItems = widget.cart.map((item) {
        return SaleItem(
          id: SaleItem.generateId(),
          saleId: saleId,
          productId: item.product.id,
          productName: item.product.name,
          unitPrice: item.product.sellingPrice,
          purchasePrice: item.product.purchasePrice,
          quantity: item.quantity,
        );
      }).toList();

      final totalProfit = saleItems.fold<double>(
        0,
        (sum, item) => sum + item.profit,
      );

      final sale = Sale(
        id: saleId,
        totalAmount: widget.total,
        totalProfit: totalProfit,
        paymentMethod: _selectedPayment,
        createdAt: DateTime.now(),
        items: saleItems,
      );

      await _repository.addSale(sale);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ReceiptScreen(
              cart: widget.cart,
              total: widget.total,
              paymentMethod: _selectedPayment,
              saleId: saleId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la vente: $e'),
            backgroundColor: AppColors.dangerTheme(context),
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Paiement'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.green(context),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total à payer',
                            style: TextStyle(
                              color: AppColors.onGreenSec(context),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppFormatters.formatCurrency(widget.total),
                            style: TextStyle(
                              color: AppColors.onGreen(context),
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Mode de paiement',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._paymentMethods.map((method) {
                      final isSelected = _selectedPayment == method['label'];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.green(context)
                                : AppColors.border(context),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: RadioListTile<String>(
                          value: method['label'],
                          groupValue: _selectedPayment,
                          onChanged: _isProcessing
                              ? null
                              : (value) =>
                                  setState(() => _selectedPayment = value!),
                          activeColor: AppColors.green(context),
                          title: Row(
                            children: [
                              Icon(method['icon'],
                                  color: method['color'], size: 22),
                              const SizedBox(width: 12),
                              Text(
                                method['label'],
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.text(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _validatePayment,
                  child: _isProcessing
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onGreen(context),
                          ),
                        )
                      : const Text('Encaisser le paiement'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
