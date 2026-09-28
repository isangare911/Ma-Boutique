class Product {
  final String id;
  final String name;
  final String? reference;
  final String? barcode;
  final String? category;
  final double purchasePrice;
  final double sellingPrice;
  final int quantity;
  final int alertThreshold;
  final String? unit;
  final String? imagePath;

  Product({
    required this.id,
    required this.name,
    this.reference,
    this.barcode,
    this.category,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.quantity,
    this.alertThreshold = 5,
    this.unit,
    this.imagePath,
  });

  // Génère un ID unique pour un nouveau produit
  static String generateId() {
    return 'PROD-${DateTime.now().millisecondsSinceEpoch}';
  }

  // Copie avec modifications (utile pour mettre à jour un produit)
  Product copyWith({
    String? id,
    String? name,
    String? reference,
    String? barcode,
    String? category,
    double? purchasePrice,
    double? sellingPrice,
    int? quantity,
    int? alertThreshold,
    String? unit,
    String? imagePath,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      reference: reference ?? this.reference,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      quantity: quantity ?? this.quantity,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      unit: unit ?? this.unit,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  // Données mockées (utilisées uniquement pour le seed initial)
  static List<Product> mockProducts = [
    Product(
      id: 'PROD-001',
      name: 'Riz 25kg',
      category: 'Alimentation',
      purchasePrice: 15000,
      sellingPrice: 18000,
      quantity: 10,
      unit: 'sac',
    ),
    Product(
      id: 'PROD-002',
      name: 'Huile 1L',
      category: 'Alimentation',
      purchasePrice: 1400,
      sellingPrice: 1700,
      quantity: 3,
      unit: 'bouteille',
    ),
    Product(
      id: 'PROD-003',
      name: 'Sucre 1kg',
      category: 'Alimentation',
      purchasePrice: 800,
      sellingPrice: 1000,
      quantity: 0,
      unit: 'paquet',
    ),
    Product(
      id: 'PROD-004',
      name: 'Lait en poudre 400g',
      category: 'Boissons',
      purchasePrice: 2000,
      sellingPrice: 2500,
      quantity: 12,
      unit: 'boîte',
    ),
    Product(
      id: 'PROD-005',
      name: 'Savon 200g',
      category: 'Hygiène',
      purchasePrice: 400,
      sellingPrice: 500,
      quantity: 3,
      unit: 'pièce',
    ),
    Product(
      id: 'PROD-006',
      name: 'Coca-Cola 1.5L',
      category: 'Boissons',
      purchasePrice: 500,
      sellingPrice: 700,
      quantity: 24,
      unit: 'bouteille',
    ),
  ];
}
