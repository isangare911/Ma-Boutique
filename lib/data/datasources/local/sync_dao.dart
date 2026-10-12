import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

class SyncDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// ⚡ Nombre max de retries avant de considérer une opération comme "dead"
  static const int maxRetries = 10;

  /// Récupère toutes les opérations en attente (hors "dead")
  Future<List<Map<String, dynamic>>> getPendingOperations(
      {int limit = 50}) async {
    final db = await _dbHelper.database;
    return await db.query(
      'sync_queue',
      where: 'status = ? AND retry_count < ?',
      whereArgs: ['PENDING', maxRetries],
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  /// Compte les opérations en attente (hors "dead")
  Future<int> getPendingCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) FROM sync_queue WHERE status = 'PENDING' AND retry_count < ?",
      [maxRetries],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Compte les opérations échouées
  Future<int> getFailedCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) FROM sync_queue WHERE status = 'FAILED'",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Compte les opérations synchronisées
  Future<int> getSyncedCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) FROM sync_queue WHERE status = 'SYNCED'",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Marque une opération comme synchronisée
  Future<void> markAsSynced(int id) async {
    final db = await _dbHelper.database;
    await db.update(
      'sync_queue',
      {'status': 'SYNCED'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marque une opération comme échouée et incrémente le compteur de retry
  Future<void> markAsFailed(int id, String error) async {
    final db = await _dbHelper.database;
    await db.rawUpdate('''
      UPDATE sync_queue
      SET status = 'FAILED',
          retry_count = retry_count + 1,
          last_error = ?
      WHERE id = ?
    ''', [error, id]);
  }

  /// Remet une opération échouée en attente (pour retry manuel)
  Future<void> retryFailed(int id) async {
    final db = await _dbHelper.database;
    await db.update(
      'sync_queue',
      {'status': 'PENDING', 'retry_count': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Récupère l'historique récent
  Future<List<Map<String, dynamic>>> getRecentOperations(
      {int limit = 20}) async {
    final db = await _dbHelper.database;
    return await db.query(
      'sync_queue',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  /// Remet toutes les opérations échouées en attente (retry_count remis à 0)
  Future<int> resetAllFailed() async {
    final db = await _dbHelper.database;
    return await db.update(
      'sync_queue',
      {'status': 'PENDING', 'retry_count': 0},
      where: 'status = ?',
      whereArgs: ['FAILED'],
    );
  }

  /// Nettoie les opérations synchronisées (pour ne pas surcharger la DB)
  Future<int> cleanSyncedOperations({int keepLast = 100}) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'sync_queue',
      columns: ['id'],
      where: 'status = ?',
      whereArgs: ['SYNCED'],
      orderBy: 'created_at DESC',
      limit: keepLast,
    );
    final idsToKeep = result.map((r) => r['id']).toList();

    if (idsToKeep.isEmpty) return 0;

    final placeholders = List.filled(idsToKeep.length, '?').join(',');
    return await db.delete(
      'sync_queue',
      where: 'status = ? AND id NOT IN ($placeholders)',
      whereArgs: ['SYNCED', ...idsToKeep],
    );
  }
}
