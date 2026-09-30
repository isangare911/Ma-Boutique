import '../datasources/local/shop_settings_dao.dart';
import '../models/shop_settings.dart';

class ShopSettingsRepository {
  final ShopSettingsDao _dao = ShopSettingsDao();

  /// ⚡ Retourne les settings du shop courant, ou null si aucun
  Future<ShopSettings?> getSettings() async {
    return await _dao.getSettings();
  }

  /// ⚡ Sauvegarde locale SANS sync (pour initialisation)
  Future<void> saveSettingsLocalOnly(ShopSettings settings) =>
      _dao.insertLocalOnly(settings);

  /// ⚡ Sauvegarde + sync vers le serveur
  Future<void> saveSettings(ShopSettings settings) =>
      _dao.saveSettings(settings);
}
