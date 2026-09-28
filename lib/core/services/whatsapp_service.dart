import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  static final WhatsAppService instance = WhatsAppService._();
  WhatsAppService._();

  /// Nettoie un numéro de téléphone (retire espaces, +, tirets)
  /// et retourne le format international sans '+' pour WhatsApp
  /// Ex: "+223 70 12 34 56" → "22370123456"
  String _cleanPhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Ouvre WhatsApp avec un message prérempli
  ///
  /// - [phone] : numéro du destinataire (avec ou sans indicatif)
  /// - [message] : message à envoyer
  /// - [includeCountryCode] : si true, on considère que le numéro a déjà l'indicatif
  Future<bool> sendMessage({
    required String phone,
    required String message,
  }) async {
    try {
      final cleanedPhone = _cleanPhoneNumber(phone);

      // ⚡ Utiliser le lien officiel WhatsApp (wa.me)
      final uri = Uri.parse(
        'https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(message)}',
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        // Fallback : ouvrir WhatsApp sans numéro
        final fallbackUri = Uri.parse(
          'https://wa.me/?text=${Uri.encodeComponent(message)}',
        );
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
          return true;
        }
        return false;
      }
    } catch (e) {
      debugPrint('Erreur WhatsApp: $e');
      return false;
    }
  }

  /// Vérifie si WhatsApp est installé
  Future<bool> isWhatsAppInstalled() async {
    try {
      final uri = Uri.parse('https://wa.me/');
      return await canLaunchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // MESSAGES PRÉDÉFINIS
  // ═══════════════════════════════════════════════════════════

  /// Message de rappel de crédit
  String buildCreditReminder({
    required String customerName,
    required String shopName,
    required double amount,
    required String currency,
    required String dueDate,
    required bool isOverdue,
  }) {
    if (isOverdue) {
      return 'Bonjour $customerName,\n\n'
          'Ceci est un rappel amical de $shopName.\n\n'
          'Votre crédit de ${_formatAmount(amount)} $currency est en retard.\n'
          'Échéance dépassée : $dueDate\n\n'
          'Merci de bien vouloir régulariser votre situation.\n\n'
          'Cordialement,\n$shopName';
    } else {
      return 'Bonjour $customerName,\n\n'
          'Ceci est un rappel de $shopName.\n\n'
          'Votre crédit de ${_formatAmount(amount)} $currency arrive à échéance le $dueDate.\n\n'
          'Merci de prévoir le règlement.\n\n'
          'Cordialement,\n$shopName';
    }
  }

  /// Message de reçu après vente
  String buildSaleReceipt({
    required String customerName,
    required String shopName,
    required double total,
    required String currency,
    required String saleId,
  }) {
    return 'Bonjour $customerName,\n\n'
        'Merci pour votre achat chez $shopName ! 🙏\n\n'
        'Reçu N° $saleId\n'
        'Montant : ${_formatAmount(total)} $currency\n\n'
        'À bientôt !';
  }

  /// Formatage d'un montant (ex: 15000 → "15 000")
  String _formatAmount(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
  }
}
