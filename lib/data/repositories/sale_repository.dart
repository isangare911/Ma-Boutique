import '../datasources/local/sale_dao.dart';
import '../models/sale.dart';

class SaleRepository {
  final SaleDao _dao = SaleDao();
  static const String _defaultShopId = 'SHOP-00001';

  Future<String> addSale(Sale sale) => _dao.insertSale(sale, _defaultShopId);

  Future<List<Sale>> getAllSales() => _dao.getAllSales();

  Future<List<Sale>> getTodaySales() => _dao.getTodaySales();

  Future<Sale?> getSaleById(String id) => _dao.getSaleById(id);

  Future<void> cancelSale(String saleId) => _dao.cancelSale(saleId);

  // Statistiques
  Future<double> getTodayRevenue() => _dao.getTodayRevenue();
  Future<int> getTodaySalesCount() => _dao.getTodaySalesCount();
  Future<double> getTodayProfit() => _dao.getTodayProfit();
  // Statistiques avancées
  Future<List<Map<String, dynamic>>> getRevenueByDay(int days) =>
      _dao.getRevenueByDay(days);

  Future<List<Map<String, dynamic>>> getTopProducts(int limit) =>
      _dao.getTopProducts(limit);

  Future<List<Map<String, dynamic>>> getSalesByCategory() =>
      _dao.getSalesByCategory();

  Future<List<Map<String, dynamic>>> getSalesByPaymentMethod() =>
      _dao.getSalesByPaymentMethod();

  Future<double> getRevenueForPeriod(String period) =>
      _dao.getRevenueForPeriod(period);
}
