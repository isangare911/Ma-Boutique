import '../../core/services/current_shop.dart';
import '../datasources/local/product_dao.dart';
import '../models/product.dart';

class ProductRepository {
  final ProductDao _dao = ProductDao();

  Future<List<Product>> getAllProducts() => _dao.getAllProducts();

  Future<Product?> getProductById(String id) => _dao.getProductById(id);

  Future<List<Product>> searchProducts(String query) =>
      _dao.searchProducts(query);

  Future<List<Product>> getOutOfStockProducts() => _dao.getOutOfStockProducts();

  Future<List<Product>> getLowStockProducts() => _dao.getLowStockProducts();

  /// ⚡ Le shopId est récupéré automatiquement depuis CurrentShop
  Future<String> addProduct(Product product) {
    final shopId = CurrentShop.shopId;
    if (shopId == null) {
      throw StateError('Aucun shop connecté');
    }
    return _dao.insertProduct(product, shopId);
  }

  Future<void> updateProduct(Product product) {
    final shopId = CurrentShop.shopId;
    if (shopId == null) {
      throw StateError('Aucun shop connecté');
    }
    return _dao.updateProduct(product, shopId);
  }

  Future<void> deleteProduct(String id) => _dao.deleteProduct(id);

  Future<void> decrementStock(String productId, int quantity) =>
      _dao.decrementStock(productId, quantity);

  Future<void> incrementStock(String productId, int quantity) =>
      _dao.incrementStock(productId, quantity);

  Future<int> getTotalProducts() => _dao.getTotalProducts();
  Future<int> getOutOfStockCount() => _dao.getOutOfStockCount();
  Future<double> getTotalStockValue() => _dao.getTotalStockValue();
}
