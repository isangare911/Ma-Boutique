import '../datasources/local/supplier_dao.dart';
import '../models/supplier.dart';
import '../models/supplier_transaction.dart';

class SupplierRepository {
  final SupplierDao _dao = SupplierDao();
  static const String _defaultShopId = 'SHOP-00001';

  // Fournisseurs
  Future<List<Supplier>> getAllSuppliers() => _dao.getAllSuppliers();
  Future<Supplier?> getSupplierById(String id) => _dao.getSupplierById(id);
  Future<List<Supplier>> searchSuppliers(String query) =>
      _dao.searchSuppliers(query);
  Future<String> addSupplier(Supplier supplier) =>
      _dao.insertSupplier(supplier, _defaultShopId);
  Future<void> updateSupplier(Supplier supplier) =>
      _dao.updateSupplier(supplier, _defaultShopId);
  Future<void> deleteSupplier(String id) => _dao.deleteSupplier(id);

  // Transactions
  Future<String> addTransaction(SupplierTransaction transaction) =>
      _dao.addTransaction(transaction);
  Future<List<SupplierTransaction>> getTransactionsBySupplier(
          String supplierId) =>
      _dao.getTransactionsBySupplier(supplierId);
  Future<void> deleteTransaction(String id) => _dao.deleteTransaction(id);

  // Solde
  Future<double> getSupplierBalance(String supplierId) =>
      _dao.getSupplierBalance(supplierId);
  Future<Map<String, double>> getAllSuppliersBalances() =>
      _dao.getAllSuppliersBalances();

  // Stats
  Future<int> getTotalSuppliers() => _dao.getTotalSuppliers();
  Future<double> getTotalDebt() => _dao.getTotalDebt();
}
