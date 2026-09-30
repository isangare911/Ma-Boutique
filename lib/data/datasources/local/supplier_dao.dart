import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/services/current_shop.dart';
import '../../../core/services/sync_service.dart';
import '../../models/supplier.dart';
import '../../models/supplier_transaction.dart';
import 'database_helper.dart';

class SupplierDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  String? get _shopId => CurrentShop.shopId;

  // ═══════════════════════════════════════════════════════════
  // CRÉER
  // ═══════════════════════════════════════════════════════════
  Future<String> insertSupplier(Supplier supplier, String shopId) async {
    final db = await _dbHelper.database;
    await db.insert(
      'suppliers',
      {
        'id': supplier.id,
        'shop_id': shopId,
        'name': supplier.name,
        'phone': supplier.phone,
        'address': supplier.address,
        'products_supplied': supplier.productsSupplied,
        'notes': supplier.notes,
        'created_at': supplier.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _addToSyncQueue(
      operationType: 'CREATE',
      entityType: 'SUPPLIER',
      entityId: supplier.id,
      payload: _supplierToJson(supplier, shopId),
    );

    return supplier.id;
  }

  // ═══════════════════════════════════════════════════════════
  // LIRE
  // ═══════════════════════════════════════════════════════════
  Future<List<Supplier>> getAllSuppliers() async {
    final shopId = _shopId;
    if (shopId == null) return [];

    final db = await _dbHelper.database;
    final result = await db.query(
      'suppliers',
      where: 'shop_id = ?',
      whereArgs: [shopId],
      orderBy: 'name ASC',
    );
    return result.map((map) => _supplierFromMap(map)).toList();
  }

  Future<Supplier?> getSupplierById(String id) async {
    final shopId = _shopId;
    if (shopId == null) return null;

    final db = await _dbHelper.database;
    final result = await db.query(
      'suppliers',
      where: 'id = ? AND shop_id = ?',
      whereArgs: [id, shopId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return _supplierFromMap(result.first);
  }

  Future<List<Supplier>> searchSuppliers(String query) async {
    final shopId = _shopId;
    if (shopId == null) return [];

    final db = await _dbHelper.database;
    final result = await db.query(
      'suppliers',
      where: 'shop_id = ? AND (name LIKE ? OR phone LIKE ?)',
      whereArgs: [shopId, '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return result.map((map) => _supplierFromMap(map)).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // METTRE À JOUR
  // ═══════════════════════════════════════════════════════════
  Future<void> updateSupplier(Supplier supplier, String shopId) async {
    final db = await _dbHelper.database;
    await db.update(
      'suppliers',
      {
        'name': supplier.name,
        'phone': supplier.phone,
        'address': supplier.address,
        'products_supplied': supplier.productsSupplied,
        'notes': supplier.notes,
      },
      where: 'id = ? AND shop_id = ?',
      whereArgs: [supplier.id, shopId],
    );

    await _addToSyncQueue(
      operationType: 'UPDATE',
      entityType: 'SUPPLIER',
      entityId: supplier.id,
      payload: _supplierToJson(supplier, shopId),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SUPPRIMER
  // ═══════════════════════════════════════════════════════════
  Future<void> deleteSupplier(String id) async {
    final shopId = _shopId;
    if (shopId == null) return;

    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(
        'supplier_transactions',
        where: 'supplier_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'suppliers',
        where: 'id = ? AND shop_id = ?',
        whereArgs: [id, shopId],
      );
    });

    await _addToSyncQueue(
      operationType: 'DELETE',
      entityType: 'SUPPLIER',
      entityId: id,
      payload: {'id': id, 'shop_id': shopId},
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TRANSACTIONS
  // ═══════════════════════════════════════════════════════════
  Future<String> addTransaction(SupplierTransaction transaction) async {
    final shopId = _shopId;
    if (shopId == null) return transaction.id;

    final db = await _dbHelper.database;
    await db.insert(
      'supplier_transactions',
      {
        'id': transaction.id,
        'supplier_id': transaction.supplierId,
        'type': transaction.type,
        'amount': transaction.amount,
        'description': transaction.description,
        'transaction_date': transaction.transactionDate.toIso8601String(),
        'created_at': transaction.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _addToSyncQueue(
      operationType: 'CREATE',
      entityType: 'SUPPLIER_TRANSACTION',
      entityId: transaction.id,
      payload: _transactionToJson(transaction, shopId),
    );

    return transaction.id;
  }

  Future<List<SupplierTransaction>> getTransactionsBySupplier(
      String supplierId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'supplier_transactions',
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy: 'transaction_date DESC',
    );
    return result.map((map) => _transactionFromMap(map)).toList();
  }

  Future<void> deleteTransaction(String id) async {
    final shopId = _shopId;
    if (shopId == null) return;

    final db = await _dbHelper.database;
    await db.delete(
      'supplier_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );

    await _addToSyncQueue(
      operationType: 'DELETE',
      entityType: 'SUPPLIER_TRANSACTION',
      entityId: id,
      payload: {'id': id, 'shop_id': shopId},
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CALCUL DU SOLDE
  // ═══════════════════════════════════════════════════════════
  Future<double> getSupplierBalance(String supplierId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        SUM(CASE 
          WHEN type = 'PAYMENT' THEN -amount
          ELSE amount
        END) as balance
      FROM supplier_transactions
      WHERE supplier_id = ?
    ''', [supplierId]);

    return (result.first['balance'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, double>> getAllSuppliersBalances() async {
    final shopId = _shopId;
    if (shopId == null) return {};

    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        st.supplier_id,
        SUM(CASE 
          WHEN st.type = 'PAYMENT' THEN -st.amount
          ELSE st.amount
        END) as balance
      FROM supplier_transactions st
      INNER JOIN suppliers s ON s.id = st.supplier_id
      WHERE s.shop_id = ?
      GROUP BY st.supplier_id
    ''', [shopId]);

    final balances = <String, double>{};
    for (final row in result) {
      balances[row['supplier_id'] as String] =
          (row['balance'] as num?)?.toDouble() ?? 0.0;
    }
    return balances;
  }

  // ═══════════════════════════════════════════════════════════
  // STATISTIQUES
  // ═══════════════════════════════════════════════════════════
  Future<int> getTotalSuppliers() async {
    final shopId = _shopId;
    if (shopId == null) return 0;

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM suppliers WHERE shop_id = ?',
      [shopId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<double> getTotalDebt() async {
    final shopId = _shopId;
    if (shopId == null) return 0.0;

    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT SUM(CASE 
        WHEN st.type = 'PAYMENT' THEN -st.amount
        ELSE st.amount
      END) as total
      FROM supplier_transactions st
      INNER JOIN suppliers s ON s.id = st.supplier_id
      WHERE s.shop_id = ?
    ''', [shopId]);
    final total = (result.first['total'] as num?)?.toDouble() ?? 0.0;
    return total > 0 ? total : 0;
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════
  Supplier _supplierFromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      productsSupplied: map['products_supplied'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  SupplierTransaction _transactionFromMap(Map<String, dynamic> map) {
    return SupplierTransaction(
      id: map['id'] as String,
      supplierId: map['supplier_id'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      transactionDate: DateTime.parse(map['transaction_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> _supplierToJson(Supplier supplier, String shopId) {
    return {
      'id': supplier.id,
      'shop_id': shopId,
      'name': supplier.name,
      'phone': supplier.phone,
      'address': supplier.address,
      'products_supplied': supplier.productsSupplied,
      'notes': supplier.notes,
    };
  }

  Map<String, dynamic> _transactionToJson(
      SupplierTransaction t, String shopId) {
    return {
      'id': t.id,
      'shop_id': shopId,
      'supplier_id': t.supplierId,
      'type': t.type,
      'amount': t.amount,
      'description': t.description,
      'transaction_date': t.transactionDate.toIso8601String(),
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
