import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/services/sync_service.dart';
import '../../models/shop_settings.dart';
import 'database_helper.dart';

class ShopSettingsDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<ShopSettings?> getSettings() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'shop_settings',
      where: 'id = ?',
      whereArgs: [ShopSettings.defaultId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return _settingsFromMap(result.first);
  }

  /// ⚡ Insérer les settings localement SANS sync
  /// Utilisé uniquement pour initialiser les valeurs par défaut
  Future<void> insertLocalOnly(ShopSettings settings) async {
    final db = await _dbHelper.database;
    final fixed = settings.copyWith(id: ShopSettings.defaultId);

    await db.insert(
      'shop_settings',
      {
        'id': fixed.id,
        'shop_name': fixed.shopName,
        'shop_logo_path': fixed.shopLogoPath,
        'currency': fixed.currency,
        'address': fixed.address,
        'phone': fixed.phone,
        'email': fixed.email,
        'owner_name': fixed.ownerName,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // ⚡ PAS d'appel à _addToSyncQueue (pas de sync pour les défauts)
  }

  /// ⚡ Sauvegarder ET synchroniser
  Future<void> saveSettings(ShopSettings settings) async {
    // FORCER l'ID à SHOP-00001
    final fixed = settings.copyWith(id: ShopSettings.defaultId);

    final db = await _dbHelper.database;
    await db.insert(
      'shop_settings',
      {
        'id': fixed.id,
        'shop_name': fixed.shopName,
        'shop_logo_path': fixed.shopLogoPath,
        'currency': fixed.currency,
        'address': fixed.address,
        'phone': fixed.phone,
        'email': fixed.email,
        'owner_name': fixed.ownerName,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _addToSyncQueue(fixed);
  }

  ShopSettings _settingsFromMap(Map<String, dynamic> map) {
    return ShopSettings(
      id: map['id'] as String,
      shopName: map['shop_name'] as String,
      shopLogoPath: map['shop_logo_path'] as String?,
      currency: map['currency'] as String? ?? 'FCFA',
      address: map['address'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      ownerName: map['owner_name'] as String?,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Future<void> _addToSyncQueue(ShopSettings settings) async {
    final db = await _dbHelper.database;
    await db.insert('sync_queue', {
      'operation_type': 'UPDATE',
      'entity_type': 'SHOP_SETTINGS',
      'entity_id': ShopSettings.defaultId,
      'payload': jsonEncode({
        'id': ShopSettings.defaultId,
        'name': settings.shopName,
        'currency': settings.currency,
        'address': settings.address,
        'phone': settings.phone,
        'email': settings.email,
        'owner_name': settings.ownerName,
        'logo_path': settings.shopLogoPath,
      }),
      'created_at': DateTime.now().toIso8601String(),
      'status': 'PENDING',
    });

    // ⚡ Déclencher la sync automatique
    SyncService.instance.triggerSync();
  }
}
