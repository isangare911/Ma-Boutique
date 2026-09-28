class Expense {
  final String id;
  final double amount;
  final String category;
  final String? description;
  final DateTime expenseDate;
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.amount,
    required this.category,
    this.description,
    required this.expenseDate,
    required this.createdAt,
  });

  static String generateId() {
    return 'EXP-${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Liste des catégories disponibles
  static const List<String> categories = [
    'Transport',
    'Électricité',
    'Loyer',
    'Salaire',
    'Achat marchandise',
    'Achat matériel',
    'Réparation',
    'Eau',
    'Internet',
    'Autre',
  ];

  Expense copyWith({
    String? id,
    double? amount,
    String? category,
    String? description,
    DateTime? expenseDate,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      expenseDate: expenseDate ?? this.expenseDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
