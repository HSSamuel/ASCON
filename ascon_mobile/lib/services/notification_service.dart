import 'dart:convert'; 
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; 
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ✅ NEW: Required for background isolation
import 'dart:typed_data'; 

import '../config.dart';
import '../router.dart'; 
import '../services/socket_service.dart';

// ============================================================================
// ✅ BACKGROUND HANDLER FOR INLINE REPLIES AND ACTIONS
// ============================================================================
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  if (response.payload == null) return;
  
  try {
    // ✅ CRITICAL FIX: The background isolate must load the env file independently
    await dotenv.load(fileName: "env.txt");
    
    final data = jsonDecode(response.payload!);
    
    // Handle Inline Reply
    if (response.actionId == 'REPLY_ACTION' && response.input != null) {
      final String replyText = response.input!;
      final String? conversationId = data['conversationId'];
      final String? receiverId = data['senderId'];

      if (conversationId != null && replyText.isNotEmpty) {
        const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
        String? token = await storage.read(key: 'auth_token');
        
        if (token == null) {
          final prefs = await SharedPreferences.getInstance();
          token = prefs.getString('auth_token');
        }

        if (token != null) {
          // Fire the reply directly to the backend
          await http.post(
            Uri.parse('${AppConfig.baseUrl}/api/chat/reply'),
            headers: {
              'Content-Type': 'application/json',
              'auth-token': token,
            },
            body: jsonEncode({
              'conversationId': conversationId,
              'receiverId': receiverId,
              'message': replyText,
            }),
          );
          
          // ✅ CRITICAL FIX: Tell the OS to clear the notification, stopping the spinner
          if (response.id != null) {
             await FlutterLocalNotificationsPlugin().cancel(response.id!);
          }
        }
      }
    } 
    // Handle Mark as Read
    else if (response.actionId == 'MARK_READ_ACTION') {
      final String? conversationId = data['conversationId'];
      if (conversationId != null) {
        const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
        String? token = await storage.read(key: 'auth_token');
        if (token != null) {
          await http.put(
            Uri.parse('${AppConfig.baseUrl}/api/chat/read/$conversationId'),
            headers: {'auth-token': token},
          );
          
          // ✅ Clear notification
          if (response.id != null) {
             await FlutterLocalNotificationsPlugin().cancel(response.id!);
          }
        }
      }
    }
  } catch (e) {
    debugPrint("Background Action Error: $e");
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
          if (response.payload != null && response.actionId == null) {
            try {
              final data = jsonDecode(response.payload!);
              handleNavigation(data);
            } catch (e) {
              debugPrint("Error parsing payload: $e");
            }
          }
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
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
      if (message.data['type'] == 'call_offer' || 
          message.data['type'] == 'video_call' || 
          message.data['type'] == 'incoming_call') {
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
      handleNavigation(initialMessage.data);
    }

    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      syncToken(tokenOverride: newToken, retry: true);
    });

    syncToken(retry: true);
  }

  Future<void> handleNavigation(Map<String, dynamic> data) async {
    int waitCount = 0;
    while (appRouter.routerDelegate.currentConfiguration.uri.path == '/' && waitCount < 50) {
      await Future.delayed(const Duration(milliseconds: 100)); 
      waitCount++;
    }
    final String? route = data['route'];
    final String? type = data['type'];
    final String? id = data['id'] ?? data['eventId'] ?? data['_id'];

    String? token = await _storage.read(key: 'auth_token');
    if (token == null) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('auth_token');
    }

    if (token == null) {
      appRouter.go('/login', extra: data); 
      return;
    }

    if (type == 'call_offer' || type == 'video_call' || type == 'incoming_call') {
      SocketService().initSocket(); 
      bool isVideo = data['isVideoCall'].toString().toLowerCase() == 'true' || type == 'video_call';
      bool isGroup = data['isGroupCall'].toString().toLowerCase() == 'true';

      final String currentRoute = appRouter.routerDelegate.currentConfiguration.uri.toString();
      if (currentRoute.contains('/call')) return;

      appRouter.push('/call', extra: {
        'remoteName': data['callerName'] ?? "Unknown Caller",
        'remoteId': data['callerId'],
        'remoteAvatar': data['callerAvatar'] ?? data['callerPic'], 
        'isIncoming': true, 
        'isVideoCall': isVideo,
        'isGroupCall': isGroup,
        'channelName': data['channelName'] ?? "call_${DateTime.now().millisecondsSinceEpoch}",
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

    if (route == 'alumni_detail' || type == 'new_alumni' || type == 'new_match') {
      appRouter.push('/alumni_detail', extra: {
        'alumniData': {
          '_id': data['profileId'] ?? id?.toString() ?? '', 
          'userId': data['userId'] ?? id?.toString() ?? '', 
          'fullName': data['fullName'] ?? 'New Alumni',
          'profilePicture': '', 
          'isOnline': false,
        }
      });
      return;
    }

    if (type == 'new_update' || route == 'updates') {
      appRouter.go('/updates'); 
      return;
    }

    if (type == 'welcome' || route == 'profile') {
      appRouter.go('/profile'); 
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
      } 
    }
  }

  Future<Uint8List?> _downloadImageBytes(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('Failed to download notification image: $e');
    }
    return null;
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    String originalTitle = message.notification?.title ?? 'New Message';
    String body = message.notification?.body ?? '';
    
    bool isCall = message.data['type'] == 'call_offer' || message.data['type'] == 'video_call' || message.data['type'] == 'incoming_call';
    String channelId = isCall ? AppConfig.callChannelId : AppConfig.notificationChannelId;
    String channelName = isCall ? AppConfig.callChannelName : AppConfig.notificationChannelName;

    String? imageUrl = message.data['image'] ?? message.data['profilePicture'] ?? message.notification?.android?.imageUrl;
    
    ByteArrayAndroidBitmap? largeIcon;
    StyleInformation? styleInfo;

    if (imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
      final imageBytes = await _downloadImageBytes(imageUrl);
      if (imageBytes != null) {
        largeIcon = ByteArrayAndroidBitmap(imageBytes);

        if (message.data['type'] == 'chat_message') {
          final person = Person(
            name: originalTitle,
            icon: ByteArrayAndroidIcon(imageBytes),
          );
          styleInfo = MessagingStyleInformation(
            person,
            messages: [Message(body, DateTime.now(), person)],
          );
        } else if (message.data['type'] == 'event' || message.data['type'] == 'programme') {
          styleInfo = BigPictureStyleInformation(
            ByteArrayAndroidBitmap(imageBytes),
            largeIcon: ByteArrayAndroidBitmap(imageBytes),
            contentTitle: originalTitle,
            summaryText: body,
            htmlFormatContentTitle: true,
            htmlFormatSummaryText: true,
          );
        }
      }
    }

    if (styleInfo == null && message.data['type'] == 'chat_message') {
       final person = Person(name: originalTitle);
       styleInfo = MessagingStyleInformation(
         person, 
         messages: [Message(body, DateTime.now(), person)]
       );
    }

    List<AndroidNotificationAction> actions = [];
    if (message.data['type'] == 'chat_message') {
      actions = [
        const AndroidNotificationAction(
          'REPLY_ACTION',
          'Reply',
          allowGeneratedReplies: true,
          showsUserInterface: false, 
          inputs: [
            AndroidNotificationActionInput(
              label: 'Type a message...',
            ),
          ],
        ),
        const AndroidNotificationAction(
          'MARK_READ_ACTION',
          'Mark as Read',
          showsUserInterface: false,
        ),
      ];
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.max,
      priority: Priority.high, 
      color: const Color(0xFF1B5E3A),
      icon: 'ic_notification',
      largeIcon: largeIcon, 
      styleInformation: styleInfo, 
      actions: actions,
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