import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/services/sync_service.dart';
import '../../models/supplier.dart';
import '../../models/supplier_transaction.dart';
import 'database_helper.dart';

class SupplierDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

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
      payload: _supplierToJson(supplier),
    );

    return supplier.id;
  }

  // ═══════════════════════════════════════════════════════════
  // LIRE
  // ═══════════════════════════════════════════════════════════
  Future<List<Supplier>> getAllSuppliers() async {
    final db = await _dbHelper.database;
    final result = await db.query('suppliers', orderBy: 'name ASC');
    return result.map((map) => _supplierFromMap(map)).toList();
  }

  Future<Supplier?> getSupplierById(String id) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return _supplierFromMap(result.first);
  }

  Future<List<Supplier>> searchSuppliers(String query) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'suppliers',
      where: 'name LIKE ? OR phone LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
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
      where: 'id = ?',
      whereArgs: [supplier.id],
    );

    await _addToSyncQueue(
      operationType: 'UPDATE',
      entityType: 'SUPPLIER',
      entityId: supplier.id,
      payload: _supplierToJson(supplier),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SUPPRIMER
  // ═══════════════════════════════════════════════════════════
  Future<void> deleteSupplier(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Supprimer d'abord les transactions liées
      await txn.delete(
        'supplier_transactions',
        where: 'supplier_id = ?',
        whereArgs: [id],
      );
      // Puis le fournisseur
      await txn.delete('suppliers', where: 'id = ?', whereArgs: [id]);
    });

    await _addToSyncQueue(
      operationType: 'DELETE',
      entityType: 'SUPPLIER',
      entityId: id,
      payload: {'id': id},
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TRANSACTIONS
  // ═══════════════════════════════════════════════════════════
  Future<String> addTransaction(SupplierTransaction transaction) async {
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
      payload: _transactionToJson(transaction),
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
      payload: {'id': id},
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CALCUL DU SOLDE
  // ═══════════════════════════════════════════════════════════
  /// Calcule le solde dû à un fournisseur (positif = on lui doit)
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

  /// Récupère le solde pour plusieurs fournisseurs en une fois
  Future<Map<String, double>> getAllSuppliersBalances() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        supplier_id,
        SUM(CASE 
          WHEN type = 'PAYMENT' THEN -amount
          ELSE amount
        END) as balance
      FROM supplier_transactions
      GROUP BY supplier_id
    ''');

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
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM suppliers');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<double> getTotalDebt() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT SUM(CASE 
        WHEN type = 'PAYMENT' THEN -amount
        ELSE amount
      END) as total
      FROM supplier_transactions
    ''');
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

  Map<String, dynamic> _supplierToJson(Supplier supplier) {
    return {
      'id': supplier.id,
      'name': supplier.name,
      'phone': supplier.phone,
      'address': supplier.address,
      'products_supplied': supplier.productsSupplied,
      'notes': supplier.notes,
    };
  }

  Map<String, dynamic> _transactionToJson(SupplierTransaction t) {
    return {
      'id': t.id,
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
    // ⚡ Déclencher la sync automatique
    SyncService.instance.triggerSync();
  }
}
