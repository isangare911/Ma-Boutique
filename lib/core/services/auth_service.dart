import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';

class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._();
  AuthService._();

  final ApiClient _apiClient = ApiClient.instance;

  // ⚡ Clés SharedPreferences
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
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

  /// Charge les tokens sauvegardés au démarrage
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_keyAccessToken);
    _refreshToken = prefs.getString(_keyRefreshToken);
    _isAuthenticated = _accessToken != null;

    if (_isAuthenticated) {
      _apiClient.setAuthToken(_accessToken!);
    }
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  // CONNEXION
  // ═══════════════════════════════════════════════════════════

  /// Connexion via API
  Future<bool> login({
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // ⚡ Retirer tout ancien token avant le login
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
      debugPrint('Erreur login: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // INSCRIPTION
  // ═══════════════════════════════════════════════════════════

  /// Inscription via API
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

      debugPrint('Register échoué: ${response.error}');
      return false;
    } catch (e) {
      debugPrint('Erreur register: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // SESSION
  // ═══════════════════════════════════════════════════════════

  /// Sauvegarde la session (tokens + user)
  Future<void> _saveSession(Map<String, dynamic> data) async {
    final tokens = data['tokens'] as Map<String, dynamic>;
    _accessToken = tokens['access'] as String;
    _refreshToken = tokens['refresh'] as String;
    _user = data['user'] as Map<String, dynamic>?;
    _isAuthenticated = true;

    // Configurer le client API
    _apiClient.setAuthToken(_accessToken!);

    // Sauvegarder localement
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, _accessToken!);
    await prefs.setString(_keyRefreshToken, _refreshToken!);

    notifyListeners();
  }

  /// Déconnexion
  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    _isAuthenticated = false;
    _apiClient.clearAuthToken();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    // ⚡ Note : on NE supprime PAS _keyDeviceVerified
    // pour que l'utilisateur n'ait pas à refaire l'OTP à la reconnexion

    notifyListeners();
  }

  /// Déconnexion totale (avec effacement de la vérification)
  /// Utilisé uniquement en cas de manipulation de date
  Future<void> forceLogout() async {
    await logout();
    await resetDeviceVerification();
  }

  // ═══════════════════════════════════════════════════════════
  // ⚡ VÉRIFICATION D'APPAREIL (DEVICE VERIFICATION)
  // ═══════════════════════════════════════════════════════════

  /// Vérifie si cet appareil a déjà validé l'OTP pour ce numéro.
  /// Si oui, l'utilisateur n'a PAS besoin de refaire l'OTP à la connexion.
  Future<bool> isDeviceVerified(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final verified = prefs.getBool(_keyDeviceVerified) ?? false;
    final savedPhone = prefs.getString(_keyVerifiedPhone);

    final result = verified && savedPhone == phone;
    debugPrint('Device vérifié pour $phone ? $result');
    return result;
  }

  /// Marque cet appareil comme vérifié pour ce numéro
  /// (appelé après que l'utilisateur a validé l'OTP)
  Future<void> markDeviceAsVerified(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDeviceVerified, true);
    await prefs.setString(_keyVerifiedPhone, phone);
    debugPrint('✓ Appareil marqué comme vérifié pour $phone');
  }

  /// Réinitialise la vérification d'appareil
  /// (utilisé en cas de manipulation de date ou de problème de sécurité)
  Future<void> resetDeviceVerification() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDeviceVerified);
    await prefs.remove(_keyVerifiedPhone);
    debugPrint('✓ Vérification d\'appareil réinitialisée');
  }

  /// Retourne le numéro de téléphone vérifié (ou null si aucun)
  Future<String?> getVerifiedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyVerifiedPhone);
  }

  /// Vérifie si un numéro est stocké comme vérifié
  Future<bool> hasVerifiedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyVerifiedPhone) != null &&
        (prefs.getBool(_keyDeviceVerified) ?? false);
  }
}
