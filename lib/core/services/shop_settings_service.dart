import 'package:flutter/foundation.dart';

import '../../data/models/shop_settings.dart';
import '../../data/repositories/shop_settings_repository.dart';

class ShopSettingsService extends ChangeNotifier {
  static final ShopSettingsService instance = ShopSettingsService._();
  ShopSettingsService._();

  final ShopSettingsRepository _repository = ShopSettingsRepository();

  ShopSettings _settings = ShopSettings.defaults;
  bool _isLoaded = false;

  ShopSettings get settings => _settings;
  String get currency => _settings.currency;
  String get shopName => _settings.shopName;
  String? get shopLogoPath => _settings.shopLogoPath;
  bool get isLoaded => _isLoaded;

  /// Charge les paramètres au démarrage
  Future<void> initialize() async {
    try {
      _settings = await _repository.getSettings();
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur chargement paramètres: $e');
      _settings = ShopSettings.defaults;
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Met à jour les paramètres
  Future<void> updateSettings(ShopSettings newSettings) async {
    final updated = newSettings.copyWith(id: ShopSettings.defaultId);
    await _repository.saveSettings(newSettings);
    _settings = updated;
    notifyListeners();
  }

  /// Raccourci : formate un montant avec la devise configurée
  String formatAmount(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        );
    return '$formatted $currency';
  }
}
