import '../../core/services/current_shop.dart';
import '../datasources/local/sale_dao.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';

class SaleRepository {
  final SaleDao _dao = SaleDao();

  Future<List<Sale>> getAllSales() => _dao.getAllSales();

  Future<List<Sale>> getTodaySales() => _dao.getTodaySales();

  Future<Sale?> getSaleById(String id) => _dao.getSaleById(id);

  Future<List<SaleItem>> getSaleItems(String saleId) =>
      _dao.getSaleItems(saleId);

  Future<String> addSale(Sale sale) {
    final shopId = CurrentShop.shopId;
    if (shopId == null) {
      throw StateError('Aucun shop connecté');
    }
    return _dao.insertSale(sale, shopId);
  }

  Future<void> cancelSale(String saleId) => _dao.cancelSale(saleId);

  Future<double> getTodayRevenue() => _dao.getTodayRevenue();
  Future<int> getTodaySalesCount() => _dao.getTodaySalesCount();
  Future<double> getTodayProfit() => _dao.getTodayProfit();

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
