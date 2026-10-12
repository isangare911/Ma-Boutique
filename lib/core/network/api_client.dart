import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  // Singleton
  static final ApiClient instance = ApiClient._();
  ApiClient._();

  static const String baseUrl =
      'https://ma-boutique-backend-production.up.railway.app/api/v1';

  static const int timeoutSeconds = 30;

  String? _authToken;

  // ⚡ Callback pour notifier un 401 (déclenche refresh ou logout)
  Future<String?> Function()? onUnauthorized;

  void setAuthToken(String token) => _authToken = token;
  void clearAuthToken() => _authToken = null;
  bool get hasToken => _authToken != null;

  Map<String, String> _getHeaders({bool withContentType = true}) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (withContentType) {
      headers['Content-Type'] = 'application/json';
    }
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  /// ⚡ Masque les champs sensibles avant log
  Map<String, dynamic> _sanitizeForLog(Map<String, dynamic> body) {
    const sensitive = {
      'password',
      'old_password',
      'new_password',
      'access',
      'refresh',
      'access_token',
      'refresh_token',
      'token',
    };
    final out = <String, dynamic>{};
    body.forEach((key, value) {
      if (sensitive.contains(key)) {
        out[key] = '***';
      } else if (value is Map<String, dynamic>) {
        out[key] = _sanitizeForLog(value);
      } else {
        out[key] = value;
      }
    });
    return out;
  }

  /// ⚡ Tronque le body pour éviter de logger 10 KB
  String _safeBodyPreview(String body) {
    // Ne log jamais plus de 500 caractères, et masque les tokens évidents
    final cleaned = body.length > 500 ? '${body.substring(0, 500)}...' : body;
    return cleaned;
  }

  /// ⚡ Gestion d'un 401 : tente le refresh, sinon logout
  Future<void> _handleUnauthorized() async {
    if (onUnauthorized != null) {
      final newToken = await onUnauthorized!();
      if (newToken != null) {
        _authToken = newToken;
      }
    }
  }

  Future<ApiResponse> _send({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
  }) async {
    final url = '$baseUrl$endpoint';

    if (kDebugMode) {
      debugPrint('🌐 $method $url');
      if (body != null) {
        debugPrint('📦 Body: ${jsonEncode(_sanitizeForLog(body))}');
      }
    }

    try {
      late http.Response response;
      final uri = Uri.parse(url);
      final headersWithCt = _getHeaders(withContentType: body != null);
      final headersNoCt = _getHeaders(withContentType: false);

      switch (method) {
        case 'POST':
          response = await http
              .post(uri, headers: headersWithCt, body: jsonEncode(body))
              .timeout(const Duration(seconds: timeoutSeconds));
          break;
        case 'PUT':
          response = await http
              .put(uri, headers: headersWithCt, body: jsonEncode(body))
              .timeout(const Duration(seconds: timeoutSeconds));
          break;
        case 'PATCH':
          response = await http
              .patch(uri, headers: headersWithCt, body: jsonEncode(body))
              .timeout(const Duration(seconds: timeoutSeconds));
          break;
        case 'GET':
          response = await http
              .get(uri, headers: headersNoCt)
              .timeout(const Duration(seconds: timeoutSeconds));
          break;
        case 'DELETE':
          response = await http
              .delete(uri, headers: headersNoCt)
              .timeout(const Duration(seconds: timeoutSeconds));
          break;
        default:
          throw ArgumentError('Méthode HTTP non supportée: $method');
      }

      if (kDebugMode) {
        debugPrint('📥 Status: ${response.statusCode}');
        debugPrint('📥 Body: ${_safeBodyPreview(response.body)}');
      }

      // ⚡ 401 → tenter un refresh puis retourner la réponse
      if (response.statusCode == 401 && onUnauthorized != null) {
        await _handleUnauthorized();
      }

      return ApiResponse(
        success: response.statusCode >= 200 && response.statusCode < 300,
        statusCode: response.statusCode,
        body: response.body.isNotEmpty ? _tryDecode(response.body) : null,
      );
    } on TimeoutException {
      if (kDebugMode) debugPrint('⏱ Timeout $method $url');
      return ApiResponse(
        success: false,
        statusCode: 0,
        error: 'timeout',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur $method: $e');
      return ApiResponse(
        success: false,
        statusCode: 0,
        error: e.toString(),
      );
    }
  }

  dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  Future<ApiResponse> post(String endpoint, Map<String, dynamic> body) =>
      _send(method: 'POST', endpoint: endpoint, body: body);

  Future<ApiResponse> get(String endpoint) =>
      _send(method: 'GET', endpoint: endpoint);

  Future<ApiResponse> patch(String endpoint, Map<String, dynamic> body) =>
      _send(method: 'PATCH', endpoint: endpoint, body: body);

  Future<ApiResponse> put(String endpoint, Map<String, dynamic> body) =>
      _send(method: 'PUT', endpoint: endpoint, body: body);

  Future<ApiResponse> delete(String endpoint) =>
      _send(method: 'DELETE', endpoint: endpoint);
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

  // ⚡ Helpers pour faciliter les messages d'erreur
  bool get isUnauthorized => statusCode == 401;
  bool get isThrottled => statusCode == 429;
  bool get isServerError => statusCode >= 500;
  bool get isNetworkError => statusCode == 0;

  String? get errorMessage {
    if (body is Map) {
      final b = body as Map;
      if (b['error'] != null) return b['error'].toString();
      if (b['detail'] != null) return b['detail'].toString();
      // Gestion des erreurs de champ DRF
      if (b.isNotEmpty) {
        final firstKey = b.keys.first;
        final firstVal = b[firstKey];
        if (firstVal is List && firstVal.isNotEmpty) {
          return firstVal.first.toString();
        }
        return '$firstKey: $firstVal';
      }
    }
    return error;
  }

  @override
  String toString() =>
      'ApiResponse(success: $success, status: $statusCode, error: $error)';
}
