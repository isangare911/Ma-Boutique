import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_client.dart';
import 'current_shop.dart';

/// ⚡ Résultat typé du login (permet de distinguer throttling / réseau / identifiants)
class LoginResult {
  final bool success;
  final String? error;
  final int? statusCode;
  final bool mustChangePassword;
  final String? subscriptionStatus;

  LoginResult({
    required this.success,
    this.error,
    this.statusCode,
    this.mustChangePassword = false,
    this.subscriptionStatus,
  });

  bool get isThrottled => statusCode == 429;
  bool get isNetworkError => statusCode == 0;
}

/// ⚡ Résultat typé de l'inscription
class RegisterResult {
  final bool success;
  final String? error;
  final int? statusCode;

  RegisterResult({
    required this.success,
    this.error,
    this.statusCode,
  });

  bool get isThrottled => statusCode == 429;
  bool get isNetworkError => statusCode == 0;
}

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
  bool _refreshing = false;

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

      // ⚡ Lire le user depuis le MÊME storage que celui utilisé pour l'écrire
      final userJson = await _secureStorage.read(key: _keyUser);

      if (userJson != null) {
        try {
          final decoded = jsonDecode(userJson);
          if (decoded is Map) {
            _user = Map<String, dynamic>.from(decoded);
            debugPrint('🔍 initialize → user rechargé: ${_user?['phone']} '
                '(shop: ${_user?['shop']?['name']})');
          }
        } catch (e) {
          debugPrint('⚠ Erreur parsing user, suppression');
          await _secureStorage.delete(key: _keyUser);
          _user = null;
        }
      }

      _isAuthenticated = _accessToken != null;

      if (_isAuthenticated) {
        _apiClient.setAuthToken(_accessToken!);

        // ⚡ Brancher le refresh automatique
        _apiClient.onUnauthorized = () async {
          return await refreshAccessToken();
        };

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

  Future<LoginResult> login({
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _apiClient.clearAuthToken();

      // ⚡ Vider l'ancien user AVANT le nouveau login
      // (évite de mélanger les données entre 2 sessions)
      _user = null;
      _accessToken = null;
      _refreshToken = null;
      _isAuthenticated = false;

      final response = await _apiClient.post('/auth/login/', {
        'phone': phone,
        'password': password,
      });

      if (response.success && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        await _saveSession(data);

        final mustChange = _user?['must_change_password'] == true;
        final subStatus = _user?['shop']?['subscription_status'] as String?;

        return LoginResult(
          success: true,
          mustChangePassword: mustChange,
          subscriptionStatus: subStatus,
        );
      }

      return LoginResult(
        success: false,
        statusCode: response.statusCode,
        error: response.errorMessage ?? 'Identifiants invalides',
      );
    } catch (e) {
      debugPrint('Erreur login');
      return LoginResult(
        success: false,
        statusCode: 0,
        error: 'Erreur de connexion',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // INSCRIPTION
  // ═══════════════════════════════════════════════════════════

  Future<RegisterResult> register({
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
        return RegisterResult(success: true);
      }

      return RegisterResult(
        success: false,
        statusCode: response.statusCode,
        error: response.errorMessage ?? 'Inscription échouée',
      );
    } catch (e) {
      debugPrint('Erreur register');
      return RegisterResult(
        success: false,
        statusCode: 0,
        error: 'Erreur de connexion',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // REFRESH TOKEN
  // ═══════════════════════════════════════════════════════════

  /// ⚡ Rafraîchit l'access token via le refresh token.
  /// Retourne le nouveau token ou null si échec (logout auto).
  Future<String?> refreshAccessToken() async {
    if (_refreshToken == null) return null;
    if (_refreshing) return _accessToken;

    _refreshing = true;

    try {
      final savedToken = _accessToken;
      _apiClient.clearAuthToken();

      final response = await _apiClient.post('/auth/token/refresh/', {
        'refresh': _refreshToken,
      });

      if (response.success && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        final newAccess = data['access'] as String?;
        final newRefresh = data['refresh'] as String?;

        if (newAccess == null) {
          if (savedToken != null) _apiClient.setAuthToken(savedToken);
          return null;
        }

        _accessToken = newAccess;
        _apiClient.setAuthToken(newAccess);

        await _secureStorage.write(key: _keyAccessToken, value: newAccess);

        if (newRefresh != null) {
          _refreshToken = newRefresh;
          await _secureStorage.write(
            key: _keyRefreshToken,
            value: newRefresh,
          );
        }

        debugPrint('✓ Access token rafraîchi');
        notifyListeners();
        return newAccess;
      }

      debugPrint('⚠ Refresh échoué → logout');
      await logout();
      return null;
    } catch (e) {
      debugPrint('Erreur refresh token');
      return null;
    } finally {
      _refreshing = false;
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

    // ⚡ Re-brancher onUnauthorized
    _apiClient.onUnauthorized = () async {
      return await refreshAccessToken();
    };

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

    // ⚡ Écrire le user dans le stockage sécurisé (PAS SharedPreferences)
    if (_user != null) {
      try {
        await _secureStorage.write(
          key: _keyUser,
          value: jsonEncode(_user),
        );
        debugPrint('🔍 _saveSession → user écrit dans secure storage');
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
    _apiClient.onUnauthorized = null;

    CurrentShop.clear();
    debugPrint('🔍 logout → CurrentShop effacé');

    try {
      await _secureStorage.delete(key: _keyAccessToken);
      await _secureStorage.delete(key: _keyRefreshToken);
      await _secureStorage.delete(key: _keyUser);
    } catch (e) {
      debugPrint('Erreur suppression token sécurisé');
    }

    notifyListeners();
  }

  Future<void> forceLogout() async {
    await logout();
    await resetDeviceVerification();
  }

  // ═══════════════════════════════════════════════════════════
  // VÉRIFICATION D'APPAREIL (legacy)
  // ═══════════════════════════════════════════════════════════

  Future<bool> isDeviceVerified(String phone) async {
    final verified = await _secureStorage.read(key: _keyDeviceVerified);
    final savedPhone = await _secureStorage.read(key: _keyVerifiedPhone);
    return verified == 'true' && savedPhone == phone;
  }

  Future<void> markDeviceAsVerified(String phone) async {
    await _secureStorage.write(key: _keyDeviceVerified, value: 'true');
    await _secureStorage.write(key: _keyVerifiedPhone, value: phone);
  }

  Future<void> resetDeviceVerification() async {
    await _secureStorage.delete(key: _keyDeviceVerified);
    await _secureStorage.delete(key: _keyVerifiedPhone);
  }

  Future<String?> getVerifiedPhone() async {
    return await _secureStorage.read(key: _keyVerifiedPhone);
  }

  Future<bool> hasVerifiedPhone() async {
    final verified = await _secureStorage.read(key: _keyDeviceVerified);
    final phone = await _secureStorage.read(key: _keyVerifiedPhone);
    return verified == 'true' && phone != null;
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

          final shopId = _user?['shop']?['id'] as String?;
          CurrentShop.set(shopId);

          try {
            await _secureStorage.write(
              key: _keyUser,
              value: jsonEncode(_user),
            );
          } catch (e) {
            debugPrint('Erreur écriture user après changePassword');
          }
        }

        notifyListeners();
        return {'success': true};
      }

      return {
        'success': false,
        'error': response.errorMessage ?? 'Erreur lors du changement',
      };
    } catch (e) {
      debugPrint('Erreur changePassword');
      return {'success': false, 'error': 'Erreur de connexion'};
    }
  }
}
