import 'package:flutter/foundation.dart';

import '../../data/models/shop_settings.dart';
import '../../data/repositories/shop_settings_repository.dart';
import 'auth_service.dart';
import 'current_shop.dart';

class ShopSettingsService extends ChangeNotifier {
  static final ShopSettingsService instance = ShopSettingsService._();
  ShopSettingsService._();

  final ShopSettingsRepository _repository = ShopSettingsRepository();

  ShopSettings? _settings;
  bool _isLoaded = false;

  /// ⚡ Retourne les settings ou une valeur par défaut
  ShopSettings get settings => _settings ?? _defaultFallback();

  String get currency => settings.currency;
  String get shopName => settings.shopName;
  String? get shopLogoPath => settings.shopLogoPath;
  bool get isLoaded => _isLoaded;

  /// ⚡ Fallback si les settings ne sont pas encore chargés
  ShopSettings _defaultFallback() {
    final shopId = CurrentShop.shopId ?? 'UNKNOWN';
    final user = AuthService.instance.user;
    final serverName = user?['shop']?['name'] as String?;
    return ShopSettings.forShop(shopId, shopName: serverName);
  }

  // ═══════════════════════════════════════════════════════════
  // INITIALISATION
  // ═══════════════════════════════════════════════════════════
  Future<void> initialize() async {
    try {
      // ⚡ 1. Charger depuis la base locale (par shop_id)
      final local = await _repository.getSettings();

      if (local != null) {
        _settings = local;
        debugPrint('🔍 Settings chargés du cache : ${local.shopName}');
      } else {
        // ⚡ 2. Pas en cache → créer depuis les données serveur
        final user = AuthService.instance.user;
        final shopData = user?['shop'] as Map<String, dynamic>?;
        final shopId = shopData?['id'] as String?;

        if (shopId == null) {
          debugPrint('⚠ Aucun shop_id → settings par défaut');
          _settings = _defaultFallback();
        } else {
          // ⚡ Pré-remplir avec les données du serveur
          final freshSettings = ShopSettings(
            id: shopId,
            shopId: shopId,
            shopName: shopData?['name'] as String? ?? 'Ma Boutique',
            currency: shopData?['currency'] as String? ?? 'FCFA',
            address: shopData?['address'] as String?,
            phone: shopData?['phone'] as String?,
            email: shopData?['email'] as String?,
            ownerName: shopData?['owner_name'] as String?,
            shopLogoPath: shopData?['logo_path'] as String?,
            updatedAt: DateTime.now(),
          );

          // Sauvegarder localement SANS sync (pas de modif serveur)
          await _repository.saveSettingsLocalOnly(freshSettings);
          _settings = freshSettings;
          debugPrint(
              '🔍 Settings initialisés depuis le serveur : ${freshSettings.shopName}');
        }
      }

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur chargement paramètres: $e');
      _settings = _defaultFallback();
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// ⚡ Recharge après changement d'utilisateur (login/logout)
  Future<void> reload() async {
    _settings = null;
    _isLoaded = false;
    await initialize();
  }

  // ═══════════════════════════════════════════════════════════
  // MISE À JOUR
  // ═══════════════════════════════════════════════════════════
  Future<void> updateSettings(ShopSettings newSettings) async {
    final shopId = CurrentShop.shopId;
    if (shopId == null) {
      throw StateError('Aucun shop connecté');
    }

    final updated = newSettings.copyWith(
      id: shopId,
      shopId: shopId,
    );

    await _repository.saveSettings(updated);
    _settings = updated;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  // FORMATAGE
  // ═══════════════════════════════════════════════════════════
  String formatAmount(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        );
    return '$formatted $currency';
  }
}
