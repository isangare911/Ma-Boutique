import 'package:intl/intl.dart';

import '../services/shop_settings_service.dart';

class AppFormatters {
  /// Formatage de la monnaie (utilise la devise configurée)
  static String formatCurrency(double amount) {
    final currency = ShopSettingsService.instance.currency;
    final formatter = NumberFormat('#,##0', 'fr_FR');
    final formatted = formatter.format(amount).replaceAll(',', ' ');
    return '$formatted $currency';
  }

  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }
}
