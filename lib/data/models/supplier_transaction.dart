class SupplierTransaction {
  final String id;
  final String supplierId;
  final String type; // PURCHASE (achat), PAYMENT (paiement), DEBT (dette)
  final double amount;
  final String? description;
  final DateTime transactionDate;
  final DateTime createdAt;

  SupplierTransaction({
    required this.id,
    required this.supplierId,
    required this.type,
    required this.amount,
    this.description,
    required this.transactionDate,
    required this.createdAt,
  });

  bool get isPurchase => type == 'PURCHASE';
  bool get isPayment => type == 'PAYMENT';
  bool get isDebt => type == 'DEBT';

  static String generateId() {
    return 'STR-${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Signe pour le calcul du solde :
  /// - PURCHASE et DEBT augmentent ce qu'on doit au fournisseur
  /// - PAYMENT réduit ce qu'on doit
  double get signedAmount {
    if (type == 'PAYMENT') return -amount;
    return amount;
  }
}
