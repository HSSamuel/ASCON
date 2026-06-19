import 'dart:io';
import 'dart:convert';
import 'dart:async';
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
import 'biometric_service.dart';

import '../viewmodels/chat_view_model.dart';
import '../viewmodels/directory_view_model.dart';
import '../viewmodels/events_view_model.dart';
import '../viewmodels/profile_view_model.dart';
import '../viewmodels/dashboard_view_model.dart';
import '../viewmodels/updates_view_model.dart';
import '../viewmodels/badge_view_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final ApiClient _api = ApiClient();
  static String? _tokenCache;
  final _secureStorage = StorageConfig.storage;

  static final GoogleSignIn googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? AppConfig.googleWebClientId : null,
    serverClientId: kIsWeb ? null : AppConfig.googleWebClientId,
    scopes: ['email', 'profile'],
  );

  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  AuthService._internal() {
    _api.onTokenRefresh = _performSilentRefresh;
  }

  void performGlobalSilentSync() {
    try {
      providerContainer.read(chatProvider.notifier).loadConversations();
      providerContainer.read(badgeProvider.notifier).refreshBadges();
      providerContainer.read(directoryProvider.notifier).loadDirectory();
      providerContainer.read(eventsProvider.notifier).loadEvents(silent: true);
      providerContainer.read(updatesProvider.notifier).loadData(silent: true);
      providerContainer.read(profileProvider.notifier).loadProfile(isRefresh: true);
      providerContainer.read(dashboardProvider.notifier).loadData(isRefresh: true);
      
      SocketService().announcePresence();
    } catch (e) {
      debugPrint("⚠️ Silent Sync Error: $e");
    }
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
    await _secureStorage.write(key: 'use_biometrics', value: 'true');
    await _secureStorage.write(key: 'bio_email', value: email);
    await _secureStorage.write(key: 'bio_password', value: password);
  }

  Future<Map<String, String>?> getBiometricCredentials() async {
    String? email = await _secureStorage.read(key: 'bio_email');
    String? password = await _secureStorage.read(key: 'bio_password');
    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  Future<bool> isBiometricEnabled() async {
    String? enabled = await _secureStorage.read(key: 'use_biometrics');
    return enabled == 'true';
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

  // =======================================================================
  // 🚀 WEB-SAFE REGISTER METHOD (Uses Bytes instead of File paths)
  // =======================================================================
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    required String programmeTitle,
    required String yearOfAttendance,
    String? customProgramme,
    String? jobTitle,
    String? organization,
    String? bio,
    String? googleToken,
    Uint8List? profileImageBytes, // ✅ Accept raw bytes instead of a File object
    String? profileImageName,     // ✅ Require the file name
  }) async {
    try {
      final String? fcmToken = await _getFcmToken();
      
      var uri = Uri.parse('${AppConfig.baseUrl}/api/auth/register');
      var request = http.MultipartRequest('POST', uri);

      request.fields['fullName'] = fullName;
      request.fields['email'] = email;
      request.fields['password'] = password;
      request.fields['programmeTitle'] = programmeTitle;
      request.fields['yearOfAttendance'] = yearOfAttendance;
      request.fields['customProgramme'] = customProgramme ?? "";
      request.fields['jobTitle'] = jobTitle ?? "";
      request.fields['organization'] = organization ?? "";
      request.fields['bio'] = bio ?? "";
      
      if (googleToken != null) request.fields['googleToken'] = googleToken;
      if (fcmToken != null) request.fields['fcmToken'] = fcmToken;

      // ✅ Upload purely via bytes (100% Web safe)
      if (profileImageBytes != null && profileImageName != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'profilePicture', 
            profileImageBytes,
            filename: profileImageName,
          )
        );
      }

      var streamedResponse = await request.send().timeout(AppConfig.apiTimeout);
      var response = await http.Response.fromStream(streamedResponse);
      
      var resultBody = jsonDecode(response.body);
      bool isSuccess = response.statusCode >= 200 && response.statusCode < 300;

      Map<String, dynamic> formattedResult = {
        'success': isSuccess,
        if (isSuccess) 'data': resultBody,
        if (!isSuccess) 'message': resultBody['message'] ?? 'Registration failed',
      };

      if (formattedResult['success'] && formattedResult['data']['token'] != null) {
        final data = formattedResult['data'];
        await _saveUserSession(data['token'], data['user'] ?? {}, refreshToken: data['refreshToken']);
        await NotificationService().init();
        await NotificationService().syncToken(retry: true);
      }
      
      return formattedResult;

    } catch (e) {
      return {'success': false, 'message': _cleanError(e)};
    }
  }

  Future<Map<String, dynamic>> googleLogin(String? idToken) async {
    try {
      String? tokenToSend = idToken;

      if (tokenToSend == null && !kIsWeb) {
        try {
          final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
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
      
      final userMap = await getCachedUser();
      if (userMap != null) {
        userMap['hasSeenWelcome'] = true;
        await _secureStorage.write(key: 'cached_user', value: jsonEncode(userMap));
      }
    } catch (e) {
      debugPrint("Failed to mark welcome as seen: $e");
    }
  }

  Future<String?> _performSilentRefresh() async {
    if (_isRefreshing) {
      return await _refreshCompleter?.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();

    try {
      String? originalRefreshToken = await _secureStorage.read(key: 'refresh_token');
      if (originalRefreshToken == null || originalRefreshToken.isEmpty) {
        _refreshCompleter?.complete(null);
        return null;
      }

      final result = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': originalRefreshToken}),
      );

      if (result.statusCode == 200) {
        final body = jsonDecode(result.body);
        final newToken = body['token'];

        if (newToken != null && newToken.isNotEmpty) {
          _tokenCache = newToken;
          await _secureStorage.write(key: 'auth_token', value: newToken);
          _api.setAuthToken(newToken);
          _refreshCompleter?.complete(newToken);
          return newToken;
        }
      } 
      else if (result.statusCode == 401 || result.statusCode == 403 || result.statusCode == 400) {
        
        bool isGenuineRejection = false;
        try {
          final body = jsonDecode(result.body);
          if (body is Map && body.containsKey('message')) {
            isGenuineRejection = true;
          }
        } catch (_) {
          isGenuineRejection = false;
        }

        if (!isGenuineRejection) {
          debugPrint("⚠️ Proxy/WAF error (${result.statusCode}) during refresh. Keeping local session alive.");
          _refreshCompleter?.complete(_tokenCache); 
          return _tokenCache;
        }

        String? currentRefreshToken = await _secureStorage.read(key: 'refresh_token');
        if (currentRefreshToken != originalRefreshToken && currentRefreshToken != null) {
          debugPrint("✅ Refresh aborted: User manually logged in during background refresh.");
          _refreshCompleter?.complete(_tokenCache);
          return _tokenCache;
        }

        if (!kIsWeb) {
          try {
            if (await googleSignIn.isSignedIn()) {
              final googleUser = await googleSignIn.signInSilently();
              if (googleUser != null) {
                final auth = await googleUser.authentication;
                final res = await googleLogin(auth.idToken ?? auth.accessToken);
                if (res['success']) {
                  _refreshCompleter?.complete(_tokenCache);
                  return _tokenCache;
                }
              }
            }
          } catch (e) {
             debugPrint("Silent Google Auth failed: $e");
          }
        }

        debugPrint("🚫 Token explicitly rejected by server (${result.statusCode}). Forcing logout.");
        await logout();
        _refreshCompleter?.complete(null);
        return null;
      } 
      else {
        debugPrint("⚠️ Server error or timeout during refresh (${result.statusCode}). Keeping local session alive.");
        _refreshCompleter?.complete(_tokenCache);
        return _tokenCache;
      }
    } catch (e) {
      debugPrint("⚠️ Network error during refresh: $e. Keeping local session alive.");
      _refreshCompleter?.complete(_tokenCache);
      return _tokenCache;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
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
        
        performGlobalSilentSync();
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
      if (_tokenCache != null && _tokenCache!.isNotEmpty) {
         bool isExpiredCache = JwtDecoder.isExpired(_tokenCache!) || JwtDecoder.getRemainingTime(_tokenCache!).inSeconds < 60;
         if (!isExpiredCache) return _tokenCache;
      }

      String? token = await _secureStorage.read(key: 'auth_token');
      String? refreshToken = await _secureStorage.read(key: 'refresh_token');

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
        return await _performSilentRefresh();
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
      await Future(() async {
        final String? fcmToken = await _getFcmToken().timeout(const Duration(seconds: 1), onTimeout: () => null);
        final String? refreshToken = await _secureStorage.read(key: 'refresh_token');
        final String? userId = await currentUserId;

        if (userId != null) {
          await http.post(
            Uri.parse('${AppConfig.baseUrl}/api/auth/logout'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${_tokenCache ?? ""}'},
            body: jsonEncode({
              'userId': userId,
              'fcmToken': fcmToken ?? "",
              'refreshToken': refreshToken ?? ""
            }),
          );
        }

        if (googleSignIn.currentUser != null) {
          await googleSignIn.disconnect();
        }
        await googleSignIn.signOut();
        
        SocketService().disconnect();

      }).timeout(const Duration(seconds: 3)); 
    } catch (e) {
      debugPrint("⚠️ Remote cleanup timed out or failed: $e. Proceeding to local cleanup.");
    }

    try {
      providerContainer.read(chatProvider.notifier).clearState();
      providerContainer.read(directoryProvider.notifier).clearState();
      providerContainer.read(eventsProvider.notifier).clearState();
    } catch (e) {
      debugPrint("⚠️ Memory sweep error: $e");
    }

    try {
      _tokenCache = null;
      await _secureStorage.delete(key: 'auth_token');
      await _secureStorage.delete(key: 'refresh_token');
      await _secureStorage.delete(key: 'userId');
      await _secureStorage.delete(key: 'cached_user');

      if (clearBiometrics) {
        await _secureStorage.delete(key: 'use_biometrics');
        await _secureStorage.delete(key: 'bio_email');
        await _secureStorage.delete(key: 'bio_password');
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