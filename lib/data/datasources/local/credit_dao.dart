import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/services/current_shop.dart';
import '../../../core/services/sync_service.dart';
import '../../models/credit.dart';
import '../../models/credit_payment.dart';
import '../../models/customer.dart';
import 'database_helper.dart';

class CreditDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  String? get _shopId => CurrentShop.shopId;

  // ═══════════════════════════════════════════════════════════
  // CRÉER UN CRÉDIT
  // ═══════════════════════════════════════════════════════════
  Future<String> insertCredit(Credit credit, String shopId) async {
    final db = await _dbHelper.database;
    await db.insert(
      'credits',
      {
        'id': credit.id,
        'shop_id': shopId,
        'customer_id': credit.customer.id,
        'total_amount': credit.totalAmount,
        'paid_amount': credit.paidAmount,
        'created_at': credit.createdAt.toIso8601String(),
        'due_date': credit.dueDate.toIso8601String(),
        'notes': credit.notes,
        'status': credit.isPaid ? 'PAID' : 'ACTIVE',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _addToSyncQueue(
      operationType: 'CREATE',
      entityType: 'CREDIT',
      entityId: credit.id,
      payload: _creditToJson(credit, shopId),
    );

    return credit.id;
  }

  // ═══════════════════════════════════════════════════════════
  // LIRE
  // ═══════════════════════════════════════════════════════════
  Future<List<Credit>> getAllCredits() async {
    final shopId = _shopId;
    if (shopId == null) return [];

    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT c.*, 
             cu.name as customer_name, 
             cu.phone as customer_phone, 
             cu.address as customer_address
      FROM credits c
      INNER JOIN customers cu ON cu.id = c.customer_id
      WHERE c.shop_id = ?
      ORDER BY c.created_at DESC
    ''', [shopId]);
    return result.map((map) => _creditFromMap(map)).toList();
  }

  Future<Credit?> getCreditById(String id) async {
    final shopId = _shopId;
    if (shopId == null) return null;

    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT c.*, 
             cu.name as customer_name, 
             cu.phone as customer_phone, 
             cu.address as customer_address
      FROM credits c
      INNER JOIN customers cu ON cu.id = c.customer_id
      WHERE c.id = ? AND c.shop_id = ?
      LIMIT 1
    ''', [id, shopId]);
    if (result.isEmpty) return null;
    return _creditFromMap(result.first);
  }

  Future<List<Credit>> getCreditsByCustomer(String customerId) async {
    final shopId = _shopId;
    if (shopId == null) return [];

    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT c.*, 
             cu.name as customer_name, 
             cu.phone as customer_phone, 
             cu.address as customer_address
      FROM credits c
      INNER JOIN customers cu ON cu.id = c.customer_id
      WHERE c.customer_id = ? AND c.shop_id = ?
      ORDER BY c.created_at DESC
    ''', [customerId, shopId]);
    return result.map((map) => _creditFromMap(map)).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // REMBOURSER UN CRÉDIT
  // ═══════════════════════════════════════════════════════════
  Future<void> addPayment(CreditPayment payment, String shopId) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      await txn.insert('credit_payments', {
        'id': payment.id,
        'credit_id': payment.creditId,
        'amount': payment.amount,
        'payment_method': payment.paymentMethod,
        'payment_date': payment.date.toIso8601String(),
        'comment': payment.comment,
      });

      final creditResult = await txn.query(
        'credits',
        where: 'id = ? AND shop_id = ?',
        whereArgs: [payment.creditId, shopId],
        limit: 1,
      );

      if (creditResult.isNotEmpty) {
        final currentPaid =
            (creditResult.first['paid_amount'] as num).toDouble();
        final totalAmount =
            (creditResult.first['total_amount'] as num).toDouble();
        final newPaid = currentPaid + payment.amount;
        final isFullyPaid = newPaid >= totalAmount;

        await txn.update(
          'credits',
          {
            'paid_amount': newPaid,
            'status': isFullyPaid ? 'PAID' : 'ACTIVE',
          },
          where: 'id = ? AND shop_id = ?',
          whereArgs: [payment.creditId, shopId],
        );

        await txn.insert('sync_queue', {
          'operation_type': 'CREATE',
          'entity_type': 'CREDIT_PAYMENT',
          'entity_id': payment.id,
          'payload': jsonEncode({
            'id': payment.id,
            'credit_id': payment.creditId,
            'shop_id': shopId,
            'amount': payment.amount,
            'payment_method': payment.paymentMethod,
            'date': payment.date.toIso8601String(),
          }),
          'created_at': DateTime.now().toIso8601String(),
          'status': 'PENDING',
        });
      }
    });

    SyncService.instance.triggerSync();
  }

  // ═══════════════════════════════════════════════════════════
  // LIRE LES PAIEMENTS
  // ═══════════════════════════════════════════════════════════
  Future<List<CreditPayment>> getPaymentsByCredit(String creditId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'credit_payments',
      where: 'credit_id = ?',
      whereArgs: [creditId],
      orderBy: 'payment_date DESC',
    );
    return result.map((map) => _paymentFromMap(map)).toList();
  }

  Future<List<CreditPayment>> getAllPayments() async {
    final shopId = _shopId;
    if (shopId == null) return [];

    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT cp.*
      FROM credit_payments cp
      INNER JOIN credits c ON c.id = cp.credit_id
      WHERE c.shop_id = ?
      ORDER BY cp.payment_date DESC
    ''', [shopId]);
    return result.map((map) => _paymentFromMap(map)).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // STATISTIQUES
  // ═══════════════════════════════════════════════════════════
  Future<double> getTotalCreditAmount() async {
    final shopId = _shopId;
    if (shopId == null) return 0.0;

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      "SELECT SUM(total_amount) FROM credits WHERE shop_id = ? AND status = 'ACTIVE'",
      [shopId],
    );
    return (result.first.values.first as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalRemainingAmount() async {
    final shopId = _shopId;
    if (shopId == null) return 0.0;

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      "SELECT SUM(total_amount - paid_amount) FROM credits WHERE shop_id = ? AND status = 'ACTIVE'",
      [shopId],
    );
    return (result.first.values.first as num?)?.toDouble() ?? 0.0;
  }

  Future<int> getOverdueCount() async {
    final shopId = _shopId;
    if (shopId == null) return 0;

    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final result = await db.rawQuery(
      "SELECT COUNT(*) FROM credits WHERE shop_id = ? AND status = 'ACTIVE' AND due_date < ?",
      [shopId, now],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<double> getTotalPaymentsReceived() async {
    final shopId = _shopId;
    if (shopId == null) return 0.0;

    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT SUM(cp.amount)
      FROM credit_payments cp
      INNER JOIN credits c ON c.id = cp.credit_id
      WHERE c.shop_id = ?
    ''', [shopId]);
    return (result.first.values.first as num?)?.toDouble() ?? 0.0;
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════
  Credit _creditFromMap(Map<String, dynamic> map) {
    final customer = Customer(
      id: map['customer_id'] as String,
      name: map['customer_name'] as String? ?? 'Client inconnu',
      phone: map['customer_phone'] as String?,
      address: map['customer_address'] as String?,
    );

    return Credit(
      id: map['id'] as String,
      customer: customer,
      totalAmount: (map['total_amount'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      dueDate: DateTime.parse(map['due_date'] as String),
      notes: map['notes'] as String?,
    );
  }

  CreditPayment _paymentFromMap(Map<String, dynamic> map) {
    return CreditPayment(
      id: map['id'] as String,
      creditId: map['credit_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      date: DateTime.parse(map['payment_date'] as String),
      comment: map['comment'] as String?,
    );
  }

  Map<String, dynamic> _creditToJson(Credit credit, String shopId) {
    return {
      'id': credit.id,
      'shop_id': shopId,
      'customer_id': credit.customer.id,
      'total_amount': credit.totalAmount,
      'paid_amount': credit.paidAmount,
      'created_at': credit.createdAt.toIso8601String(),
      'due_date': credit.dueDate.toIso8601String(),
      'notes': credit.notes,
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
