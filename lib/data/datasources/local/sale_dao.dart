import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/services/sync_service.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import 'database_helper.dart';

class SaleDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ═══════════════════════════════════════════════════════════
  // ENREGISTRER UNE VENTE (avec décrémentation du stock)
  // ═══════════════════════════════════════════════════════════
  Future<String> insertSale(Sale sale, String shopId) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Insérer la vente
      await txn.insert('sales', {
        'id': sale.id,
        'shop_id': shopId,
        'customer_id': sale.customerId,
        'total_amount': sale.totalAmount,
        'payment_method': sale.paymentMethod,
        'status': sale.status,
        'created_at': sale.createdAt.toIso8601String(),
      });

      // 2. Insérer les articles + décrémenter le stock
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
          'UPDATE products SET quantity = MAX(0, quantity - ?) WHERE id = ?',
          [item.quantity, item.productId],
        );
      }

      // 3. Ajouter à la file de synchronisation
      await txn.insert('sync_queue', {
        'operation_type': 'CREATE',
        'entity_type': 'SALE',
        'entity_id': sale.id,
        'payload': jsonEncode(_saleToJson(sale, shopId)),
        'created_at': DateTime.now().toIso8601String(),
        'status': 'PENDING',
      });
    });

    // ⚡ Déclencher la sync automatique
    SyncService.instance.triggerSync();

    return sale.id;
  }

  // ═══════════════════════════════════════════════════════════
  // LIRE LES VENTES
  // ═══════════════════════════════════════════════════════════
  Future<List<Sale>> getAllSales() async {
    final db = await _dbHelper.database;
    final result = await db.query('sales', orderBy: 'created_at DESC');
    return result.map((map) => _saleFromMap(map)).toList();
  }

  Future<List<Sale>> getTodaySales() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay =
        DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final result = await db.query(
      'sales',
      where: 'created_at BETWEEN ? AND ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => _saleFromMap(map)).toList();
  }

  Future<Sale?> getSaleById(String id) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
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
  // STATISTIQUES DE BASE
  // ═══════════════════════════════════════════════════════════
  Future<double> getTodayRevenue() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay =
        DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final result = await db.rawQuery(
      "SELECT SUM(total_amount) FROM sales WHERE created_at BETWEEN ? AND ? AND status = 'COMPLETED'",
      [startOfDay, endOfDay],
    );
    return (result.first.values.first as num?)?.toDouble() ?? 0.0;
  }

  Future<int> getTodaySalesCount() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay =
        DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final result = await db.rawQuery(
      "SELECT COUNT(*) FROM sales WHERE created_at BETWEEN ? AND ? AND status = 'COMPLETED'",
      [startOfDay, endOfDay],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<double> getTodayProfit() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay =
        DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final result = await db.rawQuery('''
      SELECT SUM((si.unit_price - si.purchase_price) * si.quantity)
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.created_at BETWEEN ? AND ? AND s.status = 'COMPLETED'
    ''', [startOfDay, endOfDay]);

    return (result.first.values.first as num?)?.toDouble() ?? 0.0;
  }

  // ═══════════════════════════════════════════════════════════
  // ANNULER UNE VENTE
  // ═══════════════════════════════════════════════════════════
  Future<void> cancelSale(String saleId) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // Récupérer les items pour restaurer le stock
      final items = await txn.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );

      // Restaurer le stock
      for (final item in items) {
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ? WHERE id = ?',
          [item['quantity'], item['product_id']],
        );
      }

      // Marquer la vente comme annulée
      await txn.update(
        'sales',
        {'status': 'CANCELLED'},
        where: 'id = ?',
        whereArgs: [saleId],
      );

      // Ajouter à la file de synchronisation
      await txn.insert('sync_queue', {
        'operation_type': 'UPDATE',
        'entity_type': 'SALE',
        'entity_id': saleId,
        'payload': jsonEncode({'id': saleId, 'status': 'CANCELLED'}),
        'created_at': DateTime.now().toIso8601String(),
        'status': 'PENDING',
      });
    });

    // ⚡ Déclencher la sync automatique
    SyncService.instance.triggerSync();
  }

  // ═══════════════════════════════════════════════════════════
  // STATISTIQUES AVANCÉES POUR LES RAPPORTS
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getRevenueByDay(int days) async {
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
        WHERE created_at BETWEEN ? AND ? AND status = 'COMPLETED'
      ''', [startOfDay, endOfDay]);

      results.add({
        'date': day,
        'revenue': (result.first['revenue'] as num?)?.toDouble() ?? 0.0,
        'count': (result.first['count'] as num?)?.toInt() ?? 0,
      });
    }

    return results;
  }

  Future<List<Map<String, dynamic>>> getTopProducts(int limit) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        si.product_name,
        SUM(si.quantity) as total_quantity,
        SUM(si.subtotal) as total_revenue
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.status = 'COMPLETED'
      GROUP BY si.product_name
      ORDER BY total_quantity DESC
      LIMIT ?
    ''', [limit]);

    return result
        .map((row) => {
              'name': row['product_name'] as String,
              'quantity': (row['total_quantity'] as num).toInt(),
              'revenue': (row['total_revenue'] as num).toDouble(),
            })
        .toList();
  }

  Future<List<Map<String, dynamic>>> getSalesByCategory() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(p.category, 'Autre') as category,
        SUM(si.subtotal) as total_revenue
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      LEFT JOIN products p ON p.id = si.product_id
      WHERE s.status = 'COMPLETED'
      GROUP BY p.category
      ORDER BY total_revenue DESC
    ''');

    return result
        .map((row) => {
              'category': row['category'] as String,
              'revenue': (row['total_revenue'] as num).toDouble(),
            })
        .toList();
  }

  Future<List<Map<String, dynamic>>> getSalesByPaymentMethod() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        payment_method,
        SUM(total_amount) as total_amount,
        COUNT(*) as count
      FROM sales
      WHERE status = 'COMPLETED'
      GROUP BY payment_method
      ORDER BY total_amount DESC
    ''');

    return result
        .map((row) => {
              'method': row['payment_method'] as String,
              'total': (row['total_amount'] as num).toDouble(),
              'count': (row['count'] as num).toInt(),
            })
        .toList();
  }

  Future<double> getRevenueForPeriod(String period) async {
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
      WHERE created_at >= ? AND status = 'COMPLETED'
    ''', [startDate.toIso8601String()]);

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
