import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/models/cart_item.dart';
import 'shop_settings_service.dart';

class ReceiptPdfService {
  static final ReceiptPdfService instance = ReceiptPdfService._();
  ReceiptPdfService._();

  /// Génère un PDF de reçu et le retourne en bytes
  Future<Uint8List> generateReceipt({
    required String saleId,
    required List<CartItem> cart,
    required double total,
    required String paymentMethod,
    DateTime? saleDate,
  }) async {
    final pdf = pw.Document();
    final settings = ShopSettingsService.instance.settings;
    final date = saleDate ?? DateTime.now();

    // ⚡ Charger le logo si disponible
    pw.MemoryImage? logoImage;
    if (settings.shopLogoPath != null && settings.shopLogoPath!.isNotEmpty) {
      try {
        final logoFile = File(settings.shopLogoPath!);
        if (await logoFile.exists()) {
          final bytes = await logoFile.readAsBytes();
          logoImage = pw.MemoryImage(bytes);
        }
      } catch (_) {}
    }

    final currency = settings.currency;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Format ticket de caisse 80mm
        margin: const pw.EdgeInsets.all(12),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ═══════════════════════════════════════════════
              // EN-TÊTE
              // ═══════════════════════════════════════════════
              pw.Center(
                child: pw.Column(
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        width: 60,
                        height: 60,
                        child: pw.Image(logoImage),
                      ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      settings.shopName.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (settings.phone != null &&
                        settings.phone!.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Tél: ${settings.phone}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                    if (settings.address != null &&
                        settings.address!.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        settings.address!,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 6),

              // ═══════════════════════════════════════════════
              // INFOS REÇU
              // ═══════════════════════════════════════════════
              pw.Text(
                'REÇU N° ${saleId.substring(saleId.length > 8 ? saleId.length - 8 : 0)}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Date: ${_formatDateTime(date)}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 6),

              // ═══════════════════════════════════════════════
              // ARTICLES
              // ═══════════════════════════════════════════════
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Article',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Qté',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Total',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(),
              pw.SizedBox(height: 4),

              ...cart.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        item.product.name,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${_formatPrice(item.product.sellingPrice)} $currency',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                          pw.Text(
                            'x${item.quantity}',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                          pw.Text(
                            '${_formatPrice(item.subtotal)} $currency',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 6),
              pw.Divider(),
              pw.SizedBox(height: 6),

              // ═══════════════════════════════════════════════
              // TOTAL
              // ═══════════════════════════════════════════════
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${_formatPrice(total)} $currency',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),

              // Paiement
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Mode de paiement',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    paymentMethod,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),

              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 8),

              // ═══════════════════════════════════════════════
              // PIED DE PAGE
              // ═══════════════════════════════════════════════
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Merci pour votre achat !',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'À bientôt ',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Généré par Ma Boutique',
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════
  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
