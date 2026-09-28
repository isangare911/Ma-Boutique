import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  // Singleton pour partager le même client partout
  static final ApiClient instance = ApiClient._();
  ApiClient._();

  // URL de l'API Cloud (Railway)
  static const String baseUrl =
      'https://ma-boutique-backend-production.up.railway.app/api/v1';

  // Timeout en secondes
  static const int timeoutSeconds = 30;

  String? _authToken;

  /// Définit le token d'authentification
  void setAuthToken(String token) => _authToken = token;

  void clearAuthToken() => _authToken = null;

  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  /// POST générique
  Future<ApiResponse> post(String endpoint, Map<String, dynamic> body) async {
    final url = '$baseUrl$endpoint';
    debugPrint('🌐 POST $url');
    debugPrint('📦 Body: ${jsonEncode(body)}');

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: _getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: timeoutSeconds));

      debugPrint('📥 Status: ${response.statusCode}');
      debugPrint('📥 Body: ${response.body}');

      return ApiResponse(
        success: response.statusCode >= 200 && response.statusCode < 300,
        statusCode: response.statusCode,
        body: response.body.isNotEmpty ? jsonDecode(response.body) : null,
      );
    } catch (e) {
      debugPrint('❌ Erreur POST: $e');
      return ApiResponse(
        success: false,
        statusCode: 0,
        error: e.toString(),
      );
    }
  }

  /// GET générique
  Future<ApiResponse> get(String endpoint) async {
    final url = '$baseUrl$endpoint';
    debugPrint('🌐 GET $url');

    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: _getHeaders(),
          )
          .timeout(const Duration(seconds: timeoutSeconds));

      debugPrint('📥 Status: ${response.statusCode}');

      return ApiResponse(
        success: response.statusCode >= 200 && response.statusCode < 300,
        statusCode: response.statusCode,
        body: response.body.isNotEmpty ? jsonDecode(response.body) : null,
      );
    } catch (e) {
      debugPrint('❌ Erreur GET: $e');
      return ApiResponse(
        success: false,
        statusCode: 0,
        error: e.toString(),
      );
    }
  }

  /// PATCH générique
  Future<ApiResponse> patch(String endpoint, Map<String, dynamic> body) async {
    final url = '$baseUrl$endpoint';
    debugPrint('🌐 PATCH $url');

    try {
      final response = await http
          .patch(
            Uri.parse(url),
            headers: _getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: timeoutSeconds));

      debugPrint('📥 Status: ${response.statusCode}');

      return ApiResponse(
        success: response.statusCode >= 200 && response.statusCode < 300,
        statusCode: response.statusCode,
        body: response.body.isNotEmpty ? jsonDecode(response.body) : null,
      );
    } catch (e) {
      debugPrint('❌ Erreur PATCH: $e');
      return ApiResponse(
        success: false,
        statusCode: 0,
        error: e.toString(),
      );
    }
  }

  /// PUT générique
  Future<ApiResponse> put(String endpoint, Map<String, dynamic> body) async {
    final url = '$baseUrl$endpoint';
    debugPrint('🌐 PUT $url');

    try {
      final response = await http
          .put(
            Uri.parse(url),
            headers: _getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: timeoutSeconds));

      debugPrint('📥 Status: ${response.statusCode}');

      return ApiResponse(
        success: response.statusCode >= 200 && response.statusCode < 300,
        statusCode: response.statusCode,
        body: response.body.isNotEmpty ? jsonDecode(response.body) : null,
      );
    } catch (e) {
      debugPrint('❌ Erreur PUT: $e');
      return ApiResponse(
        success: false,
        statusCode: 0,
        error: e.toString(),
      );
    }
  }

  /// DELETE générique
  Future<ApiResponse> delete(String endpoint) async {
    final url = '$baseUrl$endpoint';
    debugPrint('🌐 DELETE $url');

    try {
      final response = await http
          .delete(
            Uri.parse(url),
            headers: _getHeaders(),
          )
          .timeout(const Duration(seconds: timeoutSeconds));

      debugPrint('📥 Status: ${response.statusCode}');

      return ApiResponse(
        success: response.statusCode >= 200 && response.statusCode < 300,
        statusCode: response.statusCode,
      );
    } catch (e) {
      debugPrint('❌ Erreur DELETE: $e');
      return ApiResponse(
        success: false,
        statusCode: 0,
        error: e.toString(),
      );
    }
  }
}

class ApiResponse {
  final bool success;
  final int statusCode;
  final dynamic body;
  final String? error;

  ApiResponse({
    required this.success,
    required this.statusCode,
    this.body,
    this.error,
  });

  @override
  String toString() =>
      'ApiResponse(success: $success, status: $statusCode, error: $error)';
}
