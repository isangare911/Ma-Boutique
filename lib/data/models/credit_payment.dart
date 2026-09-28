class CreditPayment {
  final String id;
  final String creditId;
  final double amount;
  final DateTime date;
  final String paymentMethod;
  final String? comment;

  CreditPayment({
    required this.id,
    required this.creditId,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    this.comment,
  });

  // ═══════════════════════════════════════════════════════════
  // MÉTHODES UTILITAIRES
  // ═══════════════════════════════════════════════════════════

  /// Génère un ID unique pour un nouveau paiement
  static String generateId() {
    return 'PAY-${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Crée une copie modifiée du paiement
  CreditPayment copyWith({
    String? id,
    String? creditId,
    double? amount,
    DateTime? date,
    String? paymentMethod,
    String? comment,
  }) {
    return CreditPayment(
      id: id ?? this.id,
      creditId: creditId ?? this.creditId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      comment: comment ?? this.comment,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DONNÉES MOCKÉES (pour le seed initial uniquement)
  // ═══════════════════════════════════════════════════════════
  static List<CreditPayment> mockPayments = [
    CreditPayment(
      id: 'PAY-001',
      creditId: 'CRED-003',
      amount: 10000,
      date: DateTime.now().subtract(const Duration(days: 5)),
      paymentMethod: 'Espèces',
      comment: 'Premier remboursement',
    ),
  ];
}
