class SaleItem {
  final String id;
  final String saleId;
  final String productId;
  final String
      productName; // Dénormalisé pour l'historique (au cas où le produit est supprimé)
  final double unitPrice;
  final double purchasePrice; // Pour calculer le bénéfice
  final int quantity;

  SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.purchasePrice,
    required this.quantity,
  });

  double get subtotal => unitPrice * quantity;
  double get profit => (unitPrice - purchasePrice) * quantity;

  static String generateId() {
    return 'ITEM-${DateTime.now().microsecondsSinceEpoch}';
  }
}
