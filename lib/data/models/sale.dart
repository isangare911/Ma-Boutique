import 'sale_item.dart';

class Sale {
  final String id;
  final String? customerId;
  final String? customerName;
  final double totalAmount;
  final double totalProfit;
  final String paymentMethod;
  final String status; // COMPLETED, CANCELLED
  final DateTime createdAt;
  final List<SaleItem> items;

  Sale({
    required this.id,
    this.customerId,
    this.customerName,
    required this.totalAmount,
    required this.totalProfit,
    required this.paymentMethod,
    this.status = 'COMPLETED',
    required this.createdAt,
    this.items = const [],
  });

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  static String generateId() {
    return 'SALE-${DateTime.now().millisecondsSinceEpoch}';
  }
}
