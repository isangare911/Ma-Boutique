import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/services/sync_service.dart';
import '../../models/cash_movement.dart';
import '../../models/cash_session.dart';
import 'database_helper.dart';

class CashDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ═══════════════════════════════════════════════════════════
  // SESSION DE CAISSE
  // ═══════════════════════════════════════════════════════════
  Future<String> openSession(CashSession session, String shopId) async {
    final db = await _dbHelper.database;
    await db.insert('cash_sessions', {
      'id': session.id,
      'shop_id': shopId,
      'opening_balance': session.openingBalance,
      'opened_at': session.openedAt.toIso8601String(),
      'status': 'OPEN',
    });

    await _addToSyncQueue(
      operationType: 'CREATE',
      entityType: 'CASH_SESSION',
      entityId: session.id,
      payload: {
        'id': session.id,
        'opening_balance': session.openingBalance,
        'opened_at': session.openedAt.toIso8601String(),
        'status': 'OPEN',
      },
    );

    return session.id;
  }

  Future<CashSession?> getCurrentSession() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'cash_sessions',
      where: 'status = ?',
      whereArgs: ['OPEN'],
      orderBy: 'opened_at DESC',
      limit: 1,
    );
    if (result.isEmpty) return null;
    return _sessionFromMap(result.first);
  }

  Future<List<CashSession>> getAllSessions() async {
    final db = await _dbHelper.database;
    final result = await db.query('cash_sessions', orderBy: 'opened_at DESC');
    return result.map((map) => _sessionFromMap(map)).toList();
  }

  Future<void> closeSession(String sessionId, double closingBalance) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // Récupérer le solde théorique
      final theoretical = await _calculateTheoreticalBalance(txn, sessionId);
      final difference = closingBalance - theoretical;
      final closedAt = DateTime.now().toIso8601String();

      await txn.update(
        'cash_sessions',
        {
          'closing_balance': closingBalance,
          'theoretical_balance': theoretical,
          'difference': difference,
          'closed_at': closedAt,
          'status': 'CLOSED',
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      await txn.insert('sync_queue', {
        'operation_type': 'UPDATE',
        'entity_type': 'CASH_SESSION',
        'entity_id': sessionId,
        'payload': jsonEncode({
          'id': sessionId,
          'closing_balance': closingBalance,
          'theoretical_balance': theoretical,
          'difference': difference,
          'closed_at': closedAt, // ⚡ Ajouté
          'status': 'CLOSED', // ⚡ Ajouté
        }),
        'created_at': closedAt,
        'status': 'PENDING',
      });
    });
  }

  // ═══════════════════════════════════════════════════════════
  // MOUVEMENTS DE CAISSE
  // ═══════════════════════════════════════════════════════════
  Future<String> addMovement(CashMovement movement) async {
    final db = await _dbHelper.database;
    await db.insert('cash_movements', {
      'id': movement.id,
      'session_id': movement.sessionId,
      'type': movement.type,
      'amount': movement.amount,
      'category': movement.category,
      'description': movement.description,
      'created_at': movement.createdAt.toIso8601String(),
    });

    await _addToSyncQueue(
      operationType: 'CREATE',
      entityType: 'CASH_MOVEMENT',
      entityId: movement.id,
      payload: {
        'id': movement.id,
        'session_id': movement.sessionId,
        'type': movement.type,
        'amount': movement.amount,
        'category': movement.category,
        'description': movement.description, // ⚡ Ajouté
        'created_at': movement.createdAt.toIso8601String(), // ⚡ Ajouté
      },
    );

    return movement.id;
  }

  Future<List<CashMovement>> getMovementsBySession(String sessionId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'cash_movements',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => _movementFromMap(map)).toList();
  }

  Future<void> deleteMovement(String id) async {
    final db = await _dbHelper.database;
    await db.delete('cash_movements', where: 'id = ?', whereArgs: [id]);

    // ⚡ Ajout à la file de synchronisation
    await _addToSyncQueue(
      operationType: 'DELETE',
      entityType: 'CASH_MOVEMENT',
      entityId: id,
      payload: {'id': id},
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CALCULS
  // ═══════════════════════════════════════════════════════════
  Future<double> _calculateTheoreticalBalance(
    DatabaseExecutor txn,
    String sessionId,
  ) async {
    final sessionResult = await txn.query(
      'cash_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (sessionResult.isEmpty) return 0;
    final opening = (sessionResult.first['opening_balance'] as num).toDouble();

    final inResult = await txn.rawQuery(
      "SELECT SUM(amount) FROM cash_movements WHERE session_id = ? AND type = 'IN'",
      [sessionId],
    );
    final totalIn = (inResult.first.values.first as num?)?.toDouble() ?? 0.0;

    final outResult = await txn.rawQuery(
      "SELECT SUM(amount) FROM cash_movements WHERE session_id = ? AND type = 'OUT'",
      [sessionId],
    );
    final totalOut = (outResult.first.values.first as num?)?.toDouble() ?? 0.0;

    return opening + totalIn - totalOut;
  }

  Future<double> getTheoreticalBalance(String sessionId) async {
    final db = await _dbHelper.database;
    return _calculateTheoreticalBalance(db, sessionId);
  }

  Future<Map<String, double>> getSessionSummary(String sessionId) async {
    final db = await _dbHelper.database;

    final inResult = await db.rawQuery(
      "SELECT SUM(amount) FROM cash_movements WHERE session_id = ? AND type = 'IN'",
      [sessionId],
    );
    final totalIn = (inResult.first.values.first as num?)?.toDouble() ?? 0.0;

    final outResult = await db.rawQuery(
      "SELECT SUM(amount) FROM cash_movements WHERE session_id = ? AND type = 'OUT'",
      [sessionId],
    );
    final totalOut = (outResult.first.values.first as num?)?.toDouble() ?? 0.0;

    final theoretical = await getTheoreticalBalance(sessionId);

    return {
      'totalIn': totalIn,
      'totalOut': totalOut,
      'theoretical': theoretical,
    };
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════
  CashSession _sessionFromMap(Map<String, dynamic> map) {
    return CashSession(
      id: map['id'] as String,
      openingBalance: (map['opening_balance'] as num).toDouble(),
      closingBalance: (map['closing_balance'] as num?)?.toDouble(),
      theoreticalBalance: (map['theoretical_balance'] as num?)?.toDouble(),
      difference: (map['difference'] as num?)?.toDouble(),
      openedAt: DateTime.parse(map['opened_at'] as String),
      closedAt: map['closed_at'] != null
          ? DateTime.parse(map['closed_at'] as String)
          : null,
      status: map['status'] as String? ?? 'OPEN',
    );
  }

  CashMovement _movementFromMap(Map<String, dynamic> map) {
    return CashMovement(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
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
    // ⚡ Déclencher la sync automatique
    SyncService.instance.triggerSync();
  }
}
