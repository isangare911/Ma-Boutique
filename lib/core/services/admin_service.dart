import 'package:flutter/foundation.dart';

import '../../data/models/admin_models.dart';
import '../../data/models/payment.dart';
import '../network/api_client.dart';

class AdminService {
  static final AdminService instance = AdminService._();
  AdminService._();

  final ApiClient _apiClient = ApiClient.instance;

  // ═══════════════════════════════════════════════════════════
  // STATISTIQUES GLOBALES
  // ═══════════════════════════════════════════════════════════
  Future<AdminStats?> getStats() async {
    try {
      final response = await _apiClient.get('/admin/stats/');

      if (response.success && response.body != null) {
        return AdminStats.fromJson(response.body as Map<String, dynamic>);
      }
      debugPrint('Erreur getStats: ${response.error}');
      return null;
    } catch (e) {
      debugPrint('Exception getStats: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // LISTE DES BOUTIQUES
  // ═══════════════════════════════════════════════════════════
  Future<List<AdminShop>> getShops() async {
    try {
      final response = await _apiClient.get('/admin/shops/');

      if (response.success && response.body is List) {
        return (response.body as List)
            .map((json) => AdminShop.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Exception getShops: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // LISTE DES PAIEMENTS
  // ═══════════════════════════════════════════════════════════
  Future<List<Payment>> getPayments({String? status}) async {
    try {
      final endpoint = status != null
          ? '/admin/payments/?status=$status'
          : '/admin/payments/';

      final response = await _apiClient.get(endpoint);

      if (response.success && response.body is List) {
        return (response.body as List)
            .map((json) => Payment.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Exception getPayments: $e');
      return [];
    }
  }

  Future<List<Payment>> getPendingPayments() async {
    return getPayments(status: 'PENDING_REVIEW');
  }

  // ═══════════════════════════════════════════════════════════
  // ⚡ NOUVEAU : Paiements d'une boutique spécifique
  // ═══════════════════════════════════════════════════════════
  Future<List<Payment>> getShopPayments(String shopId) async {
    try {
      final response = await _apiClient.get('/admin/shops/$shopId/payments/');

      if (response.success && response.body is List) {
        return (response.body as List)
            .map((json) => Payment.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Exception getShopPayments: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // APPROUVER UN PAIEMENT
  // ═══════════════════════════════════════════════════════════
  Future<bool> approvePayment(String paymentId) async {
    try {
      final response = await _apiClient.post(
        '/admin/payments/$paymentId/approve/',
        {},
      );

      if (response.success) {
        debugPrint('✓ Paiement $paymentId approuvé');
        return true;
      }

      debugPrint('Erreur approvePayment: ${response.error}');
      return false;
    } catch (e) {
      debugPrint('Exception approvePayment: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // REJETER UN PAIEMENT
  // ═══════════════════════════════════════════════════════════
  Future<bool> rejectPayment(String paymentId, String reason) async {
    try {
      final response = await _apiClient.post(
        '/admin/payments/$paymentId/reject/',
        {'reason': reason},
      );

      if (response.success) {
        debugPrint('✓ Paiement $paymentId rejeté');
        return true;
      }

      debugPrint('Erreur rejectPayment: ${response.error}');
      return false;
    } catch (e) {
      debugPrint('Exception rejectPayment: $e');
      return false;
    }
  }
}
