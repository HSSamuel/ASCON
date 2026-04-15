import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';
import '../config/storage_config.dart';

/// ✅ Custom Exception for typed error handling in ViewModels
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // ✅ ENCRYPTED VAULT FOR TOKENS
  final _secureStorage = StorageConfig.storage;

  // Callback to handle token refresh
  Future<String?> Function()? onTokenRefresh;

  // ✅ LOCKING MECHANISM VARIABLES
  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  // =========================================================
  // 🔐 DYNAMIC SECURE HEADER GENERATOR
  // =========================================================
  Future<Map<String, String>> _getSecureHeaders() async {
    final token = await _secureStorage.read(key: 'auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'auth-token': token, 
    };
  }

  // ✅ Legacy method kept for backward compatibility with AuthService
  void setAuthToken(String token) {
    // No longer needs to set a static map, as _getSecureHeaders reads dynamically
  }

  void clearAuthToken() {
    // Tokens are now cleared directly in AuthService via secureStorage.delete()
  }

  // ✅ FIX: Added {bool requiresAuth = true} to allow public requests
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body, {bool requiresAuth = true}) async {
    final response = await _request(() async {
      // ✅ LOGIC CHANGE: Only add secure headers if explicitly requested
      final headers = requiresAuth 
          ? await _getSecureHeaders() 
          : {'Content-Type': 'application/json'}; // Public Header
          
      return http.post(
        Uri.parse('${AppConfig.baseUrl}$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
    });
    return response as Map<String, dynamic>; 
  }

  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> body, {bool requiresAuth = true}) async {
    final response = await _request(() async {
      final headers = requiresAuth 
          ? await _getSecureHeaders() 
          : {'Content-Type': 'application/json'};
          
      return http.put(
        Uri.parse('${AppConfig.baseUrl}$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
    });
    return response as Map<String, dynamic>;
  }

  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    return _request(() async {
      final headers = requiresAuth 
          ? await _getSecureHeaders() 
          : {'Content-Type': 'application/json'};
          
      return http.get(
        Uri.parse('${AppConfig.baseUrl}$endpoint'),
        headers: headers,
      );
    });
  }

  Future<dynamic> delete(String endpoint, {bool requiresAuth = true}) async {
    return _request(() async {
      final headers = requiresAuth 
          ? await _getSecureHeaders() 
          : {'Content-Type': 'application/json'};
          
      return http.delete(
        Uri.parse('${AppConfig.baseUrl}$endpoint'),
        headers: headers,
      );
    });
  }

  Future<dynamic> _request(Future<http.Response> Function() req) async {
    try {
      // ✅ Use Centralized Timeout
      var response = await req().timeout(AppConfig.apiTimeout);

      // ✅ CRITICAL FIX: Handle Race Condition for 401
      if (response.statusCode == 401 && onTokenRefresh != null) {
        print("🔄 401 Detected. Attempting Refresh...");

        String? newToken;

        if (_isRefreshing) {
          print("⏳ Waiting for pending refresh...");
          newToken = await _refreshCompleter?.future;
        } else {
          _isRefreshing = true;
          _refreshCompleter = Completer<String?>();
          print("🔄 Initiating Silent Refresh...");

          try {
            newToken = await onTokenRefresh!();
            if (!(_refreshCompleter?.isCompleted ?? true)) {
              _refreshCompleter?.complete(newToken);
            }
          } catch (e) {
            if (!(_refreshCompleter?.isCompleted ?? true)) {
              _refreshCompleter?.complete(null);
            }
          } finally {
            _isRefreshing = false;
            _refreshCompleter = null;
          }
        }

        if (newToken != null) {
          print("✅ Token Refreshed. Retrying Request...");
          // This call to req() will now re-execute and pick up the NEW token
          response = await req().timeout(AppConfig.apiTimeout); 
        }
      }

      return _processResponse(response);
    } on TimeoutException {
      throw ApiException('Server is taking too long to respond. Please check your connection.', statusCode: 408);
    } on SocketException {
      throw ApiException('No internet connection. Please try again later.', statusCode: 0);
    } on ApiException {
      rethrow; 
    } catch (e) {
      throw ApiException('Connection error: $e');
    }
  }

  dynamic _processResponse(http.Response response) {
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (e) {
      body = {}; 
    }
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {
        'success': true,
        'statusCode': response.statusCode,
        'data': body
      };
    } else {
      final errorMessage = (body is Map && body['message'] != null) 
          ? body['message'] 
          : 'Request failed with status ${response.statusCode}';
      
      throw ApiException(errorMessage, statusCode: response.statusCode);
    }
  }
}