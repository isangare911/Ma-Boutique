import '../datasources/local/shop_settings_dao.dart';
import '../models/shop_settings.dart';

class ShopSettingsRepository {
  final ShopSettingsDao _dao = ShopSettingsDao();

  Future<ShopSettings> getSettings() async {
    final settings = await _dao.getSettings();
    if (settings == null) {
      // ⚡ Créer les paramètres par défaut SANS déclencher de sync
      final defaults = ShopSettings.defaults;
      await _dao.insertLocalOnly(defaults); // ⚡ Nouvelle méthode
      return defaults;
    }
    return settings;
  }

  Future<void> saveSettings(ShopSettings settings) =>
      _dao.saveSettings(settings);
}
