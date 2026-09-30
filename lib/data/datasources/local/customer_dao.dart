import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/services/current_shop.dart';
import '../../../core/services/sync_service.dart';
import '../../models/customer.dart';
import 'database_helper.dart';

class CustomerDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  String? get _shopId => CurrentShop.shopId;

  // ═══════════════════════════════════════════════════════════
  // CRÉER
  // ═══════════════════════════════════════════════════════════
  Future<String> insertCustomer(Customer customer, String shopId) async {
    final db = await _dbHelper.database;
    await db.insert(
      'customers',
      {
        'id': customer.id,
        'shop_id': shopId,
        'name': customer.name,
        'phone': customer.phone,
        'address': customer.address,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _addToSyncQueue(
      operationType: 'CREATE',
      entityType: 'CUSTOMER',
      entityId: customer.id,
      payload: {
        'id': customer.id,
        'shop_id': shopId,
        'name': customer.name,
        'phone': customer.phone,
        'address': customer.address,
      },
    );

    return customer.id;
  }

  // ═══════════════════════════════════════════════════════════
  // LIRE
  // ═══════════════════════════════════════════════════════════
  Future<List<Customer>> getAllCustomers() async {
    final shopId = _shopId;
    if (shopId == null) return [];

    final db = await _dbHelper.database;
    final result = await db.query(
      'customers',
      where: 'shop_id = ?',
      whereArgs: [shopId],
      orderBy: 'name ASC',
    );
    return result.map((map) => _customerFromMap(map)).toList();
  }

  Future<Customer?> getCustomerById(String id) async {
    final shopId = _shopId;
    if (shopId == null) return null;

    final db = await _dbHelper.database;
    final result = await db.query(
      'customers',
      where: 'id = ? AND shop_id = ?',
      whereArgs: [id, shopId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return _customerFromMap(result.first);
  }

  Future<List<Customer>> searchCustomers(String query) async {
    final shopId = _shopId;
    if (shopId == null) return [];

    final db = await _dbHelper.database;
    final result = await db.query(
      'customers',
      where: 'shop_id = ? AND (name LIKE ? OR phone LIKE ?)',
      whereArgs: [shopId, '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return result.map((map) => _customerFromMap(map)).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // METTRE À JOUR
  // ═══════════════════════════════════════════════════════════
  Future<void> updateCustomer(Customer customer, String shopId) async {
    final db = await _dbHelper.database;
    await db.update(
      'customers',
      {
        'name': customer.name,
        'phone': customer.phone,
        'address': customer.address,
      },
      where: 'id = ? AND shop_id = ?',
      whereArgs: [customer.id, shopId],
    );

    await _addToSyncQueue(
      operationType: 'UPDATE',
      entityType: 'CUSTOMER',
      entityId: customer.id,
      payload: {
        'id': customer.id,
        'shop_id': shopId,
        'name': customer.name,
        'phone': customer.phone,
        'address': customer.address,
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SUPPRIMER
  // ═══════════════════════════════════════════════════════════
  Future<void> deleteCustomer(String id) async {
    final shopId = _shopId;
    if (shopId == null) return;

    final db = await _dbHelper.database;
    await db.delete(
      'customers',
      where: 'id = ? AND shop_id = ?',
      whereArgs: [id, shopId],
    );

    await _addToSyncQueue(
      operationType: 'DELETE',
      entityType: 'CUSTOMER',
      entityId: id,
      payload: {'id': id, 'shop_id': shopId},
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════
  Customer _customerFromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
    );
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
