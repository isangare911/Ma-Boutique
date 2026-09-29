import 'package:flutter/foundation.dart';

import '../../data/models/shop_user.dart';
import '../network/api_client.dart';

class ShopUserService {
  static final ShopUserService instance = ShopUserService._();
  ShopUserService._();

  final ApiClient _apiClient = ApiClient.instance;

  // ═══════════════════════════════════════════════════════════
  // LISTE DES UTILISATEURS
  // ═══════════════════════════════════════════════════════════
  Future<List<ShopUser>> getUsers() async {
    try {
      final response = await _apiClient.get('/shop/users/');

      if (response.success && response.body is List) {
        return (response.body as List)
            .map((json) => ShopUser.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Erreur getUsers: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // AJOUTER UN UTILISATEUR
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> addUser({
    required String phone,
    required String role,
    String? firstName,
    String? lastName,
    String? password,
  }) async {
    try {
      final response = await _apiClient.post('/shop/users/', {
        'phone': phone,
        'role': role,
        if (firstName != null && firstName.isNotEmpty) 'first_name': firstName,
        if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
        if (password != null && password.isNotEmpty) 'password': password,
      });

      if (response.success && response.body != null) {
        final data = response.body as Map<String, dynamic>;

        final result = <String, dynamic>{
          'success': true,
          'user': ShopUser.fromJson(data),
        };

        // ⚡ Récupérer le mot de passe généré s'il existe
        if (data['generated_password'] != null) {
          result['generated_password'] = data['generated_password'] as String;
        }

        return result;
      }

      // Extraire l'erreur de la réponse
      String errorMessage = 'Erreur lors de l\'ajout';
      if (response.body is Map && response.body['error'] != null) {
        errorMessage = response.body['error'] as String;
      } else if (response.body is Map && response.body['phone'] != null) {
        errorMessage = (response.body['phone'] as List).first.toString();
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      debugPrint('Exception addUser: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ═══════════════════════════════════════════════════════════
  // MODIFIER UN UTILISATEUR
  // ═══════════════════════════════════════════════════════════
  Future<bool> updateUser({
    required String memberId,
    String? role,
    bool? isActive,
  }) async {
    try {
      final response = await _apiClient.patch(
        '/shop/users/$memberId/',
        {
          if (role != null) 'role': role,
          if (isActive != null) 'is_active': isActive,
        },
      );

      return response.success;
    } catch (e) {
      debugPrint('Exception updateUser: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // SUPPRIMER UN UTILISATEUR
  // ═══════════════════════════════════════════════════════════
  Future<bool> deleteUser(String memberId) async {
    try {
      final response = await _apiClient.delete('/shop/users/$memberId/');
      return response.success;
    } catch (e) {
      debugPrint('Exception deleteUser: $e');
      return false;
    }
  }
}
