import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/datasources/local/database_helper.dart';
import '../../data/datasources/local/sync_dao.dart';
import '../network/api_client.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'current_shop.dart';
import 'data_refresh_notifier.dart';

enum SyncStatus { idle, syncing, success, failed, offline }

class SyncService extends ChangeNotifier {
  static final SyncService instance = SyncService._();
  SyncService._();

  final SyncDao _syncDao = SyncDao();
  final ApiClient _apiClient = ApiClient.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Timer? _periodicTimer;
  Timer? _debounceTimer;
  bool _isSyncing = false;
  bool _isPulling = false;

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  DateTime? _lastSyncAt;
  DateTime? get lastSyncAt => _lastSyncAt;

  int _pendingCount = 0;
  int get pendingCount => _pendingCount;

  int _failedCount = 0;
  int get failedCount => _failedCount;

  String? _lastError;
  String? get lastError => _lastError;

  bool get isSyncing => _isSyncing;
  bool get isPulling => _isPulling;

  // ═══════════════════════════════════════════════════════════
  // INITIALISATION
  // ═══════════════════════════════════════════════════════════
  Future<void> initialize() async {
    await _connectivity.initialize();

    // Écouter les changements de connexion
    _connectivity.connectionStream.listen((isConnected) {
      if (isConnected) {
        syncNow();
      } else {
        _updateStatus(SyncStatus.offline);
      }
    });

    // Synchroniser au démarrage si connecté
    if (_connectivity.isConnected && AuthService.instance.isAuthenticated) {
      syncNow();
    }

    // Synchronisation périodique toutes les 2 min
    _periodicTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => syncNow(),
    );

