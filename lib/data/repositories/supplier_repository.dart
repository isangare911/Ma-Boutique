import '../../core/services/current_shop.dart';
import '../datasources/local/supplier_dao.dart';
import '../models/supplier.dart';
import '../models/supplier_transaction.dart';

class SupplierRepository {
  final SupplierDao _dao = SupplierDao();

  Future<List<Supplier>> getAllSuppliers() => _dao.getAllSuppliers();

  Future<Supplier?> getSupplierById(String id) => _dao.getSupplierById(id);

  Future<List<Supplier>> searchSuppliers(String query) =>
      _dao.searchSuppliers(query);

  Future<String> addSupplier(Supplier supplier) {
    final shopId = CurrentShop.shopId;
    if (shopId == null) {
      throw StateError('Aucun shop connecté');
    }
    return _dao.insertSupplier(supplier, shopId);
  }

  Future<void> updateSupplier(Supplier supplier) {
    final shopId = CurrentShop.shopId;
    if (shopId == null) {
      throw StateError('Aucun shop connecté');
    }
    return _dao.updateSupplier(supplier, shopId);
  }

  Future<void> deleteSupplier(String id) => _dao.deleteSupplier(id);

  Future<String> addTransaction(SupplierTransaction transaction) =>
      _dao.addTransaction(transaction);

  Future<List<SupplierTransaction>> getTransactionsBySupplier(
          String supplierId) =>
      _dao.getTransactionsBySupplier(supplierId);

  Future<void> deleteTransaction(String id) => _dao.deleteTransaction(id);

  Future<double> getSupplierBalance(String supplierId) =>
      _dao.getSupplierBalance(supplierId);

  Future<Map<String, double>> getAllSuppliersBalances() =>
      _dao.getAllSuppliersBalances();

  Future<int> getTotalSuppliers() => _dao.getTotalSuppliers();
  Future<double> getTotalDebt() => _dao.getTotalDebt();
}
