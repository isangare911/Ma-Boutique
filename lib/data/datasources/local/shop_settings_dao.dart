import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/services/current_shop.dart';
import '../../../core/services/sync_service.dart';
import '../../models/shop_settings.dart';
import 'database_helper.dart';

class ShopSettingsDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  String? get _shopId => CurrentShop.shopId;

  // ═══════════════════════════════════════════════════════════
  // LIRE
  // ═══════════════════════════════════════════════════════════
  Future<ShopSettings?> getSettings() async {
    final shopId = _shopId;
    if (shopId == null) return null;

    final db = await _dbHelper.database;
    final result = await db.query(
      'shop_settings',
      where: 'shop_id = ?',
      whereArgs: [shopId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return _settingsFromMap(result.first);
  }

  // ═══════════════════════════════════════════════════════════
  // INSÉRER LOCALEMENT (sans sync)
  // ═══════════════════════════════════════════════════════════
  Future<void> insertLocalOnly(ShopSettings settings) async {
    final db = await _dbHelper.database;

    await db.insert(
      'shop_settings',
      {
        'id': settings.shopId, // ⚡ L'id = shopId
        'shop_id': settings.shopId,
        'shop_name': settings.shopName,
        'shop_logo_path': settings.shopLogoPath,
        'currency': settings.currency,
        'address': settings.address,
        'phone': settings.phone,
        'email': settings.email,
        'owner_name': settings.ownerName,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SAUVEGARDER + SYNCHRONISER
  // ═══════════════════════════════════════════════════════════
  Future<void> saveSettings(ShopSettings settings) async {
    final db = await _dbHelper.database;

    await db.insert(
      'shop_settings',
      {
        'id': settings.shopId,
        'shop_id': settings.shopId,
        'shop_name': settings.shopName,
        'shop_logo_path': settings.shopLogoPath,
        'currency': settings.currency,
        'address': settings.address,
        'phone': settings.phone,
        'email': settings.email,
        'owner_name': settings.ownerName,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _addToSyncQueue(settings);
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════
  ShopSettings _settingsFromMap(Map<String, dynamic> map) {
    return ShopSettings(
      id: map['id'] as String,
      shopId: map['shop_id'] as String,
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
      'entity_id': settings.shopId,
      'payload': jsonEncode({
        'id': settings.shopId,
        'shop_id': settings.shopId,
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

    SyncService.instance.triggerSync();
  }
}
