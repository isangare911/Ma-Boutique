class CashSession {
  final String id;
  final double openingBalance;
  final double? closingBalance;
  final double? theoreticalBalance;
  final double? difference;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String status; // OPEN, CLOSED

  CashSession({
    required this.id,
    required this.openingBalance,
    this.closingBalance,
    this.theoreticalBalance,
    this.difference,
    required this.openedAt,
    this.closedAt,
    this.status = 'OPEN',
  });

  bool get isOpen => status == 'OPEN';

  static String generateId() {
    return 'CASH-${DateTime.now().millisecondsSinceEpoch}';
  }

  CashSession copyWith({
    String? id,
    double? openingBalance,
    double? closingBalance,
    double? theoreticalBalance,
    double? difference,
    DateTime? openedAt,
    DateTime? closedAt,
    String? status,
  }) {
    return CashSession(
      id: id ?? this.id,
      openingBalance: openingBalance ?? this.openingBalance,
      closingBalance: closingBalance ?? this.closingBalance,
      theoreticalBalance: theoreticalBalance ?? this.theoreticalBalance,
      difference: difference ?? this.difference,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      status: status ?? this.status,
    );
  }
}
