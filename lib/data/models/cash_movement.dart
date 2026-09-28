class CashMovement {
  final String id;
  final String sessionId;
  final String type; // IN, OUT
  final double amount;
  final String category;
  final String? description;
  final DateTime createdAt;

  CashMovement({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.amount,
    required this.category,
    this.description,
    required this.createdAt,
  });

  bool get isIn => type == 'IN';
  bool get isOut => type == 'OUT';

  static String generateId() {
    return 'MOV-${DateTime.now().millisecondsSinceEpoch}';
  }
}
