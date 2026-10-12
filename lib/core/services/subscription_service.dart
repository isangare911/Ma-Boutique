import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/payment.dart';
import '../../data/models/subscription.dart';
import '../network/api_client.dart';

class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService instance = SubscriptionService._();
  SubscriptionService._();

  final ApiClient _apiClient = ApiClient.instance;

  static const String _keyCache = 'subscription_cache';
  static const String _keyLastCheck = 'last_server_check';
  static const String _keyDeviceTime = 'device_time_at_check';
  static const int _maxOfflineDays = 7;

  Subscription? _subscription;
  Subscription? get subscription => _subscription;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // ═══════════════════════════════════════════════════════════
  // ACCÈS RAPIDE
  // ═══════════════════════════════════════════════════════════

  bool get canSell => _subscription?.canSell ?? false;
  bool get isTrial => _subscription?.isTrial ?? false;
  bool get isActive => _subscription?.isActiveStatus ?? false;
  bool get isGracePeriod => _subscription?.isGracePeriod ?? false;
  bool get isExpired => _subscription?.isExpired ?? false;
  int get daysRemaining => _subscription?.daysRemaining ?? 0;
  String get planName => _subscription?.planName ?? 'Inconnu';
  String get statusName => _subscription?.statusName ?? 'Inconnu';

  // ═══════════════════════════════════════════════════════════
  // INITIALISATION
  // ═══════════════════════════════════════════════════════════

  Future<void> initializeFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_keyCache);

      if (cachedJson == null) {
        debugPrint('ℹ Aucun cache abonnement');
        return;
      }

      try {
        final decoded = jsonDecode(cachedJson);
        if (decoded is! Map) {
          throw const FormatException('Cache abonnement: format invalide');
        }

        final data = Map<String, dynamic>.from(decoded);
        _subscription = Subscription.fromJson(data);
        debugPrint('✓ Abonnement chargé du cache: ${_subscription!.status}');
        notifyListeners();
      } catch (e) {
        debugPrint('⚠ Cache abonnement corrompu, suppression...');
        await prefs.remove(_keyCache);
        await prefs.remove(_keyLastCheck);
        await prefs.remove(_keyDeviceTime);
        _subscription = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Erreur chargement cache abonnement');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // MOBILE MONEY — PAIEMENT D'ABONNEMENT
  // ═══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> createPayment({
    required String plan,
    required String method,
    String? payerPhone,
  }) async {
    try {
      final response = await _apiClient.post('/payments/create/', {
        'plan': plan,
        'method': method,
        if (payerPhone != null) 'payer_phone': payerPhone,
      });

      if (response.success && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        return {
          'payment': Payment.fromJson(
            data['payment'] as Map<String, dynamic>,
          ),
          'instructions': PaymentInstructions.fromJson(
            data['instructions'] as Map<String, dynamic>,
          ),
        };
      }

      debugPrint('Erreur createPayment: ${response.error}');
      return null;
    } catch (e) {
      debugPrint('Exception createPayment');
      return null;
    }
  }

  /// ⚡ Retourne {'success': bool, 'error': String?}
  Future<Map<String, dynamic>> submitPaymentProof({
    required String paymentId,
    required String transactionId,
  }) async {
    try {
      final response = await _apiClient.post(
        '/payments/$paymentId/submit/',
        {'transaction_id': transactionId},
      );

      if (response.success) {
        debugPrint('✓ Preuve soumise pour $paymentId');
        return {'success': true};
      }

      // ⚡ Récupérer le vrai message d'erreur du serveur
      String errorMessage = 'Erreur lors de la soumission';

      if (response.body is Map && response.body['error'] != null) {
        errorMessage = response.body['error'] as String;
      } else if (response.errorMessage != null) {
        errorMessage = response.errorMessage!;
      }

      debugPrint('Erreur submitPaymentProof: $errorMessage');
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      debugPrint('Exception submitPaymentProof: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion au serveur',
      };
    }
  }

  Future<bool> cancelPayment(String paymentId) async {
    try {
      final response = await _apiClient.post(
        '/payments/$paymentId/cancel/',
        {},
      );
      return response.success;
    } catch (e) {
      debugPrint('Exception cancelPayment');
      return false;
    }
  }

  Future<List<Payment>> getPaymentHistory() async {
    try {
      final response = await _apiClient.get('/payments/');

      if (response.success && response.body is List) {
        return (response.body as List)
            .map((json) => Payment.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Exception getPaymentHistory');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // CHARGER DEPUIS L'API
  // ═══════════════════════════════════════════════════════════

  Future<bool> refreshSubscription() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.get('/subscription/status/');

      if (response.success && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        _subscription = Subscription.fromJson(data);

        await _saveToCache(_subscription!);

        debugPrint('✓ Abonnement: ${_subscription!.status} '
            '(${_subscription!.daysRemaining} jours restants)');

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response.error ?? 'Erreur de récupération';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ANTI-MANIPULATION DE DATE
  // ═══════════════════════════════════════════════════════════

  Future<bool> isDateManipulated() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final lastCheckStr = prefs.getString(_keyLastCheck);
      final deviceTimeAtCheckStr = prefs.getString(_keyDeviceTime);

      if (lastCheckStr == null || deviceTimeAtCheckStr == null) {
        return false;
      }

      final lastCheck = DateTime.parse(lastCheckStr);
      final deviceTimeAtCheck = DateTime.parse(deviceTimeAtCheckStr);
      final now = DateTime.now();

      const tolerance = Duration(days: 1);

      if (now.isBefore(lastCheck.subtract(tolerance))) {
        debugPrint('⚠ Date reculée significativement');
        return true;
      }

      if (now.isBefore(deviceTimeAtCheck.subtract(tolerance))) {
        debugPrint('⚠ Date reculée significativement');
        return true;
      }

      final daysSinceLastCheck = now.difference(lastCheck).inDays;
      if (daysSinceLastCheck > _maxOfflineDays) {
        debugPrint('⚠ Hors-ligne depuis $daysSinceLastCheck jours '
            '(max: $_maxOfflineDays)');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Erreur isDateManipulated');
      return false;
    }
  }

  Future<void> _saveServerCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString(_keyLastCheck, now.toIso8601String());
    await prefs.setString(_keyDeviceTime, now.toIso8601String());
  }

  // ═══════════════════════════════════════════════════════════
  // CACHE LOCAL
  // ═══════════════════════════════════════════════════════════

  Future<void> _saveToCache(Subscription subscription) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyCache,
      jsonEncode(subscription.toJson()),
    );
    await _saveServerCheckTime();
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCache);
    await prefs.remove(_keyLastCheck);
    await prefs.remove(_keyDeviceTime);
    _subscription = null;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  // VÉRIFICATION PÉRIODIQUE
  // ═══════════════════════════════════════════════════════════

  Future<bool> needsRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckStr = prefs.getString(_keyLastCheck);

    if (lastCheckStr == null) return true;

    final lastCheck = DateTime.parse(lastCheckStr);
    final hoursSinceLastCheck = DateTime.now().difference(lastCheck).inHours;

    return hoursSinceLastCheck >= 24;
  }

  // ═══════════════════════════════════════════════════════════
  // PLANS DISPONIBLES
  // ═══════════════════════════════════════════════════════════

  Future<List<SubscriptionPlan>> getAvailablePlans() async {
    try {
      final response = await _apiClient.get('/subscription/plans/');

      if (response.success && response.body is List) {
        return (response.body as List)
            .map((json) => SubscriptionPlan.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Erreur chargement plans');
      return [];
    }
  }
}
