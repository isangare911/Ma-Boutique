import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/services/current_shop.dart';
import '../../../core/services/sync_service.dart';
import '../../models/product.dart';
import 'database_helper.dart';

class ProductDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// ⚡ Récupère le shop_id courant, ou null si non connecté
  String? get _shopId => CurrentShop.shopId;

  // ═══════════════════════════════════════════════════════════
  // CRÉER
  // ═══════════════════════════════════════════════════════════
  Future<String> insertProduct(Product product, String shopId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.insert(
      'products',
      {
        'id': product.id,
        'shop_id': shopId,
        'name': product.name,
        'reference': product.reference,
        'barcode': product.barcode,
        'category': product.category,
        'purchase_price': product.purchasePrice,
        'selling_price': product.sellingPrice,
        'quantity': product.quantity,
        'alert_threshold': product.alertThreshold,
        'unit': product.unit,
        'image_path': product.imagePath,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _addToSyncQueue(
      operationType: 'CREATE',
      entityType: 'PRODUCT',
      entityId: product.id,
      payload: _productToJson(product, shopId),
    );

    return product.id;
  }

  // ═══════════════════════════════════════════════════════════
  // LIRE (filtré par shop_id)
  // ═══════════════════════════════════════════════════════════
  Future<List<Product>> getAllProducts() async {
    final shopId = _shopId;
    if (shopId == null) return [];

    final db = await _dbHelper.database;
    final result = await db.query(
      'products',
      where: 'shop_id = ?',
      whereArgs: [shopId],
      orderBy: 'name ASC',
    );
    return result.map((map) => _productFromMap(map)).toList();
  }

  Future<Product?> getProductById(String id) async {
    final shopId = _shopId;
    if (shopId == null) return null;

    final db = await _dbHelper.database;
    final result = await db.query(
      'products',
      where: 'id = ? AND shop_id = ?',
      whereArgs: [id, shopId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return _productFromMap(result.first);
  }

  Future<List<Product>> searchProducts(String query) async {
    final shopId = _shopId;
    if (shopId == null) return [];

    final db = await _dbHelper.database;
    final result = await db.query(
      'products',
      where:
          'shop_id = ? AND (name LIKE ? OR category LIKE ? OR reference LIKE ?)',
      whereArgs: [shopId, '%$query%', '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return result.map((map) => _productFromMap(map)).toList();
  }

  Future<List<Product>> getOutOfStockProducts() async {
    final shopId = _shopId;
    if (shopId == null) return [];

    final db = await _dbHelper.database;
    final result = await db.query(
      'products',
      where: 'shop_id = ? AND quantity = 0',
      whereArgs: [shopId],
      orderBy: 'name ASC',
    );
    return result.map((map) => _productFromMap(map)).toList();
  }

  Future<List<Product>> getLowStockProducts() async {
    final shopId = _shopId;
    if (shopId == null) return [];

    final db = await _dbHelper.database;
    final result = await db.query(
      'products',
      where: 'shop_id = ? AND quantity > 0 AND quantity <= alert_threshold',
      whereArgs: [shopId],
      orderBy: 'quantity ASC',
    );
    return result.map((map) => _productFromMap(map)).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // METTRE À JOUR
  // ═══════════════════════════════════════════════════════════
  Future<void> updateProduct(Product product, String shopId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'products',
      {
        'name': product.name,
        'reference': product.reference,
        'barcode': product.barcode,
        'category': product.category,
        'purchase_price': product.purchasePrice,
        'selling_price': product.sellingPrice,
        'quantity': product.quantity,
        'alert_threshold': product.alertThreshold,
        'unit': product.unit,
        'image_path': product.imagePath,
        'updated_at': now,
      },
      where: 'id = ? AND shop_id = ?',
      whereArgs: [product.id, shopId],
    );

    await _addToSyncQueue(
      operationType: 'UPDATE',
      entityType: 'PRODUCT',
      entityId: product.id,
      payload: _productToJson(product, shopId),
    );
  }

  Future<void> decrementStock(String productId, int quantity) async {
    final shopId = _shopId;
    if (shopId == null) return;

    final db = await _dbHelper.database;
    final product = await getProductById(productId);
    if (product == null) return;

    final newQuantity = (product.quantity - quantity).clamp(0, 999999);

    await db.update(
      'products',
      {
        'quantity': newQuantity,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND shop_id = ?',
      whereArgs: [productId, shopId],
    );

    await _addToSyncQueue(
      operationType: 'UPDATE',
      entityType: 'PRODUCT',
      entityId: productId,
      payload: {'id': productId, 'shop_id': shopId, 'quantity': newQuantity},
    );
  }

  Future<void> incrementStock(String productId, int quantity) async {
    final shopId = _shopId;
    if (shopId == null) return;

    final db = await _dbHelper.database;
    final product = await getProductById(productId);
    if (product == null) return;

    final newQuantity = product.quantity + quantity;

    await db.update(
      'products',
      {
        'quantity': newQuantity,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND shop_id = ?',
      whereArgs: [productId, shopId],
    );

    await _addToSyncQueue(
      operationType: 'UPDATE',
      entityType: 'PRODUCT',
      entityId: productId,
      payload: {'id': productId, 'shop_id': shopId, 'quantity': newQuantity},
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SUPPRIMER
  // ═══════════════════════════════════════════════════════════
  Future<void> deleteProduct(String id) async {
    final shopId = _shopId;
    if (shopId == null) return;

    final db = await _dbHelper.database;
    await db.delete(
      'products',
      where: 'id = ? AND shop_id = ?',
      whereArgs: [id, shopId],
    );

    await _addToSyncQueue(
      operationType: 'DELETE',
      entityType: 'PRODUCT',
      entityId: id,
      payload: {'id': id, 'shop_id': shopId},
    );
  }

  // ═══════════════════════════════════════════════════════════
  // STATISTIQUES (filtré par shop_id)
  // ═══════════════════════════════════════════════════════════
  Future<int> getTotalProducts() async {
    final shopId = _shopId;
    if (shopId == null) return 0;

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM products WHERE shop_id = ?',
      [shopId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getOutOfStockCount() async {
    final shopId = _shopId;
    if (shopId == null) return 0;

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM products WHERE shop_id = ? AND quantity = 0',
      [shopId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<double> getTotalStockValue() async {
    final shopId = _shopId;
    if (shopId == null) return 0.0;

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(quantity * purchase_price) FROM products WHERE shop_id = ?',
      [shopId],
    );
    return (result.first.values.first as num?)?.toDouble() ?? 0.0;
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════
  Product _productFromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      reference: map['reference'] as String?,
      barcode: map['barcode'] as String?,
      category: map['category'] as String?,
      purchasePrice: (map['purchase_price'] as num).toDouble(),
      sellingPrice: (map['selling_price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      alertThreshold: map['alert_threshold'] as int? ?? 5,
      unit: map['unit'] as String?,
      imagePath: map['image_path'] as String?,
    );
  }

  Map<String, dynamic> _productToJson(Product product, String shopId) {
    return {
      'id': product.id,
      'shop_id': shopId,
      'name': product.name,
      'reference': product.reference,
      'barcode': product.barcode,
      'category': product.category,
      'purchase_price': product.purchasePrice,
      'selling_price': product.sellingPrice,
      'quantity': product.quantity,
      'alert_threshold': product.alertThreshold,
      'unit': product.unit,
    };
  }

  Future<void> _addToSyncQueue({
    required String operationType,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _dbHelper.database;
    await db.insert('sync_queue', {
      'operation_type': operationType,
      'entity_type': entityType,
      'entity_id': entityId,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'status': 'PENDING',
    });
    SyncService.instance.triggerSync();
  }
}
