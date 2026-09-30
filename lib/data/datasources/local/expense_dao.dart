import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/services/current_shop.dart';
import '../../../core/services/sync_service.dart';
import '../../models/expense.dart';
import 'database_helper.dart';

class ExpenseDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  String? get _shopId => CurrentShop.shopId;

  // ═══════════════════════════════════════════════════════════
  // CRÉER
  // ═══════════════════════════════════════════════════════════
  Future<String> insertExpense(Expense expense, String shopId) async {
    final db = await _dbHelper.database;

    await db.insert(
      'expenses',
      {
        'id': expense.id,
        'shop_id': shopId,
        'amount': expense.amount,
        'category': expense.category,
        'description': expense.description,
        'expense_date': expense.expenseDate.toIso8601String(),
        'created_at': expense.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _addToSyncQueue(
      operationType: 'CREATE',
      entityType: 'EXPENSE',
      entityId: expense.id,
      payload: _expenseToJson(expense, shopId),
    );

    return expense.id;
  }

  // ═══════════════════════════════════════════════════════════
  // LIRE
  // ═══════════════════════════════════════════════════════════
  Future<List<Expense>> getAllExpenses() async {
    final shopId = _shopId;
    if (shopId == null) return [];

    final db = await _dbHelper.database;
    final result = await db.query(
      'expenses',
      where: 'shop_id = ?',
      whereArgs: [shopId],
      orderBy: 'expense_date DESC',
    );
    return result.map((map) => _expenseFromMap(map)).toList();
  }

  Future<List<Expense>> getExpensesByDateRange(
      DateTime start, DateTime end) async {
    final shopId = _shopId;
    if (shopId == null) return [];

    final db = await _dbHelper.database;
    final result = await db.query(
      'expenses',
      where: 'shop_id = ? AND expense_date BETWEEN ? AND ?',
      whereArgs: [shopId, start.toIso8601String(), end.toIso8601String()],
      orderBy: 'expense_date DESC',
    );
    return result.map((map) => _expenseFromMap(map)).toList();
  }

  Future<List<Expense>> getExpensesByCategory(String category) async {
    final shopId = _shopId;
    if (shopId == null) return [];

    final db = await _dbHelper.database;
    final result = await db.query(
      'expenses',
      where: 'shop_id = ? AND category = ?',
      whereArgs: [shopId, category],
      orderBy: 'expense_date DESC',
    );
    return result.map((map) => _expenseFromMap(map)).toList();
  }

  Future<Expense?> getExpenseById(String id) async {
    final shopId = _shopId;
    if (shopId == null) return null;

    final db = await _dbHelper.database;
    final result = await db.query(
      'expenses',
      where: 'id = ? AND shop_id = ?',
      whereArgs: [id, shopId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return _expenseFromMap(result.first);
  }

  // ═══════════════════════════════════════════════════════════
  // METTRE À JOUR
  // ═══════════════════════════════════════════════════════════
  Future<void> updateExpense(Expense expense, String shopId) async {
    final db = await _dbHelper.database;

    await db.update(
      'expenses',
      {
        'amount': expense.amount,
        'category': expense.category,
        'description': expense.description,
        'expense_date': expense.expenseDate.toIso8601String(),
      },
      where: 'id = ? AND shop_id = ?',
      whereArgs: [expense.id, shopId],
    );

    await _addToSyncQueue(
      operationType: 'UPDATE',
      entityType: 'EXPENSE',
      entityId: expense.id,
      payload: _expenseToJson(expense, shopId),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SUPPRIMER
  // ═══════════════════════════════════════════════════════════
  Future<void> deleteExpense(String id) async {
    final shopId = _shopId;
    if (shopId == null) return;

    final db = await _dbHelper.database;
    await db.delete(
      'expenses',
      where: 'id = ? AND shop_id = ?',
      whereArgs: [id, shopId],
    );

    await _addToSyncQueue(
      operationType: 'DELETE',
      entityType: 'EXPENSE',
      entityId: id,
      payload: {'id': id, 'shop_id': shopId},
    );
  }

  // ═══════════════════════════════════════════════════════════
  // STATISTIQUES
  // ═══════════════════════════════════════════════════════════
  Future<double> getTodayTotal() async {
    final shopId = _shopId;
    if (shopId == null) return 0.0;

    final db = await _dbHelper.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay =
        DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final result = await db.rawQuery(
      'SELECT SUM(amount) FROM expenses WHERE shop_id = ? AND expense_date BETWEEN ? AND ?',
      [shopId, startOfDay, endOfDay],
    );
    return (result.first.values.first as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getMonthTotal() async {
    final shopId = _shopId;
    if (shopId == null) return 0.0;

    final db = await _dbHelper.database;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

    final result = await db.rawQuery(
      'SELECT SUM(amount) FROM expenses WHERE shop_id = ? AND expense_date >= ?',
      [shopId, startOfMonth],
    );
    return (result.first.values.first as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getYearTotal() async {
    final shopId = _shopId;
    if (shopId == null) return 0.0;

    final db = await _dbHelper.database;
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1).toIso8601String();

    final result = await db.rawQuery(
      'SELECT SUM(amount) FROM expenses WHERE shop_id = ? AND expense_date >= ?',
      [shopId, startOfYear],
    );
    return (result.first.values.first as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getTotalByCategory({
    DateTime? start,
    DateTime? end,
  }) async {
    final shopId = _shopId;
    if (shopId == null) return [];

    final db = await _dbHelper.database;

    String whereClause = 'WHERE shop_id = ?';
    List<dynamic> whereArgs = [shopId];

    if (start != null && end != null) {
      whereClause += ' AND expense_date BETWEEN ? AND ?';
      whereArgs.addAll([
        start.toIso8601String(),
        end.toIso8601String(),
      ]);
    }

    final result = await db.rawQuery('''
      SELECT category, SUM(amount) as total, COUNT(*) as count
      FROM expenses
      $whereClause
      GROUP BY category
      ORDER BY total DESC
    ''', whereArgs);

    return result
        .map((row) => {
              'category': row['category'] as String,
              'total': (row['total'] as num).toDouble(),
              'count': (row['count'] as num).toInt(),
            })
        .toList();
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════
  Expense _expenseFromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      description: map['description'] as String?,
      expenseDate: DateTime.parse(map['expense_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> _expenseToJson(Expense expense, String shopId) {
    return {
      'id': expense.id,
      'shop_id': shopId,
      'amount': expense.amount,
      'category': expense.category,
      'description': expense.description,
      'expense_date': expense.expenseDate.toIso8601String(),
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
