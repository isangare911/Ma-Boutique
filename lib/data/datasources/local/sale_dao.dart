import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/services/current_shop.dart';
import '../../../core/services/sync_service.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import 'database_helper.dart';

class SaleDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  String? get _shopId => CurrentShop.shopId;

  // ═══════════════════════════════════════════════════════════
  // ENREGISTRER UNE VENTE
  // ═══════════════════════════════════════════════════════════
  Future<String> insertSale(Sale sale, String shopId) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      await txn.insert('sales', {
        'id': sale.id,
        'shop_id': shopId,
        'customer_id': sale.customerId,
        'total_amount': sale.totalAmount,
        'payment_method': sale.paymentMethod,
        'status': sale.status,
        'created_at': sale.createdAt.toIso8601String(),
      });

      for (final item in sale.items) {
        await txn.insert('sale_items', {
          'id': item.id,
          'sale_id': sale.id,
          'product_id': item.productId,
          'product_name': item.productName,
          'unit_price': item.unitPrice,
          'purchase_price': item.purchasePrice,
          'quantity': item.quantity,
          'subtotal': item.subtotal,
        });

        await txn.rawUpdate(
          'UPDATE products SET quantity = MAX(0, quantity - ?) WHERE id = ? AND shop_id = ?',
          [item.quantity, item.productId, shopId],
        );
      }

      await txn.insert('sync_queue', {
        'operation_type': 'CREATE',
        'entity_type': 'SALE',
        'entity_id': sale.id,
        'payload': jsonEncode(_saleToJson(sale, shopId)),
        'created_at': DateTime.now().toIso8601String(),
        'status': 'PENDING',
      });
    });

    SyncService.instance.triggerSync();
    return sale.id;
  }

  // ═══════════════════════════════════════════════════════════
  // LIRE
  // ═══════════════════════════════════════════════════════════
  Future<List<Sale>> getAllSales() async {
    final shopId = _shopId;
    if (shopId == null) return [];

    final db = await _dbHelper.database;
    final result = await db.query(
      'sales',
      where: 'shop_id = ?',
      whereArgs: [shopId],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => _saleFromMap(map)).toList();
  }

  Future<List<Sale>> getTodaySales() async {
    final shopId = _shopId;
    if (shopId == null) return [];

    final db = await _dbHelper.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay =
        DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final result = await db.query(
      'sales',
      where: 'shop_id = ? AND created_at BETWEEN ? AND ?',
      whereArgs: [shopId, startOfDay, endOfDay],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => _saleFromMap(map)).toList();
  }

  Future<Sale?> getSaleById(String id) async {
    final shopId = _shopId;
    if (shopId == null) return null;

    final db = await _dbHelper.database;
    final result = await db.query(
      'sales',
      where: 'id = ? AND shop_id = ?',
      whereArgs: [id, shopId],
      limit: 1,
    );
    if (result.isEmpty) return null;

    final sale = _saleFromMap(result.first);
    final items = await getSaleItems(id);
    return Sale(
      id: sale.id,
      customerId: sale.customerId,
      customerName: sale.customerName,
      totalAmount: sale.totalAmount,
      totalProfit: sale.totalProfit,
      paymentMethod: sale.paymentMethod,
      status: sale.status,
      createdAt: sale.createdAt,
      items: items,
    );
  }

  Future<List<SaleItem>> getSaleItems(String saleId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
    return result.map((map) => _saleItemFromMap(map)).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // STATISTIQUES
  // ═══════════════════════════════════════════════════════════
  Future<double> getTodayRevenue() async {
    final shopId = _shopId;
    if (shopId == null) return 0.0;

    final db = await _dbHelper.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay =
        DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final result = await db.rawQuery(
      "SELECT SUM(total_amount) FROM sales WHERE shop_id = ? AND created_at BETWEEN ? AND ? AND status = 'COMPLETED'",
      [shopId, startOfDay, endOfDay],
    );
    return (result.first.values.first as num?)?.toDouble() ?? 0.0;
  }

  Future<int> getTodaySalesCount() async {
    final shopId = _shopId;
    if (shopId == null) return 0;

    final db = await _dbHelper.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay =
        DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final result = await db.rawQuery(
      "SELECT COUNT(*) FROM sales WHERE shop_id = ? AND created_at BETWEEN ? AND ? AND status = 'COMPLETED'",
      [shopId, startOfDay, endOfDay],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<double> getTodayProfit() async {
    final shopId = _shopId;
    if (shopId == null) return 0.0;

    final db = await _dbHelper.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay =
        DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final result = await db.rawQuery('''
      SELECT SUM((si.unit_price - si.purchase_price) * si.quantity)
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.shop_id = ? AND s.created_at BETWEEN ? AND ? AND s.status = 'COMPLETED'
    ''', [shopId, startOfDay, endOfDay]);

    return (result.first.values.first as num?)?.toDouble() ?? 0.0;
  }

  // ═══════════════════════════════════════════════════════════
  // ANNULER UNE VENTE
  // ═══════════════════════════════════════════════════════════
  Future<void> cancelSale(String saleId) async {
    final shopId = _shopId;
    if (shopId == null) return;

    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      final items = await txn.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );

      for (final item in items) {
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ? WHERE id = ? AND shop_id = ?',
          [item['quantity'], item['product_id'], shopId],
        );
      }

      await txn.update(
        'sales',
        {'status': 'CANCELLED'},
        where: 'id = ? AND shop_id = ?',
        whereArgs: [saleId, shopId],
      );

      await txn.insert('sync_queue', {
        'operation_type': 'UPDATE',
        'entity_type': 'SALE',
        'entity_id': saleId,
        'payload': jsonEncode({
          'id': saleId,
          'shop_id': shopId,
          'status': 'CANCELLED',
        }),
        'created_at': DateTime.now().toIso8601String(),
        'status': 'PENDING',
      });
    });

    SyncService.instance.triggerSync();
  }

  // ═══════════════════════════════════════════════════════════
  // STATISTIQUES AVANCÉES
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getRevenueByDay(int days) async {
    final shopId = _shopId;
    if (shopId == null) return [];

    final db = await _dbHelper.database;
    final now = DateTime.now();
    final results = <Map<String, dynamic>>[];

    for (int i = days - 1; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final startOfDay =
          DateTime(day.year, day.month, day.day).toIso8601String();
      final endOfDay =
          DateTime(day.year, day.month, day.day, 23, 59, 59).toIso8601String();

      final result = await db.rawQuery('''
        SELECT SUM(total_amount) as revenue, COUNT(*) as count
        FROM sales
        WHERE shop_id = ? AND created_at BETWEEN ? AND ? AND status = 'COMPLETED'
      ''', [shopId, startOfDay, endOfDay]);

      results.add({
        'date': day,
        'revenue': (result.first['revenue'] as num?)?.toDouble() ?? 0.0,
        'count': (result.first['count'] as num?)?.toInt() ?? 0,
      });
    }

    return results;
  }

  Future<List<Map<String, dynamic>>> getTopProducts(int limit) async {
    final shopId = _shopId;
    if (shopId == null) return [];

    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        si.product_name,
        SUM(si.quantity) as total_quantity,
        SUM(si.subtotal) as total_revenue
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.shop_id = ? AND s.status = 'COMPLETED'
      GROUP BY si.product_name
      ORDER BY total_quantity DESC
      LIMIT ?
    ''', [shopId, limit]);

    return result
        .map((row) => {
              'name': row['product_name'] as String,
              'quantity': (row['total_quantity'] as num).toInt(),
              'revenue': (row['total_revenue'] as num).toDouble(),
            })
        .toList();
  }

  Future<List<Map<String, dynamic>>> getSalesByCategory() async {
    final shopId = _shopId;
    if (shopId == null) return [];

    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(p.category, 'Autre') as category,
        SUM(si.subtotal) as total_revenue
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      LEFT JOIN products p ON p.id = si.product_id
      WHERE s.shop_id = ? AND s.status = 'COMPLETED'
      GROUP BY p.category
      ORDER BY total_revenue DESC
    ''', [shopId]);

    return result
        .map((row) => {
              'category': row['category'] as String,
              'revenue': (row['total_revenue'] as num).toDouble(),
            })
        .toList();
  }

  Future<List<Map<String, dynamic>>> getSalesByPaymentMethod() async {
    final shopId = _shopId;
    if (shopId == null) return [];

    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        payment_method,
        SUM(total_amount) as total_amount,
        COUNT(*) as count
      FROM sales
      WHERE shop_id = ? AND status = 'COMPLETED'
      GROUP BY payment_method
      ORDER BY total_amount DESC
    ''', [shopId]);

    return result
        .map((row) => {
              'method': row['payment_method'] as String,
              'total': (row['total_amount'] as num).toDouble(),
              'count': (row['count'] as num).toInt(),
            })
        .toList();
  }

  Future<double> getRevenueForPeriod(String period) async {
    final shopId = _shopId;
    if (shopId == null) return 0.0;

    final db = await _dbHelper.database;
    final now = DateTime.now();
    DateTime startDate;

    switch (period) {
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'year':
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    final result = await db.rawQuery('''
      SELECT SUM(total_amount) FROM sales
      WHERE shop_id = ? AND created_at >= ? AND status = 'COMPLETED'
    ''', [shopId, startDate.toIso8601String()]);

    return (result.first.values.first as num?)?.toDouble() ?? 0.0;
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════
  Sale _saleFromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as String,
      customerId: map['customer_id'] as String?,
      totalAmount: (map['total_amount'] as num).toDouble(),
      totalProfit: 0,
      paymentMethod: map['payment_method'] as String,
      status: map['status'] as String? ?? 'COMPLETED',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  SaleItem _saleItemFromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as String,
      saleId: map['sale_id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      unitPrice: (map['unit_price'] as num).toDouble(),
      purchasePrice: (map['purchase_price'] as num).toDouble(),
      quantity: map['quantity'] as int,
    );
  }

  Map<String, dynamic> _saleToJson(Sale sale, String shopId) {
    return {
      'id': sale.id,
      'shop_id': shopId,
      'customer_id': sale.customerId,
      'total_amount': sale.totalAmount,
      'payment_method': sale.paymentMethod,
      'status': sale.status,
      'created_at': sale.createdAt.toIso8601String(),
      'items': sale.items
          .map((i) => {
                'id': i.id,
                'product_id': i.productId,
                'product_name': i.productName,
                'unit_price': i.unitPrice,
                'purchase_price': i.purchasePrice,
                'quantity': i.quantity,
              })
          .toList(),
    };
  }
}
