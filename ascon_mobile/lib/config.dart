import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class AppConfig {
  // =========================================================
  // 🌍 BASE URL (Dynamic)
  // =========================================================
  static String get baseUrl {
    String? url = dotenv.env['API_URL'];

    if (url == null || url.isEmpty) {
      throw Exception("⛔ FATAL ERROR: API_URL not found in .env file.");
    }

    // ✅ FIX: Automatically swap 'localhost' for '10.0.2.2' on Android Emulator
    if (kDebugMode && defaultTargetPlatform == TargetPlatform.android) {
      if (url.contains('localhost')) {
        url = url.replaceAll('localhost', '10.0.2.2');
        debugPrint("🤖 Android Emulator Detected: Switched API URL to $url");
      }
    }

    return url;
  }

  // =========================================================
  // 🔑 SECRETS
  // =========================================================
  static String get googleWebClientId {
    return dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';
  }
  
  static String? get googleClientId {
    return kIsWeb ? googleWebClientId : null; 
  }

  // =========================================================
  // 🔥 FIREBASE WEB CONFIGURATION
  // =========================================================
  static String get firebaseWebApiKey => "AIzaSyBBteJZoirarB77b3Cgo67njG6meoGNq_U";
  static String get firebaseWebAuthDomain => "ascon-alumni-91df2.firebaseapp.com";
  static String get firebaseWebProjectId => "ascon-alumni-91df2";
  static String get firebaseWebStorageBucket => "ascon-alumni-91df2.firebasestorage.app";
  static String get firebaseWebMessagingSenderId => "826004672204";
  static String get firebaseWebAppId => "1:826004672204:web:4352aaeba03118fb68fc69";
  static String get firebaseWebMeasurementId => "G-XYZ"; 

  // =========================================================
  // ⚙️ APP CONFIGURATION CONSTANTS
  // =========================================================
  
  // Network & Sockets
  static const Duration apiTimeout = Duration(seconds: 30);
  static const int socketTimeoutMs = 20000;      // ✅ Centralized
  static const int socketReconnectionDelayMs = 1000; // ✅ Centralized
  static String get unreadCountEndpoint => '$baseUrl/api/notifications/unread-count';

  // Notifications
  static const String notificationChannelId = 'ascon_high_importance'; 
  static const String notificationChannelName = 'ASCON Notifications';
  static const String notificationChannelDesc = 'This channel is used for important ASCON updates.';
  
  static const String callChannelId = 'ascon_call_channel';
  static const String callChannelName = 'Incoming Calls';
  static const String callChannelDesc = 'Ringtone for incoming calls';
}