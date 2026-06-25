import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';
import '../config/storage_config.dart';

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
  
  String? _memoryToken;
  Future<String?> Function()? onTokenRefresh;
  
  // ✅ ADDED: Allows ApiClient to request the token dynamically so AuthService can proactively check expiry
  Future<String?> Function()? onGetToken; 

  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;
  
  bool isLoggingOut = false; 

  void setAuthToken(String token) {
    _memoryToken = token;
  }

  void clearAuthToken() {
    _memoryToken = null;
  }

  Future<Map<String, String>> _getSecureHeaders() async {
    String? token;
    
    // ✅ Always ask AuthService for the token first (this triggers the proactive expiry check)
    if (onGetToken != null) {
      token = await onGetToken!();
    } else {
      token = _memoryToken ?? await _secureStorage.read(key: 'auth_token');
    }
    
    if (token != null) {
      _memoryToken = token;
    }

    return {
      'Content-Type': 'application/json',
      if (token != null) 'auth-token': token, 
      if (token != null) 'Authorization': 'Bearer $token', // Redundant safety for backend middlewares
    };
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body, {bool requiresAuth = true}) async {
    final response = await _request(() async {
      final headers = requiresAuth ? await _getSecureHeaders() : {'Content-Type': 'application/json'}; 
      return http.post(Uri.parse('${AppConfig.baseUrl}$endpoint'), headers: headers, body: jsonEncode(body));
    });
    return response as Map<String, dynamic>; 
  }

  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> body, {bool requiresAuth = true}) async {
    final response = await _request(() async {
      final headers = requiresAuth ? await _getSecureHeaders() : {'Content-Type': 'application/json'};
      return http.put(Uri.parse('${AppConfig.baseUrl}$endpoint'), headers: headers, body: jsonEncode(body));
    });
    return response as Map<String, dynamic>;
  }

  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    return _request(() async {
      final headers = requiresAuth ? await _getSecureHeaders() : {'Content-Type': 'application/json'};
      return http.get(Uri.parse('${AppConfig.baseUrl}$endpoint'), headers: headers);
    });
  }

  Future<dynamic> delete(String endpoint, {bool requiresAuth = true}) async {
    return _request(() async {
      final headers = requiresAuth ? await _getSecureHeaders() : {'Content-Type': 'application/json'};
      return http.delete(Uri.parse('${AppConfig.baseUrl}$endpoint'), headers: headers);
    });
  }

  Future<dynamic> _request(Future<http.Response> Function() req) async {
    if (isLoggingOut) return await Completer<dynamic>().future;

    try {
      var response = await req().timeout(AppConfig.apiTimeout);

      if (response.statusCode == 401 && onTokenRefresh != null) {
        String? newToken;

        if (!_isRefreshing) {
          _isRefreshing = true;
          _refreshCompleter = Completer<String?>();
          try {
            newToken = await onTokenRefresh!();
            _refreshCompleter!.complete(newToken);
          } catch (e) {
            _refreshCompleter!.completeError(e);
            throw ApiException('Network unstable while verifying session. Please check your connection.', statusCode: 0);
          } finally {
            _isRefreshing = false; 
          }
        } else {
          try {
            newToken = await _refreshCompleter!.future; 
          } catch (e) {
            throw ApiException('Network unstable while verifying session. Please check your connection.', statusCode: 0);
          }
        }

        if (newToken != null) {
          response = await req().timeout(AppConfig.apiTimeout); 
        }
      }

      if (isLoggingOut) return await Completer<dynamic>().future;

      return _processResponse(response);
    } on TimeoutException {
      if (isLoggingOut) return await Completer<dynamic>().future;
      throw ApiException('Server is taking too long to respond. Please check your connection.', statusCode: 408);
    } on SocketException {
      if (isLoggingOut) return await Completer<dynamic>().future;
      throw ApiException('No internet connection. Please try again later.', statusCode: 0);
    } on ApiException {
      if (isLoggingOut) return await Completer<dynamic>().future;
      rethrow; 
    } catch (e) {
      if (isLoggingOut) return await Completer<dynamic>().future;
      throw ApiException('Connection error: $e');
    }
  }

  dynamic _processResponse(http.Response response) {
    dynamic body;
    try { body = jsonDecode(response.body); } catch (e) { body = {}; }
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {'success': true, 'statusCode': response.statusCode, 'data': body};
    } else {
      final errorMessage = (body is Map && body['message'] != null) ? body['message'] : 'Request failed with status ${response.statusCode}';
      throw ApiException(errorMessage, statusCode: response.statusCode);
    }
  }
}