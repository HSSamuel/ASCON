import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config.dart';
import '../config/storage_config.dart';
import '../main.dart';
import '../router.dart';
import 'api_client.dart';
import 'notification_service.dart';
import 'socket_service.dart';

class AuthService {
  final ApiClient _api = ApiClient();
  static String? _tokenCache;
  final _secureStorage = StorageConfig.storage;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  AuthService() {
    _api.onTokenRefresh = _performSilentRefresh;
  }

  Future<bool> get isAdmin async {
    try {
      final userMap = await getCachedUser();
      if (userMap != null && userMap['isAdmin'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<String?> get currentUserId async {
    try {
      final userMap = await getCachedUser();
      return userMap?['id'] ?? userMap?['_id'];
    } catch (e) {
      return null;
    }
  }

  Future<void> enableBiometrics(String email, String password) async {
    await _secureStorage.write(key: 'biometric_email', value: email);
    await _secureStorage.write(key: 'biometric_password', value: password);
    await _secureStorage.write(key: 'use_biometrics', value: 'true');
  }

  Future<bool> isBiometricEnabled() async {
    String? enabled = await _secureStorage.read(key: 'use_biometrics');
    return enabled == 'true';
  }

  Future<Map<String, dynamic>> loginWithStoredCredentials() async {
    final email = await _secureStorage.read(key: 'biometric_email');
    final password = await _secureStorage.read(key: 'biometric_password');

    if (email != null && password != null) {
      return await login(email, password);
    }
    return {'success': false, 'message': 'No credentials stored'};
  }

  Future<String?> _getFcmToken() async {
    try {
      if (kIsWeb) {
        String? vapidKey = dotenv.env['FIREBASE_VAPID_KEY'];
        if (vapidKey == null || vapidKey.isEmpty) return null;
        return await FirebaseMessaging.instance.getToken(vapidKey: vapidKey);
      } else {
        return await FirebaseMessaging.instance.getToken();
      }
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final String? fcmToken = await _getFcmToken();
      final result = await _api.post('/api/auth/login', {
        'email': email,
        'password': password,
        'fcmToken': fcmToken ?? "",
      }, requiresAuth: false);

      if (result['success']) {
        final data = result['data'];
        await _saveUserSession(data['token'], data['user'], refreshToken: data['refreshToken']);
        await NotificationService().init();
        await NotificationService().syncToken(retry: true);
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': _cleanError(e)};
    }
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    required String phoneNumber,
    required String programmeTitle,
    required String yearOfAttendance,
    String? dateOfBirth,
    String? googleToken,
  }) async {
    try {
      final String? fcmToken = await _getFcmToken();
      final result = await _api.post('/api/auth/register', {
        'fullName': fullName,
        'email': email,
        'password': password,
        'phoneNumber': phoneNumber,
        'programmeTitle': programmeTitle,
        'yearOfAttendance': yearOfAttendance,
        'dateOfBirth': dateOfBirth,
        'googleToken': googleToken,
        'fcmToken': fcmToken ?? "",
      }, requiresAuth: false);

      if (result['success'] && result['data']['token'] != null) {
        final data = result['data'];
        await _saveUserSession(data['token'], data['user'] ?? {}, refreshToken: data['refreshToken']);
        await NotificationService().init();
        await NotificationService().syncToken(retry: true);
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': _cleanError(e)};
    }
  }

  Future<Map<String, dynamic>> googleLogin(String? idToken) async {
    try {
      String? tokenToSend = idToken;

      if (tokenToSend == null && !kIsWeb) {
        try {
          final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
          if (googleUser == null) return {'success': false, 'message': 'Sign in cancelled'};
          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
          tokenToSend = googleAuth.idToken ?? googleAuth.accessToken;
        } catch (e) {
          return {'success': false, 'message': 'Google Sign-In failed'};
        }
      }

      if (tokenToSend == null) return {'success': false, 'message': 'No Google Token'};

      final String? fcmToken = await _getFcmToken();
      final result = await _api.post('/api/auth/google', {
        'token': tokenToSend,
        'fcmToken': fcmToken ?? "",
      }, requiresAuth: false);

      if (result['success']) {
        final data = result['data'];
        await _saveUserSession(data['token'], data['user'], refreshToken: data['refreshToken']);
        await NotificationService().init();
        await NotificationService().syncToken(retry: true);
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': _cleanError(e)};
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      return await _api.post('/api/auth/forgot-password', {'email': email}, requiresAuth: false);
    } catch (e) {
      return {'success': false, 'message': _cleanError(e)};
    }
  }

  // ✅ THE MISSING METHOD RESTORED
  Future<List<dynamic>> getProgrammes() async {
    try {
      final result = await _api.get('/api/admin/programmes');
      if (result['success']) {
        final data = result['data'];
        return (data is Map && data.containsKey('programmes'))
            ? data['programmes']
            : (data is List ? data : []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> markWelcomeSeen() async {
    try {
      await _api.put('/api/profile/welcome-seen', {});
    } catch (e) {}
  }

  Future<String?> _performSilentRefresh() async {
    try {
      String? refreshToken = await _secureStorage.read(key: 'refresh_token');
      if (refreshToken == null) return null;

      final result = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (result.statusCode == 200) {
        final body = jsonDecode(result.body);
        final newToken = body['token'];

        if (newToken != null) {
          _tokenCache = newToken;
          await _secureStorage.write(key: 'auth_token', value: newToken);
          _api.setAuthToken(newToken);
          return newToken;
        }
      } else {
        await logout();
        return null;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<void> _saveUserSession(String token, Map<String, dynamic> user, {String? refreshToken}) async {
    try {
      _tokenCache = token;
      _api.setAuthToken(token);

      await _secureStorage.write(key: 'auth_token', value: token);
      if (refreshToken != null) {
        await _secureStorage.write(key: 'refresh_token', value: refreshToken);
      }

      await _secureStorage.write(key: 'cached_user', value: jsonEncode(user));

      final userId = user['id'] ?? user['_id'];
      if (userId != null) {
        await _secureStorage.write(key: 'userId', value: userId);
        SocketService().connectUser(userId);
      }

      final prefs = await SharedPreferences.getInstance();
      if (user['fullName'] != null) await prefs.setString('user_name', user['fullName']);
      if (user['alumniId'] != null) await prefs.setString('alumni_id', user['alumniId']);
    } catch (e) {
      debugPrint("⚠️ Session Save Error: $e");
    }
  }

  Future<String?> getToken() async {
    try {
      if (_tokenCache != null && _tokenCache!.isNotEmpty) return _tokenCache;

      String? token = await _secureStorage.read(key: 'auth_token');
      String? refreshToken = await _secureStorage.read(key: 'refresh_token');

      // Migration fallback
      if (token == null) {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('auth_token');
        if (token != null) {
          await _secureStorage.write(key: 'auth_token', value: token);
          await prefs.remove('auth_token');
        }
      }

      if (token == null) return null;

      bool isExpired = JwtDecoder.isExpired(token) || JwtDecoder.getRemainingTime(token).inSeconds < 60;

      if (isExpired && refreshToken != null) {
        try {
          final result = await _api.post('/api/auth/refresh', {'refreshToken': refreshToken});
          if (result['success']) {
            final newToken = result['data']['token'];
            _tokenCache = newToken;
            await _secureStorage.write(key: 'auth_token', value: newToken);
            _api.setAuthToken(newToken);
            return newToken;
          }
        } catch (e) {}
        return null;
      }

      _tokenCache = token;
      _api.setAuthToken(token);
      return token;
    } catch (e) {
      return null;
    }
  }

  Future<bool> isSessionValid() async {
    final token = await getToken();
    return token != null;
  }

  Future<Map<String, dynamic>?> getCachedUser() async {
    final userData = await _secureStorage.read(key: 'cached_user');
    return userData != null ? jsonDecode(userData) : null;
  }

  Future<void> logout({bool clearBiometrics = false}) async {
    try {
      SocketService().disconnect();
    } catch (_) {}

    try {
      if (_googleSignIn.currentUser != null) {
        await _googleSignIn.disconnect();
      }
      await _googleSignIn.signOut();
    } catch (_) {}

    try {
      _tokenCache = null;
      await _secureStorage.delete(key: 'auth_token');
      await _secureStorage.delete(key: 'refresh_token');
      await _secureStorage.delete(key: 'userId');
      await _secureStorage.delete(key: 'cached_user');

      if (clearBiometrics) {
        await _secureStorage.delete(key: 'biometric_email');
        await _secureStorage.delete(key: 'biometric_password');
        await _secureStorage.delete(key: 'use_biometrics');
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _api.clearAuthToken();

    if (kIsWeb) await Future.delayed(const Duration(milliseconds: 200));

    appRouter.go('/login');
  }

  String _cleanError(Object e) {
    String error = e.toString();
    if (error.contains("SocketException") || error.contains("Network is unreachable")) {
      return "No internet connection. Please check your network.";
    }
    if (error.contains("TimeoutException")) {
      return "Server took too long to respond.";
    }
    return error.replaceAll("Exception: ", "").replaceAll("ApiException: ", "");
  }
}