    await _updatePendingCount();
  }

  // ═══════════════════════════════════════════════════════════
  // ⚡ TRIGGER : Appelé après chaque opération CRUD
  // ═══════════════════════════════════════════════════════════
  void triggerSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      syncNow();
    });
  }

  // ═══════════════════════════════════════════════════════════
  // SYNCHRONISATION PRINCIPALE (PUSH)
  // ═══════════════════════════════════════════════════════════
  Future<void> syncNow() async {
    if (_isSyncing) return;

    if (!AuthService.instance.isAuthenticated) {
      debugPrint('⏸ Sync en pause : utilisateur non connecté');
      return;
    }

    final connected = await _connectivity.checkConnection();
    if (!connected) {
      _updateStatus(SyncStatus.offline);
      return;
    }

    _isSyncing = true;
    _updateStatus(SyncStatus.syncing);
    notifyListeners();

    try {
      final pending = await _syncDao.getPendingOperations(limit: 50);

      if (pending.isEmpty) {
        _lastSyncAt = DateTime.now();
        _updateStatus(SyncStatus.idle);
        _isSyncing = false;
        notifyListeners();
        return;
      }

      int successCount = 0;
      int failCount = 0;

      for (final op in pending) {
        final success = await _sendOperation(op);
        if (success) {
          await _syncDao.markAsSynced(op['id'] as int);
          successCount++;
        } else {
          failCount++;
        }
      }

      _lastSyncAt = DateTime.now();
      await _updatePendingCount();

      if (failCount == 0) {
        _updateStatus(SyncStatus.success);
        _lastError = null;
      } else {
        _updateStatus(SyncStatus.failed);
        _lastError = '$failCount opération(s) ont échoué';
      }

      if (successCount > 0) {
        DataRefreshNotifier.instance.notifyProductsChanged();
        DataRefreshNotifier.instance.notifySalesChanged();
        DataRefreshNotifier.instance.notifyCreditsChanged();
      }

      await _syncDao.cleanSyncedOperations();
    } catch (e) {
      _updateStatus(SyncStatus.failed);
      _lastError = e.toString();
      debugPrint('Erreur synchronisation');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ENVOI D'UNE OPÉRATION
  // ═══════════════════════════════════════════════════════════
  Future<bool> _sendOperation(Map<String, dynamic> op) async {
    final operationType = op['operation_type'] as String;
    final entityType = op['entity_type'] as String;
    final entityId = op['entity_id'] as String;
    final payloadString = op['payload'] as String;
    final id = op['id'] as int;

    Map<String, dynamic> payload;
    try {
      payload = _parsePayload(payloadString);
      if (payload.isEmpty) {
        await _syncDao.markAsFailed(id, 'Payload vide ou invalide');
        return false;
      }
    } catch (e) {
      await _syncDao.markAsFailed(id, 'Payload invalide: $e');
      return false;
    }

    try {
      final response = await _apiClient.post('/sync/', {
        'operations': [
          {
            'operation_type': operationType,
            'entity_type': entityType,
            'entity_id': entityId,
            'payload': payload,
            'created_at': op['created_at'],
          }
        ],
      });

      if (!response.success) {
        if (response.statusCode == 401) {
          debugPrint('🔒 Session expirée');
          await AuthService.instance.logout();
          return false;
        }
        await _syncDao.markAsFailed(
          id,
          'HTTP ${response.statusCode}: ${response.error ?? "Erreur"}',
        );
        return false;
      }

      final body = response.body as Map<String, dynamic>?;
      if (body != null && body['results'] is List) {
        final results = body['results'] as List;
        if (results.isNotEmpty && results[0]['success'] == true) {
          return true;
        }
        final err = results.isNotEmpty ? results[0]['error'] : null;
        await _syncDao.markAsFailed(id, err?.toString() ?? 'Erreur inconnue');
        return false;
      }

      return true;
    } catch (e) {
      await _syncDao.markAsFailed(id, e.toString());
      debugPrint('Erreur envoi opération');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ⚡ PULL — Serveur → Client
  // ═══════════════════════════════════════════════════════════
  /// Récupère TOUTES les données du serveur et remplace le local.
  /// Appelé au démarrage après login réussi.
  Future<bool> pullAll() async {
    if (_isPulling) {
      debugPrint('⏸ Pull déjà en cours');
      return false;
    }

    if (!AuthService.instance.isAuthenticated) {
      debugPrint('⏸ Pull en pause : utilisateur non connecté');
      return false;
    }

    final connected = await _connectivity.checkConnection();
    if (!connected) {
      debugPrint('⏸ Pull en pause : pas de connexion');
      return false;
    }

    _isPulling = true;
    notifyListeners();

    try {
      debugPrint('🔄 Pull complet depuis le serveur...');

      final response = await _apiClient.get('/sync/full/');

      if (!response.success || response.body == null) {
        debugPrint('❌ Pull échoué : ${response.error}');
        _isPulling = false;
        notifyListeners();
        return false;
      }

      final data = response.body as Map<String, dynamic>;

      // ⚡ Vider le local pour ce shop
      await _clearLocalData();

      // ⚡ Réinsérer tout
      await _importFullData(data);

      _lastSyncAt = DateTime.now();
      _updateStatus(SyncStatus.success);

      // ⚡ Rafraîchir tous les écrans
      DataRefreshNotifier.instance.notifyProductsChanged();
      DataRefreshNotifier.instance.notifySalesChanged();
      DataRefreshNotifier.instance.notifyCreditsChanged();

      await _updatePendingCount();

      debugPrint('✅ Pull terminé avec succès');
      _isPulling = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Exception pull: $e');
      _lastError = e.toString();
      _isPulling = false;
      notifyListeners();
      return false;
    }
  }

  /// Vide les données locales du shop courant
  Future<void> _clearLocalData() async {
    final shopId = CurrentShop.shopId;
    if (shopId == null) return;

    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // Ordre important : enfants d'abord
      await txn.delete(
        'sale_items',
        where: 'sale_id IN (SELECT id FROM sales WHERE shop_id = ?)',
        whereArgs: [shopId],
      );
      await txn.delete('sales', where: 'shop_id = ?', whereArgs: [shopId]);

      await txn.delete(
        'credit_payments',
        where: 'credit_id IN (SELECT id FROM credits WHERE shop_id = ?)',
        whereArgs: [shopId],
      );
      await txn.delete('credits', where: 'shop_id = ?', whereArgs: [shopId]);

      await txn.delete('products', where: 'shop_id = ?', whereArgs: [shopId]);
      await txn.delete('customers', where: 'shop_id = ?', whereArgs: [shopId]);
      await txn.delete('expenses', where: 'shop_id = ?', whereArgs: [shopId]);

      await txn.delete(
        'supplier_transactions',
        where: 'supplier_id IN (SELECT id FROM suppliers WHERE shop_id = ?)',
        whereArgs: [shopId],
      );
      await txn.delete('suppliers', where: 'shop_id = ?', whereArgs: [shopId]);

      await txn.delete(
        'cash_movements',
        where: 'session_id IN (SELECT id FROM cash_sessions WHERE shop_id = ?)',
        whereArgs: [shopId],
      );
      await txn
          .delete('cash_sessions', where: 'shop_id = ?', whereArgs: [shopId]);

      await txn
          .delete('shop_settings', where: 'shop_id = ?', whereArgs: [shopId]);
    });

    debugPrint('🗑️  Données locales vidées pour $shopId');
  }

  /// Importe toutes les données du serveur dans le local
  Future<void> _importFullData(Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    final shopId = CurrentShop.shopId;
    if (shopId == null) return;

    await db.transaction((txn) async {
      // PRODUITS
      for (final p in (data['products'] as List? ?? [])) {
        await txn.insert(
          'products',
          {
            'id': p['id'],
            'shop_id': shopId,
            'name': p['name'],
            'reference': p['reference'],
            'barcode': p['barcode'],
            'category': p['category'],
            'purchase_price': _toDouble(p['purchase_price']),
            'selling_price': _toDouble(p['selling_price']),
            'quantity': p['quantity'] ?? 0,
            'alert_threshold': p['alert_threshold'] ?? 5,
            'unit': p['unit'],
            'image_path': p['image_path'],
            'created_at': p['created_at'],
            'updated_at': p['updated_at'] ?? p['created_at'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // CLIENTS
      for (final c in (data['customers'] as List? ?? [])) {
        await txn.insert(
          'customers',
          {
            'id': c['id'],
            'shop_id': shopId,
            'name': c['name'],
            'phone': c['phone'],
            'address': c['address'],
            'created_at': c['created_at'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // CRÉDITS
      for (final cr in (data['credits'] as List? ?? [])) {
        await txn.insert(
          'credits',
          {
            'id': cr['id'],
            'shop_id': shopId,
            'customer_id': cr['customer'],
            'total_amount': _toDouble(cr['total_amount']),
            'paid_amount': _toDouble(cr['paid_amount']),
            'created_at': cr['created_at'],
            'due_date': cr['due_date'],
            'notes': cr['notes'],
            'status': cr['status'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // PAIEMENTS DE CRÉDIT
      for (final cp in (data['credit_payments'] as List? ?? [])) {
        await txn.insert(
          'credit_payments',
          {
            'id': cp['id'],
            'credit_id': cp['credit'],
            'amount': _toDouble(cp['amount']),
            'payment_method': cp['payment_method'],
            'payment_date': cp['payment_date'],
            'comment': cp['comment'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // VENTES
      for (final s in (data['sales'] as List? ?? [])) {
        await txn.insert(
          'sales',
          {
            'id': s['id'],
            'shop_id': shopId,
            'customer_id': s['customer'],
            'total_amount': _toDouble(s['total_amount']),
            'payment_method': s['payment_method'],
            'status': s['status'],
            'created_at': s['created_at'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        for (final item in (s['items'] as List? ?? [])) {
          await txn.insert(
            'sale_items',
            {
              'id': item['id'],
              'sale_id': s['id'],
              'product_id': item['product'],
              'product_name': item['product_name'],
              'unit_price': _toDouble(item['unit_price']),
              'purchase_price': _toDouble(item['purchase_price']),
              'quantity': item['quantity'],
              'subtotal': _toDouble(item['subtotal']),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // DÉPENSES
      for (final e in (data['expenses'] as List? ?? [])) {
        await txn.insert(
          'expenses',
          {
            'id': e['id'],
            'shop_id': shopId,
            'amount': _toDouble(e['amount']),
            'category': e['category'],
            'description': e['description'],
            'expense_date': e['expense_date'] ?? e['created_at'],
            'created_at': e['created_at'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // FOURNISSEURS
      for (final sup in (data['suppliers'] as List? ?? [])) {
        await txn.insert(
          'suppliers',
          {
            'id': sup['id'],
            'shop_id': shopId,
            'name': sup['name'],
            'phone': sup['phone'],
            'address': sup['address'],
            'products_supplied': sup['products_supplied'],
            'notes': sup['notes'],
            'created_at': sup['created_at'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final st in (data['supplier_transactions'] as List? ?? [])) {
        await txn.insert(
          'supplier_transactions',
          {
            'id': st['id'],
            'supplier_id': st['supplier'],
            'type': st['type'],
            'amount': _toDouble(st['amount']),
            'description': st['description'],
            'transaction_date': st['transaction_date'],
            'created_at': st['created_at'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // CAISSE
      for (final cs in (data['cash_sessions'] as List? ?? [])) {
        await txn.insert(
          'cash_sessions',
          {
            'id': cs['id'],
            'shop_id': shopId,
            'opening_balance': _toDouble(cs['opening_balance']),
            'closing_balance': cs['closing_balance'] != null
                ? _toDouble(cs['closing_balance'])
                : null,
            'theoretical_balance': cs['theoretical_balance'] != null
                ? _toDouble(cs['theoretical_balance'])
                : null,
            'difference':
                cs['difference'] != null ? _toDouble(cs['difference']) : null,
            'opened_at': cs['opened_at'],
            'closed_at': cs['closed_at'],
            'status': cs['status'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        for (final m in (cs['movements'] as List? ?? [])) {
          await txn.insert(
            'cash_movements',
            {
              'id': m['id'],
              'session_id': cs['id'],
              'type': m['type'],
              'amount': _toDouble(m['amount']),
              'category': m['category'],
              'description': m['description'],
              'created_at': m['created_at'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // SHOP SETTINGS
      final shop = data['shop'] as Map<String, dynamic>?;
      if (shop != null) {
        await txn.insert(
          'shop_settings',
          {
            'id': shopId,
            'shop_id': shopId,
            'shop_name': shop['name'] ?? 'Ma Boutique',
            'shop_logo_path': shop['logo_path'],
            'currency': shop['currency'] ?? 'FCFA',
            'address': shop['address'],
            'phone': shop['phone'],
            'email': shop['email'],
            'owner_name': shop['owner_name'],
            'updated_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    debugPrint('📥 Données importées du serveur');
  }

  // ═══════════════════════════════════════════════════════════
  // PARSING DU PAYLOAD
  // ═══════════════════════════════════════════════════════════
  Map<String, dynamic> _parsePayload(String payloadString) {
    try {
      final decoded = jsonDecode(payloadString);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('Payload JSON invalide');
    }
    return {};
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // ═══════════════════════════════════════════════════════════
  // COMPTEURS
  // ═══════════════════════════════════════════════════════════
  Future<void> _updatePendingCount() async {
    _pendingCount = await _syncDao.getPendingCount();
    _failedCount = await _syncDao.getFailedCount();
    notifyListeners();
  }

  void _updateStatus(SyncStatus status) {
    _status = status;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  // ACTIONS MANUELLES
  // ═══════════════════════════════════════════════════════════
  Future<void> retryAllFailed() async {
    final count = await _syncDao.resetAllFailed();
    debugPrint('$count opération(s) remises en attente');
    await refreshCounters();
    await syncNow();
  }

  Future<void> refreshCounters() async {
    await _updatePendingCount();
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
