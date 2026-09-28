import 'customer.dart';

class Credit {
  final String id;
  final Customer customer;
  final double totalAmount;
  final double paidAmount;
  final DateTime createdAt;
  final DateTime dueDate;
  final String? notes;

  Credit({
    required this.id,
    required this.customer,
    required this.totalAmount,
    this.paidAmount = 0,
    required this.createdAt,
    required this.dueDate,
    this.notes,
  });

  // ═══════════════════════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════════════════════

  /// Montant restant à payer
  double get remainingAmount => totalAmount - paidAmount;

  /// Le crédit est-il entièrement payé ?
  bool get isPaid => remainingAmount <= 0;

  /// Le crédit est-il en retard ? (échéance dépassée et non payé)
  bool get isOverdue => !isPaid && DateTime.now().isAfter(dueDate);

  /// Le crédit arrive-t-il bientôt à échéance ? (dans les 7 jours)
  bool get isDueSoon =>
      !isPaid &&
      !isOverdue &&
      DateTime.now().add(const Duration(days: 7)).isAfter(dueDate);

  // ═══════════════════════════════════════════════════════════
  // MÉTHODES UTILITAIRES
  // ═══════════════════════════════════════════════════════════

  /// Génère un ID unique pour un nouveau crédit
  static String generateId() {
    return 'CRED-${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Crée une copie modifiée du crédit
  Credit copyWith({
    String? id,
    Customer? customer,
    double? totalAmount,
    double? paidAmount,
    DateTime? createdAt,
    DateTime? dueDate,
    String? notes,
  }) {
    return Credit(
      id: id ?? this.id,
      customer: customer ?? this.customer,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DONNÉES MOCKÉES (pour le seed initial uniquement)
  // ═══════════════════════════════════════════════════════════
  static List<Credit> mockCredits = [
    Credit(
      id: 'CRED-001',
      customer: Customer.mockCustomers[0],
      totalAmount: 45000,
      paidAmount: 0,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      dueDate: DateTime.now().subtract(const Duration(days: 5)),
      notes: 'Riz 25kg + Huile',
    ),
    Credit(
      id: 'CRED-002',
      customer: Customer.mockCustomers[1],
      totalAmount: 12500,
      paidAmount: 0,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
      dueDate: DateTime.now().add(const Duration(days: 3)),
      notes: 'Sucre 1kg x 5',
    ),
    Credit(
      id: 'CRED-003',
      customer: Customer.mockCustomers[2],
      totalAmount: 25000,
      paidAmount: 10000,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      dueDate: DateTime.now().add(const Duration(days: 20)),
      notes: 'Lait en poudre',
    ),
    Credit(
      id: 'CRED-004',
      customer: Customer.mockCustomers[3],
      totalAmount: 15000,
      paidAmount: 0,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      dueDate: DateTime.now().add(const Duration(days: 25)),
    ),
    Credit(
      id: 'CRED-005',
      customer: Customer.mockCustomers[4],
      totalAmount: 35000,
      paidAmount: 0,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      dueDate: DateTime.now().add(const Duration(days: 28)),
      notes: 'Savon 200g x 20',
    ),
  ];
}
