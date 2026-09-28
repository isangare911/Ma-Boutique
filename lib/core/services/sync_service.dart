import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/datasources/local/sync_dao.dart';
import '../network/api_client.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'data_refresh_notifier.dart';

enum SyncStatus { idle, syncing, success, failed, offline }

class SyncService extends ChangeNotifier {
  static final SyncService instance = SyncService._();
  SyncService._();

  final SyncDao _syncDao = SyncDao();
  final ApiClient _apiClient = ApiClient.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;

  Timer? _periodicTimer;
  Timer? _debounceTimer;
  bool _isSyncing = false;

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

  // ═══════════════════════════════════════════════════════════
  // INITIALISATION
  // ═══════════════════════════════════════════════════════════
  Future<void> initialize() async {
    await _connectivity.initialize();

    // Écouter les changements de connexion
    _connectivity.connectionStream.listen((isConnected) {
      if (isConnected) {
        // Dès qu'on retrouve Internet, on synchronise
        syncNow();
      } else {
        _updateStatus(SyncStatus.offline);
      }
    });

    // Synchroniser au démarrage si connecté
    if (_connectivity.isConnected && AuthService.instance.isAuthenticated) {
      syncNow();
    }

    // Synchronisation périodique de secours toutes les 2 minutes
    // (au cas où une opération aurait raté)
    _periodicTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => syncNow(),
    );

    await _updatePendingCount();
  }

  // ═══════════════════════════════════════════════════════════
  // ⚡ TRIGGER : Appelé après chaque opération CRUD
  // ═══════════════════════════════════════════════════════════
  /// Déclenche une sync avec un léger debounce (300ms)
  /// pour éviter de spammer si plusieurs opérations sont faites en rafale.
  void triggerSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      syncNow();
    });
  }

  // ═══════════════════════════════════════════════════════════
  // SYNCHRONISATION PRINCIPALE
  // ═══════════════════════════════════════════════════════════
  Future<void> syncNow() async {
    if (_isSyncing) return;

    // ⚡ Ne pas synchroniser si l'utilisateur n'est pas connecté
    if (!AuthService.instance.isAuthenticated) {
      debugPrint('⏸ Sync en pause : utilisateur non connecté');
      return;
    }

    // Vérifier la connexion
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
      debugPrint('Erreur synchronisation: $e');
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
        // ⚡ Si le token est invalide, on arrête tout et on force la déconnexion
        if (response.statusCode == 401) {
          debugPrint('🔒 Token expiré : déconnexion');
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
      debugPrint('Erreur envoi opération: $e');
      return false;
    }
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
      debugPrint('Payload JSON invalide: $payloadString');
    }
    return {};
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
