import '../datasources/local/customer_dao.dart';
import '../models/customer.dart';

class CustomerRepository {
  final CustomerDao _dao = CustomerDao();
  static const String _defaultShopId = 'SHOP-00001';

  Future<List<Customer>> getAllCustomers() => _dao.getAllCustomers();
  Future<Customer?> getCustomerById(String id) => _dao.getCustomerById(id);
  Future<List<Customer>> searchCustomers(String query) =>
      _dao.searchCustomers(query);
  Future<String> addCustomer(Customer customer) =>
      _dao.insertCustomer(customer, _defaultShopId);
  Future<void> updateCustomer(Customer customer) =>
      _dao.updateCustomer(customer, _defaultShopId);
  Future<void> deleteCustomer(String id) => _dao.deleteCustomer(id);
}
