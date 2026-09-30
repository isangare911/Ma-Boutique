class CurrentShop {
  CurrentShop._();

  static String? _shopId;

  /// Le shop_id de l'utilisateur actuellement connecté.
  /// `null` si aucun utilisateur n'est connecté.
  static String? get shopId => _shopId;

  /// Vérifie si un shop est actif
  static bool get isSet => _shopId != null;

  /// Définit le shop courant (à appeler au login)
  static void set(String? id) {
    _shopId = id;
  }

  /// Efface le shop courant (à appeler au logout)
  static void clear() {
    _shopId = null;
  }
}
