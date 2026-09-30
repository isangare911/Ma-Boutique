import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import 'current_shop.dart';

class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._();
  AuthService._();

  final ApiClient _apiClient = ApiClient.instance;

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUser = 'current_user';
  static const String _keyDeviceVerified = 'device_verified';
  static const String _keyVerifiedPhone = 'verified_phone';

  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _user;
  bool _isAuthenticated = false;
  bool _isLoading = false;

  String? get accessToken => _accessToken;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  // ═══════════════════════════════════════════════════════════
  // INITIALISATION
  // ═══════════════════════════════════════════════════════════

  Future<void> initialize() async {
    try {
      _accessToken = await _secureStorage.read(key: _keyAccessToken);
      _refreshToken = await _secureStorage.read(key: _keyRefreshToken);

      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_keyUser);

      if (userJson != null) {
        try {
          final decoded = jsonDecode(userJson);
          if (decoded is Map) {
            _user = Map<String, dynamic>.from(decoded);
          }
        } catch (e) {
          await prefs.remove(_keyUser);
          _user = null;
        }
      }

      _isAuthenticated = _accessToken != null;

      if (_isAuthenticated) {
        _apiClient.setAuthToken(_accessToken!);

        // ⚡ Définir le shop courant
        final shopId = _user?['shop']?['id'] as String?;
        CurrentShop.set(shopId);
        debugPrint('🔍 initialize → CurrentShop.shopId = $shopId');
      }
    } catch (e) {
      debugPrint('Erreur initialize auth');
      _accessToken = null;
      _refreshToken = null;
      _user = null;
      _isAuthenticated = false;
      CurrentShop.clear();
    }

    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  // CONNEXION
  // ═══════════════════════════════════════════════════════════

  Future<bool> login({
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _apiClient.clearAuthToken();

      final response = await _apiClient.post('/auth/login/', {
        'phone': phone,
        'password': password,
      });

      if (response.success && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        await _saveSession(data);
        return true;
      }

      debugPrint('Login échoué');
      return false;
    } catch (e) {
      debugPrint('Erreur login');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // INSCRIPTION
  // ═══════════════════════════════════════════════════════════

  Future<bool> register({
    required String phone,
    required String password,
    required String shopName,
    String? firstName,
    String? lastName,
    String currency = 'FCFA',
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.post('/auth/register/', {
        'phone': phone,
        'password': password,
        'shop_name': shopName,
        'first_name': firstName ?? '',
        'last_name': lastName ?? '',
        'currency': currency,
      });

      if (response.success && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        await _saveSession(data);
        return true;
      }

      debugPrint('Register échoué');
      return false;
    } catch (e) {
      debugPrint('Erreur register');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // SESSION
  // ═══════════════════════════════════════════════════════════

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final tokens = data['tokens'] as Map<String, dynamic>;
    _accessToken = tokens['access'] as String;
    _refreshToken = tokens['refresh'] as String;
    _user = data['user'] as Map<String, dynamic>?;
    _isAuthenticated = true;

    _apiClient.setAuthToken(_accessToken!);

    // ⚡ Définir le shop courant
    final shopId = _user?['shop']?['id'] as String?;
    CurrentShop.set(shopId);
    debugPrint('🔍 _saveSession → CurrentShop.shopId = $shopId');

    // Écrire les tokens dans le stockage sécurisé
    try {
      await _secureStorage.write(key: _keyAccessToken, value: _accessToken);
      await _secureStorage.write(key: _keyRefreshToken, value: _refreshToken);
    } catch (e) {
      debugPrint('Erreur écriture token sécurisé');
    }

    // Écrire le user dans SharedPreferences
    if (_user != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyUser, jsonEncode(_user));
      } catch (e) {
        debugPrint('Erreur écriture user');
      }
    }

    notifyListeners();
  }

  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    _isAuthenticated = false;
    _apiClient.clearAuthToken();

    // ⚡ Effacer le shop courant
    CurrentShop.clear();
    debugPrint('🔍 logout → CurrentShop effacé');

    try {
      await _secureStorage.delete(key: _keyAccessToken);
      await _secureStorage.delete(key: _keyRefreshToken);
    } catch (e) {
      debugPrint('Erreur suppression token sécurisé');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUser);
    } catch (e) {
      debugPrint('Erreur suppression user');
    }

    notifyListeners();
  }

  Future<void> forceLogout() async {
    await logout();
    await resetDeviceVerification();
  }

  // ═══════════════════════════════════════════════════════════
  // VÉRIFICATION D'APPAREIL
  // ═══════════════════════════════════════════════════════════

  Future<bool> isDeviceVerified(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final verified = prefs.getBool(_keyDeviceVerified) ?? false;
    final savedPhone = prefs.getString(_keyVerifiedPhone);
    return verified && savedPhone == phone;
  }

  Future<void> markDeviceAsVerified(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDeviceVerified, true);
    await prefs.setString(_keyVerifiedPhone, phone);
  }

  Future<void> resetDeviceVerification() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDeviceVerified);
    await prefs.remove(_keyVerifiedPhone);
  }

  Future<String?> getVerifiedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyVerifiedPhone);
  }

  Future<bool> hasVerifiedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyVerifiedPhone) != null &&
        (prefs.getBool(_keyDeviceVerified) ?? false);
  }

  // ═══════════════════════════════════════════════════════════
  // CHANGEMENT DE MOT DE PASSE
  // ═══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> changePassword({
    String? oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _apiClient.post('/auth/change-password/', {
        if (oldPassword != null) 'old_password': oldPassword,
        'new_password': newPassword,
      });

      if (response.success && response.body != null) {
        final data = response.body as Map<String, dynamic>;

        if (data['user'] != null) {
          _user = data['user'] as Map<String, dynamic>;

          // ⚡ Mettre à jour le shop courant
          final shopId = _user?['shop']?['id'] as String?;
          CurrentShop.set(shopId);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyUser, jsonEncode(_user));
        }

        notifyListeners();
        return {'success': true};
      }

      String errorMessage = 'Erreur lors du changement';
      if (response.body is Map && response.body['error'] != null) {
        errorMessage = response.body['error'] as String;
      }

      return {'success': false, 'error': errorMessage};
    } catch (e) {
      debugPrint('Erreur changePassword');
      return {'success': false, 'error': 'Erreur de connexion'};
    }
  }
}
