import '../../core/services/current_shop.dart';
import '../datasources/local/customer_dao.dart';
import '../models/customer.dart';

class CustomerRepository {
  final CustomerDao _dao = CustomerDao();

  Future<List<Customer>> getAllCustomers() => _dao.getAllCustomers();

  Future<Customer?> getCustomerById(String id) => _dao.getCustomerById(id);

  Future<List<Customer>> searchCustomers(String query) =>
      _dao.searchCustomers(query);

  Future<String> addCustomer(Customer customer) {
    final shopId = CurrentShop.shopId;
    if (shopId == null) {
      throw StateError('Aucun shop connecté');
    }
    return _dao.insertCustomer(customer, shopId);
  }

  Future<void> updateCustomer(Customer customer) {
    final shopId = CurrentShop.shopId;
    if (shopId == null) {
      throw StateError('Aucun shop connecté');
    }
    return _dao.updateCustomer(customer, shopId);
  }

  Future<void> deleteCustomer(String id) => _dao.deleteCustomer(id);
}
