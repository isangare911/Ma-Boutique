import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../../core/services/receipt_pdf_service.dart';
import '../../../../core/services/shop_settings_service.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/cart_item.dart';
import '../../../navigation/presentation/pages/main_navigation_screen.dart';

class ReceiptScreen extends StatelessWidget {
  final List<CartItem> cart;
  final double total;
  final String paymentMethod;
  final String? saleId;

  const ReceiptScreen({
    super.key,
    required this.cart,
    required this.total,
    required this.paymentMethod,
    this.saleId,
  });

  Future<Uint8List> _generatePdf() async {
    return await ReceiptPdfService.instance.generateReceipt(
      saleId: saleId ?? 'SALE-${DateTime.now().millisecondsSinceEpoch}',
      cart: cart,
      total: total,
      paymentMethod: paymentMethod,
    );
  }

  Future<void> _printReceipt(BuildContext context) async {
    try {
      final pdfBytes = await _generatePdf();
      try {
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: 'Recu_${saleId ?? DateTime.now().millisecondsSinceEpoch}',
        );
      } catch (printError) {
        if (context.mounted) {
          final shouldShare = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Impression indisponible'),
              content: const Text(
                'Aucune imprimante n\'est configurée. Voulez-vous partager le reçu à la place ?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Partager'),
                ),
              ],
            ),
          );
          if (shouldShare == true) {
            await Printing.sharePdf(
              bytes: pdfBytes,
              filename:
                  'Recu_${saleId ?? DateTime.now().millisecondsSinceEpoch}.pdf',
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.dangerTheme(context),
          ),
        );
      }
    }
  }

  Future<void> _shareReceipt(BuildContext context) async {
    try {
      final pdfBytes = await _generatePdf();
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Recu_${saleId ?? DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur partage: $e'),
            backgroundColor: AppColors.dangerTheme(context),
          ),
        );
      }
    }
  }

  Future<void> _sendByWhatsApp(BuildContext context) async {
    try {
      final shopName = ShopSettingsService.instance.shopName;
      final displaySaleId = saleId ?? 'N/A';

      final message = 'Bonjour,\n\n'
          'Merci pour votre achat chez $shopName ! 🙏\n\n'
          'Reçu N° $displaySaleId\n'
          'Montant : ${AppFormatters.formatCurrency(total)}\n\n'
          'À bientôt !';

      final phoneController = TextEditingController();
      final phone = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.chat, color: Color(0xFF25D366)),
              SizedBox(width: 8),
              Text('Envoyer par WhatsApp'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Entrez le numéro de téléphone du client :',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '+223 70 12 34 56',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, phoneController.text),
              child: const Text('Envoyer'),
            ),
          ],
        ),
      );

      if (phone == null || phone.trim().isEmpty) return;

      final success = await WhatsAppService.instance.sendMessage(
        phone: phone.trim(),
        message: message,
      );

      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp n\'est pas installé'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.dangerTheme(context),
          ),
        );
      }
    }
  }

  void _goToDashboard(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final displaySaleId =
        saleId ?? 'SALE-${now.millisecondsSinceEpoch.toString().substring(7)}';

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.greenLight(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 50,
                        color: AppColors.green(context),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Paiement réussi !',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Merci et à bientôt !',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSec(context),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Détails du reçu
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(context, 'N° de vente', displaySaleId),
                          Divider(height: 24, color: AppColors.border(context)),
                          _buildInfoRow(
                            context,
                            'Date',
                            AppFormatters.formatDateTime(now),
                          ),
                          Divider(height: 24, color: AppColors.border(context)),
                          _buildInfoRow(
                              context, 'Mode de paiement', paymentMethod),
                          Divider(height: 24, color: AppColors.border(context)),
                          _buildInfoRow(
                            context,
                            'Total payé',
                            AppFormatters.formatCurrency(total),
                            isBold: true,
                          ),
                          Divider(height: 24, color: AppColors.border(context)),
                          _buildInfoRow(
                            context,
                            'Articles',
                            '${cart.fold<int>(0, (sum, item) => sum + item.quantity)}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Boutons d'action
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _printReceipt(context),
                            icon: const Icon(Icons.print),
                            label: const Text('Imprimer'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 50),
                              side: BorderSide(color: AppColors.green(context)),
                              foregroundColor: AppColors.green(context),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _shareReceipt(context),
                            icon: const Icon(Icons.share),
                            label: const Text('Partager'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 50),
                              side: BorderSide(color: AppColors.green(context)),
                              foregroundColor: AppColors.green(context),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: () => _sendByWhatsApp(context),
                      icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                      label: const Text('Envoyer par WhatsApp'),
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
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: () => _goToDashboard(context),
                  child: const Text('Nouvelle vente'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
  }) {
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
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color:
                  isBold ? AppColors.green(context) : AppColors.text(context),
            ),
          ),
        ),
      ],
    );
  }
}
