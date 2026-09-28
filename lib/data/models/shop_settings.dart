class ShopSettings {
  final String id;
  final String shopName;
  final String? shopLogoPath;
  final String currency;
  final String? address;
  final String? phone;
  final String? email;
  final String? ownerName;
  final DateTime updatedAt;

  ShopSettings({
    required this.id,
    required this.shopName,
    this.shopLogoPath,
    this.currency = 'FCFA',
    this.address,
    this.phone,
    this.email,
    this.ownerName,
    required this.updatedAt,
  });

  static const String defaultId = 'SHOP-00001';

  /// Devises supportées
  static final List<Map<String, String>> availableCurrencies = [
    {'code': 'FCFA', 'label': 'Franc CFA (FCFA)'},
    {'code': 'EUR', 'label': 'Euro (€)'},
    {'code': 'USD', 'label': 'Dollar US (\$)'},
    {'code': 'MAD', 'label': 'Dirham marocain (MAD)'},
    {'code': 'DZD', 'label': 'Dinar algérien (DZD)'},
    {'code': 'TND', 'label': 'Dinar tunisien (TND)'},
    {'code': 'NGN', 'label': 'Naira nigérian (₦)'},
    {'code': 'GHS', 'label': 'Cedi ghanéen (₵)'},
    {'code': 'CDF', 'label': 'Franc congolais (CDF)'},
  ];

  /// Paramètres par défaut
  static ShopSettings get defaults => ShopSettings(
        id: defaultId,
        shopName: 'Ma Boutique',
        currency: 'FCFA',
        updatedAt: DateTime.now(),
      );

  ShopSettings copyWith({
    String? id,
    String? shopName,
    String? shopLogoPath,
    String? currency,
    String? address,
    String? phone,
    String? email,
    String? ownerName,
    DateTime? updatedAt,
  }) {
    return ShopSettings(
      id: id ?? this.id,
      shopName: shopName ?? this.shopName,
      shopLogoPath: shopLogoPath ?? this.shopLogoPath,
      currency: currency ?? this.currency,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      ownerName: ownerName ?? this.ownerName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
