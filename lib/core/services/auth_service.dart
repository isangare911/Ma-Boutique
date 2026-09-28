import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';

class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._();
  AuthService._();

  final ApiClient _apiClient = ApiClient.instance;

  // ⚡ Stockage sécurisé pour les tokens
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // ⚡ Clés sécurisées (tokens)
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';

  // ⚡ Clés non sensibles (restent dans SharedPreferences)
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
    // ⚡ Lire les tokens depuis le stockage sécurisé
    _accessToken = await _secureStorage.read(key: _keyAccessToken);
    _refreshToken = await _secureStorage.read(key: _keyRefreshToken);
    _isAuthenticated = _accessToken != null;

    if (_isAuthenticated) {
      _apiClient.setAuthToken(_accessToken!);
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

      debugPrint('Login échoué: ${response.error ?? "Identifiants invalides"}');
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

    // ⚡ Écrire les tokens dans le stockage sécurisé
    await _secureStorage.write(key: _keyAccessToken, value: _accessToken);
    await _secureStorage.write(key: _keyRefreshToken, value: _refreshToken);

    notifyListeners();
  }

  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    _isAuthenticated = false;
    _apiClient.clearAuthToken();

    // ⚡ Effacer les tokens du stockage sécurisé
    await _secureStorage.delete(key: _keyAccessToken);
    await _secureStorage.delete(key: _keyRefreshToken);

    // ⚡ NE PAS toucher à _keyDeviceVerified (SharedPreferences)
    // pour ne pas refaire l'OTP à la reconnexion

    notifyListeners();
  }

  Future<void> forceLogout() async {
    await logout();
    await resetDeviceVerification();
  }

  // ═══════════════════════════════════════════════════════════
  // VÉRIFICATION D'APPAREIL (SharedPreferences — non sensible)
  // ═══════════════════════════════════════════════════════════

  Future<bool> isDeviceVerified(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final verified = prefs.getBool(_keyDeviceVerified) ?? false;
    final savedPhone = prefs.getString(_keyVerifiedPhone);

    final result = verified && savedPhone == phone;
    debugPrint('Device vérifié pour ce numéro ? $result');
    return result;
  }

  Future<void> markDeviceAsVerified(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDeviceVerified, true);
    await prefs.setString(_keyVerifiedPhone, phone);
    debugPrint('✓ Appareil marqué comme vérifié');
  }

  Future<void> resetDeviceVerification() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDeviceVerified);
    await prefs.remove(_keyVerifiedPhone);
    debugPrint('✓ Vérification d\'appareil réinitialisée');
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
}
