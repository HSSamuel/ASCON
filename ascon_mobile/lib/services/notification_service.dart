import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../config.dart';
import '../router.dart'; 
import '../services/socket_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    if (!kIsWeb) {
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('ic_notification');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
      const InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null) {
            try {
              final data = jsonDecode(response.payload!);
              handleNavigation(data);
            } catch (e) {
              debugPrint("Error parsing payload: $e");
            }
          }
        },
      );

      const AndroidNotificationChannel callChannel = AndroidNotificationChannel(
        AppConfig.callChannelId,
        AppConfig.callChannelName,
        description: AppConfig.callChannelDesc,
        importance: Importance.max, 
        enableVibration: true,
        playSound: true,
      );

      const AndroidNotificationChannel standardChannel = AndroidNotificationChannel(
        AppConfig.notificationChannelId,
        AppConfig.notificationChannelName,
        description: AppConfig.notificationChannelDesc,
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      );

      final plugin = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (plugin != null) {
        await plugin.createNotificationChannel(callChannel);
        await plugin.createNotificationChannel(standardChannel);
      }
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint("🔔 Foreground Message: ${message.data}");

      if (message.data['type'] == 'call_offer' || message.data['type'] == 'video_call') {
        return; 
      }

      if (message.notification != null || message.data.isNotEmpty) {
        if (!kIsWeb) {
          _showLocalNotification(message);
        }
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      handleNavigation(message.data);
    });

    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      // ✅ Reduced delay since we no longer rely on BuildContext to be ready
      Future.delayed(const Duration(milliseconds: 300), () {
        handleNavigation(initialMessage.data);
      });
    }

    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      syncToken(tokenOverride: newToken, retry: true);
    });

    syncToken(retry: true);
  }

  Future<void> handleNavigation(Map<String, dynamic> data) async {
    final String? route = data['route'];
    final String? type = data['type'];
    final String? id = data['id'] ?? data['eventId'] ?? data['_id'];

    String? token = await _storage.read(key: 'auth_token');
    if (token == null) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('auth_token');
    }

    if (token == null) {
      // ✅ Use global appRouter instead of context
      appRouter.go('/login', extra: data); 
      return;
    }

    // ✅ CALL ROUTING
    if (type == 'call_offer' || type == 'video_call') {
      SocketService().initSocket(); 
      bool isVideo = data['isVideoCall'].toString().toLowerCase() == 'true' || type == 'video_call';
      bool isGroup = data['isGroupCall'].toString().toLowerCase() == 'true';

      appRouter.push('/call', extra: {
        'remoteName': data['callerName'] ?? "Unknown Caller",
        'remoteId': data['callerId'],
        'remoteAvatar': data['callerPic'],
        'isIncoming': true, 
        'isVideoCall': isVideo,
        'isGroupCall': isGroup,
        'channelName': data['channelName'] ?? "call_${DateTime.now().millisecondsSinceEpoch}",
      });
      return;
    }

    // ✅ CHAT ROUTING
    if (type == 'chat_message') {
      final conversationId = data['conversationId'];
      final senderId = data['senderId'];
      final isGroup = data['isGroup'].toString().toLowerCase() == 'true';
      final groupId = data['groupId'];
      
      String displayName = isGroup 
          ? (data['groupName'] ?? "Group Chat") 
          : (data['senderName'] ?? "Alumni Member");
          
      final senderProfilePic = data['senderProfilePic'];

      if (conversationId != null) {
        SocketService().initSocket();
        
        appRouter.push('/chat_detail', extra: {
          'conversationId': conversationId,
          'receiverId': senderId,
          'receiverName': displayName,
          'receiverProfilePic': senderProfilePic,
          'isGroup': isGroup,
          'groupId': groupId,
          'isOnline': false, 
        });
      }
      return;
    }

    // ✅ NEW ALUMNI ROUTING
    if (route == 'alumni_detail' || type == 'new_alumni') {
      appRouter.push('/alumni_detail', extra: {
        'alumniData': {
          '_id': id.toString(),
          'fullName': data['fullName'] ?? 'New Alumni',
        }
      });
      return;
    }

    // ✅ TAB ROUTING (Uses go to swap bottom nav shell)
    if (type == 'new_update' || route == 'updates') {
      appRouter.go('/updates'); 
      return;
    }

    if (type == 'welcome' || route == 'profile') {
      appRouter.go('/profile'); 
      return;
    }

    // ✅ DETAIL SCREEN ROUTING (Uses push to enable back button)
    if (route == 'mentorship_requests' || type == 'mentorship_request') {
      appRouter.push('/mentorship_requests');
      return;
    }
    
    if (route == 'polls' || type == 'poll') {
      appRouter.push('/polls');
      return;
    }

    if (id != null) {
      if (route == 'event_detail' || type == 'event') {
        appRouter.push('/event_detail', extra: {'eventData': {'_id': id.toString(), 'title': 'Loading...'}});
      } else if (route == 'programme_detail' || type == 'programme') {
        appRouter.push('/programme_detail', extra: {'programme': {'_id': id.toString(), 'title': 'Loading...'}});
      } else if (route == 'facility_detail' || type == 'facility') {
        appRouter.push('/facility_detail', extra: {'facility': {'_id': id.toString(), 'title': 'Loading...'}});
      }
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    String originalTitle = message.notification?.title ?? 'New Message';
    String body = message.notification?.body ?? '';
    
    bool isCall = message.data['type'] == 'call_offer' || message.data['type'] == 'video_call';
    String channelId = isCall ? AppConfig.callChannelId : AppConfig.notificationChannelId;
    String channelName = isCall ? AppConfig.callChannelName : AppConfig.notificationChannelName;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.max,
      priority: Priority.high, 
      color: const Color(0xFF1B5E3A),
      icon: 'ic_notification',
      enableVibration: true,
      playSound: true, 
    );

    await _localNotifications.show(
      message.hashCode,
      originalTitle,
      body,
      NotificationDetails(android: androidDetails),
      payload: jsonEncode(message.data),
    );
  }

  Future<AuthorizationStatus> getAuthorizationStatus() async {
    return (await _firebaseMessaging.getNotificationSettings()).authorizationStatus;
  }

  Future<void> requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      syncToken(retry: false);
    }
  }

  Future<void> syncToken({String? tokenOverride, bool retry = false}) async {
    try {
      String? fcmToken = tokenOverride ?? (kIsWeb 
          ? await _firebaseMessaging.getToken(vapidKey: dotenv.env['FIREBASE_VAPID_KEY']) 
          : await _firebaseMessaging.getToken());

      if (fcmToken == null) return;

      String? authToken = await _storage.read(key: 'auth_token');
      if (authToken == null) {
        final prefs = await SharedPreferences.getInstance();
        authToken = prefs.getString('auth_token');
      }

      if (authToken != null) {
        await http.post(
          Uri.parse('${AppConfig.baseUrl}/api/notifications/save-token'),
          headers: {'Content-Type': 'application/json', 'auth-token': authToken},
          body: jsonEncode({"fcmToken": fcmToken}),
        ).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      debugPrint("Sync Error: $e");
    }
  }
}