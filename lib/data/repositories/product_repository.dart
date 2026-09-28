import '../datasources/local/product_dao.dart';
import '../models/product.dart';

class ProductRepository {
  final ProductDao _dao = ProductDao();

  // Shop ID fictif pour l'instant (à récupérer depuis les préférences après login)
  static const String _defaultShopId = 'SHOP-00001';

  Future<List<Product>> getAllProducts() => _dao.getAllProducts();

  Future<Product?> getProductById(String id) => _dao.getProductById(id);

  Future<List<Product>> searchProducts(String query) =>
      _dao.searchProducts(query);

  Future<List<Product>> getOutOfStockProducts() => _dao.getOutOfStockProducts();

  Future<List<Product>> getLowStockProducts() => _dao.getLowStockProducts();

  Future<String> addProduct(Product product) =>
      _dao.insertProduct(product, _defaultShopId);

  Future<void> updateProduct(Product product) =>
      _dao.updateProduct(product, _defaultShopId);

  Future<void> deleteProduct(String id) => _dao.deleteProduct(id);

  Future<void> decrementStock(String productId, int quantity) =>
      _dao.decrementStock(productId, quantity);

  Future<void> incrementStock(String productId, int quantity) =>
      _dao.incrementStock(productId, quantity);

  Future<int> getTotalProducts() => _dao.getTotalProducts();
  Future<int> getOutOfStockCount() => _dao.getOutOfStockCount();
  Future<double> getTotalStockValue() => _dao.getTotalStockValue();
}
