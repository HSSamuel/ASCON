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

  final _secureStorage = StorageConfig.storage;
  
  // ✅ 1. Add an in-memory token variable
  String? _memoryToken;

  Future<String?> Function()? onTokenRefresh;

  // ✅ ADDED: Mutex lock variables for Token Refresh Race Conditions
  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  // ✅ 2. Implement the setter to catch the token from AuthService
  void setAuthToken(String token) {
    _memoryToken = token;
  }

  // ✅ 3. Clear memory on logout
  void clearAuthToken() {
    _memoryToken = null;
  }

  Future<Map<String, String>> _getSecureHeaders() async {
    // ✅ 4. Use the memory token first. Only hit SecureStorage if memory is empty.
    final token = _memoryToken ?? await _secureStorage.read(key: 'auth_token');
    
    // Cache it immediately so subsequent requests don't hit SecureStorage
    if (token != null) {
      _memoryToken = token;
    }

    return {
      'Content-Type': 'application/json',
      if (token != null) 'auth-token': token, 
    };
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body, {bool requiresAuth = true}) async {
    final response = await _request(() async {
      final headers = requiresAuth 
          ? await _getSecureHeaders() 
          : {'Content-Type': 'application/json'}; 
          
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
      var response = await req().timeout(AppConfig.apiTimeout);

      if (response.statusCode == 401 && onTokenRefresh != null) {
        String? newToken;

        // ✅ FIX: Lock the refresh process so concurrent 401s don't spam the server
        if (!_isRefreshing) {
          _isRefreshing = true;
          _refreshCompleter = Completer<String?>();
          print("🔄 401 Detected. Attempting Refresh (Locked)...");

          try {
            newToken = await onTokenRefresh!();
            _refreshCompleter!.complete(newToken);
          } catch (e) {
            _refreshCompleter!.completeError(e);
          } finally {
            _isRefreshing = false; // Release lock
          }
        } else {
          print("⏳ Refresh in progress. Waiting for lock to release...");
          // Wait for the active refresh to finish
          newToken = await _refreshCompleter!.future; 
        }

        if (newToken != null) {
          print("✅ Token Refreshed. Retrying Request...");
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