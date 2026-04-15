import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart'; 

import '../config.dart';
import '../router.dart'; 

import '../screens/event_detail_screen.dart';
import '../screens/programme_detail_screen.dart';
import '../screens/facility_detail_screen.dart';
import '../screens/mentorship_dashboard_screen.dart';
import '../services/socket_service.dart';

// ✅ Background Handler (Handles Terminated & Data-Only Notifications)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("🌙 Background Message: ${message.messageId}");
  
  // If the payload has no 'notification' block, it's a data-only message.
  // We must manually show the notification so the phone rings/vibrates when killed.
  if (message.notification == null && message.data.isNotEmpty) {
    
    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
    
    // Initialize standard settings for background execution
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('ic_notification');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    await localNotifications.initialize(initSettings);

    // Determine if it's a call or regular message
    bool isCall = message.data['type'] == 'call_offer';
    String channelId = isCall ? AppConfig.callChannelId : AppConfig.notificationChannelId;
    String channelName = isCall ? AppConfig.callChannelName : AppConfig.notificationChannelName;
    String title = isCall ? "Incoming Call" : "New Message";
    String callerName = message.data['callerName'] ?? 'Someone';
    String body = isCall ? "$callerName is calling you" : "You have a new message";

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

    await localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: jsonEncode(message.data),
    );
  }
}

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
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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

      // Create a dedicated channel for Calls (High Importance)
      const AndroidNotificationChannel callChannel = AndroidNotificationChannel(
        AppConfig.callChannelId,
        AppConfig.callChannelName,
        description: AppConfig.callChannelDesc,
        importance: Importance.max, // ✅ Controls priority on Android 8+
        enableVibration: true,
        playSound: true,
      );

      // Standard Channel
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

    // ✅ FOREGROUND LISTENER
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint("🔔 Foreground Message: ${message.data}");

      // If app is open, we ignore call notifications because SocketService 
      // will handle the immediate navigation to CallScreen.
      if (message.data['type'] == 'call_offer') {
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
      Future.delayed(const Duration(milliseconds: 800), () {
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

    final BuildContext? context = rootNavigatorKey.currentContext;

    if (token == null) {
      if (context != null) GoRouter.of(context).go('/login', extra: data); 
      return;
    }

    if (context == null) return;

    // ✅ CALL HANDLING: Open CallScreen from Notification Tap
    if (type == 'call_offer' || type == 'video_call') {
      SocketService().initSocket(); 

      context.push('/call', extra: {
        'remoteName': data['callerName'] ?? "Unknown Caller",
        'remoteId': data['callerId'],
        'remoteAvatar': data['callerPic'],
        'isCaller': false, // Receiver
        'offer': data['offer'] is String ? jsonDecode(data['offer']) : data['offer'],
        'callLogId': data['callLogId'],
      });
      return;
    }

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
        
        context.push('/chat_detail', extra: {
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

    if (type == 'new_update' || route == 'updates') {
      context.go('/updates'); 
      return;
    }

    if (type == 'welcome' || route == 'profile') {
      context.go('/profile'); 
      return;
    }

    if (route == 'mentorship_requests') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MentorshipDashboardScreen()),
      );
      return;
    }

    if (id != null) {
      if (route == 'event_detail') {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailScreen(eventData: {'_id': id.toString(), 'title': 'Loading...'})));
      } else if (route == 'programme_detail') {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProgrammeDetailScreen(programme: {'_id': id.toString(), 'title': 'Loading...'})));
      } else if (route == 'facility_detail') {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => FacilityDetailScreen(facility: {'_id': id.toString(), 'title': 'Loading...'})));
      }
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    String originalTitle = message.notification?.title ?? 'New Message';
    String body = message.notification?.body ?? '';
    
    // Check if it's a call to use the high-priority channel
    bool isCall = message.data['type'] == 'call_offer';
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