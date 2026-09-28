import '../../models/credit.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import 'credit_dao.dart';
import 'customer_dao.dart';
import 'product_dao.dart';

class SeedData {
  static Future<void> seedIfEmpty() async {
    const shopId = 'SHOP-00001';

    // Produits
    final productDao = ProductDao();
    if (await productDao.getTotalProducts() == 0) {
      for (final product in Product.mockProducts) {
        await productDao.insertProduct(product, shopId);
      }
    }

    // Clients
    final customerDao = CustomerDao();
    final existingCustomers = await customerDao.getAllCustomers();
    if (existingCustomers.isEmpty) {
      for (final customer in Customer.mockCustomers) {
        await customerDao.insertCustomer(customer, shopId);
      }

      // Crédits de test (basés sur les clients mockés)
      final creditDao = CreditDao();
      final mockCredits = [
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

      for (final credit in mockCredits) {
        await creditDao.insertCredit(credit, shopId);
      }
    }
  }
}
