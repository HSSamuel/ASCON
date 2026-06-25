import 'dart:async'; 
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:firebase_crashlytics/firebase_crashlytics.dart'; 
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart'; 
import 'package:flutter_callkit_incoming/entities/entities.dart'; 
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http; 

import 'services/notification_service.dart';
import 'services/socket_service.dart'; 
import 'services/auth_service.dart'; 
import 'config/theme.dart';
import 'config.dart';
import 'router.dart'; 
import 'utils/error_handler.dart'; 

final GlobalKey<NavigatorState> navigatorKey = rootNavigatorKey;
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
final ProviderContainer providerContainer = ProviderContainer();

// ✅ NEW: Safe Cold-Start Navigation Guard
bool _isNavigatingToCall = false;

void safeNavigateToCall(Map<String, dynamic> args) {
  if (_isNavigatingToCall) return;
  _isNavigatingToCall = true;

  void pushRoute() {
    final currentRoute = appRouter.routerDelegate.currentConfiguration.uri.toString();
    if (!currentRoute.contains('/call')) {
      appRouter.push('/call', extra: args);
    }
    // Release the lock after routing is complete
    Future.delayed(const Duration(seconds: 2), () {
      _isNavigatingToCall = false;
    });
  }

  // If the app is waking from a dead state, context might not be ready. Wait for next frame.
  if (rootNavigatorKey.currentContext != null) {
    pushRoute();
  } else {
    WidgetsBinding.instance.addPostFrameCallback((_) => pushRoute());
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  final String? replyText = notificationResponse.input;
  final payload = notificationResponse.payload;

  if (notificationResponse.actionId == 'REPLY_ACTION' && replyText != null && payload != null) {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: "env.txt");
    await Hive.initFlutter();
    var box = await Hive.openBox('ascon_cache');
    
    String? token = box.get('auth_token'); 
    final data = jsonDecode(payload);

    final String conversationId = data['conversationId'] ?? '';
    final String receiverId = data['senderId'] ?? '';

    if (token != null && conversationId.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('${AppConfig.baseUrl}/chat/reply'), 
          headers: {
            'Authorization': 'Bearer $token', 
            'Content-Type': 'application/json'
          },
          body: jsonEncode({
            'conversationId': conversationId, 
            'receiverId': receiverId, 
            'message': replyText
          }),
        );
      } catch (e) {
        debugPrint("Background Reply failed: $e");
      }
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;
  
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); 

  final type = message.data['type'];

  if (type == 'call_ended' || type == 'call_rejected') {
    final String? channelName = message.data['channelName'] ?? message.data['id']; 
    if (channelName != null && channelName.isNotEmpty) {
      await FlutterCallkitIncoming.endCall(channelName);
    } else {
      await FlutterCallkitIncoming.endAllCalls();
    }
    return; 
  }

  if (type == 'incoming_call' || type == 'call_offer' || type == 'video_call') {
    CallKitParams callKitParams = CallKitParams(
      id: message.data['channelName'] ?? "call_${DateTime.now().millisecondsSinceEpoch}", 
      nameCaller: message.data['callerName'] ?? 'Alumni User',
      appName: 'ASCON Connect',
      avatar: message.data['callerAvatar'] ?? '',
      handle: 'Incoming Call',
      type: (message.data['isVideoCall'] == "true" || type == 'video_call') ? 1 : 0,
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      duration: 30000, 
      extra: <String, dynamic>{
        'channelName': message.data['channelName'],
        'callerId': message.data['callerId'],
        'callerAvatar': message.data['callerAvatar'] 
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'ringtone', 
        backgroundColor: '#0F3621',
        actionColor: '#4CAF50',
        textAccept: 'Accept', 
        textDecline: 'Decline', 
        // ✅ CRITICAL FIX: Changing this name forces Android to create a NEW notification channel, 
        // overwriting the cached "beep" and forcing the ringtone.mp3 to loop.
        incomingCallNotificationChannelName: 'ASCON Calls V2', 
      ),
      ios: const IOSParams(
        iconName: 'CallKitIcon',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'ringtone.mp3', 
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
  } 
  else if (message.notification == null && message.data.isNotEmpty) {
    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
    
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('ic_notification');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    
    await localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground, 
    );

    String title = message.data['title'] ?? "New Notification";
    String body = message.data['body'] ?? "You have a new update";
    final isChat = type == 'chat_message';

    ByteArrayAndroidBitmap? largeIconBitmap;
    ByteArrayAndroidIcon? personIcon;
    
    if (message.data['profilePicture'] != null && message.data['profilePicture'].toString().isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(message.data['profilePicture']));
        if (response.statusCode == 200) {
          largeIconBitmap = ByteArrayAndroidBitmap(response.bodyBytes);
          personIcon = ByteArrayAndroidIcon(response.bodyBytes);
        }
      } catch (e) {
        debugPrint("Failed to load avatar for notification: $e");
      }
    }

    MessagingStyleInformation? styleInformation;
    if (isChat) {
      final person = Person(
        name: message.data['senderName'] ?? title,
        icon: personIcon, 
      );
      styleInformation = MessagingStyleInformation(
        person,
        messages: [Message(body, DateTime.now(), person)],
      );
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      AppConfig.notificationChannelId,
      AppConfig.notificationChannelName,
      importance: Importance.max,
      priority: Priority.high,
      color: const Color(0xFF1B5E3A),
      icon: 'ic_notification',
      largeIcon: largeIconBitmap, 
      styleInformation: styleInformation, 
      enableVibration: true,
      playSound: true, 
      actions: isChat ? [
        const AndroidNotificationAction(
          'REPLY_ACTION',
          'Reply',
          icon: DrawableResourceAndroidBitmap('ic_notification'), 
          inputs: [
            AndroidNotificationActionInput(
              label: 'Type a message...',
            ),
          ],
        )
      ] : null,
    );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      categoryIdentifier: isChat ? 'CHAT_REPLY' : null,
    );

    await localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(message.data),
    );
  }
}

void main() async {
  ErrorHandler.init();

  var defaultDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      if (message.contains("GSI_LOGGER")) return;
      if (message.contains("access_token")) return;
    }
    defaultDebugPrint(message, wrapWidth: wrapWidth);
  };

  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    await dotenv.load(fileName: "env.txt");
    await Hive.initFlutter();
    await Hive.openBox('ascon_cache');
    
    SocketService().initSocket();

    bool isMobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    bool isDesktop = !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux);

    if (kIsWeb || isMobile || isDesktop) {
      if (kIsWeb) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: AppConfig.firebaseWebApiKey, 
            authDomain: AppConfig.firebaseWebAuthDomain,
            projectId: AppConfig.firebaseWebProjectId,
            storageBucket: AppConfig.firebaseWebStorageBucket,
            messagingSenderId: AppConfig.firebaseWebMessagingSenderId,
            appId: AppConfig.firebaseWebAppId,
            measurementId: AppConfig.firebaseWebMeasurementId,
          ),
        );
      } else {
        await Firebase.initializeApp();
      }
    }

    FlutterError.onError = (errorDetails) {
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      } else {
        debugPrint("Flutter Error (Web): ${errorDetails.exception}");
      }
    };
    
    PlatformDispatcher.instance.onError = (error, stack) {
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } else {
        debugPrint("Platform Error (Web): $error\n$stack");
      }
      return true;
    };

    if (isMobile) {
       FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }

    runApp(UncontrolledProviderScope(
      container: providerContainer, 
      child: const MyApp()
    ));
    
  }, (error, stack) {
    debugPrint("🔴 Uncaught Zone Error: $error\n$stack");
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription? _callSubscription;
  StreamSubscription? _fcmSubscription;
  
  DateTime? _lastSyncTime; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    _setupInteractedMessage(); 
    _listenForFCMForeground(); 
    _listenForIncomingCalls();
    _listenForCallKitEvents(); 
    _checkColdStartCall(); 
    
    _triggerColdStartSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); 
    _callSubscription?.cancel();
    _fcmSubscription?.cancel();
    super.dispose();
  }

  Future<void> _triggerColdStartSync() async {
    if (await AuthService().isSessionValid()) {
      _lastSyncTime = DateTime.now(); 
      AuthService().performGlobalSilentSync();
    }
  }

  Future<void> _checkColdStartCall() async {
    if (kIsWeb) return;
    try {
      var calls = await FlutterCallkitIncoming.activeCalls();
      if (calls is List && calls.isNotEmpty) {
        final dynamic callData = calls[0]; 
        
        Map<String, dynamic> data = {};
        if (callData is Map) {
           data = Map<String, dynamic>.from(callData);
        } else {
           try { data = jsonDecode(jsonEncode(callData)); } catch (_) {}
        }

        if (data.isEmpty) return;

        bool isLoggedIn = await AuthService().isSessionValid();
        if (!isLoggedIn) return;

        Map<String, dynamic> extra = {};
        if (data['extra'] != null) {
          if (data['extra'] is Map) {
             extra = Map<String, dynamic>.from(data['extra']);
          } else if (data['extra'] is String) {
             try { extra = jsonDecode(data['extra']); } catch (_) {}
          }
        }

        String channelName = extra['channelName']?.toString() ?? data['id']?.toString() ?? "";
        String callerId = extra['callerId']?.toString() ?? "";
        String callerAvatar = extra['callerAvatar']?.toString() ?? data['avatar']?.toString() ?? ""; 
        bool isVideo = data['type'] == 1 || data['type'] == "1";
        String remoteName = data['nameCaller']?.toString() ?? "Alumni User";

        // ✅ FIXED: Safely navigate after cold start parsing
        safeNavigateToCall({
          'isGroupCall': false, 
          'isVideoCall': isVideo,
          'remoteName': remoteName,
          'remoteId': callerId,
          'channelName': channelName,
          'remoteAvatar': callerAvatar, 
          'isIncoming': true,
          'autoAccept': true,
        });
      }
    } catch (e) {
      debugPrint("Cold start call check failed: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final currentPath = appRouter.routerDelegate.currentConfiguration.uri.path;
    final isInCall = currentPath.contains('/call');

    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      SocketService().disconnect(); 
      if (!isInCall) {
        debugPrint("App Backgrounded: Socket Disconnected");
      } else {
        debugPrint("App Backgrounded: Socket Disconnected. Relying on FCM and Agora for background signaling.");
      }
    } 
    else if (state == AppLifecycleState.resumed) {
      debugPrint("App Resumed: Reconnecting Socket and Syncing Data");
      
      if (SocketService().socket?.connected != true) {
        SocketService().initSocket(); 
      }
      
      AuthService().isSessionValid().then((isValid) {
        if (isValid) {
          final now = DateTime.now();
          if (_lastSyncTime == null || now.difference(_lastSyncTime!).inMinutes >= 5) {
            _lastSyncTime = now;
            AuthService().performGlobalSilentSync();
          }
        }
      });
    }
  }

  Future<void> _setupInteractedMessage() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationClick(initialMessage);
    }
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);
  }

  void _handleNotificationClick(RemoteMessage message) {
    final data = message.data;
    
    if (data['type'] == 'incoming_call' || data['type'] == 'video_call') {
      safeNavigateToCall({
        'isGroupCall': data['isGroupCall'] == 'true' || data['isGroupCall'] == true,
        'isVideoCall': data['isVideoCall'] == 'true' || data['isVideoCall'] == true,
        'remoteName': data['callerName'] ?? data['groupName'] ?? "Alumni User",
        'remoteId': data['callerId'] ?? "",
        'channelName': data['channelName'] ?? "",
        'remoteAvatar': data['callerAvatar'] ?? data['callerPic'], 
        'isIncoming': true,
      });
    } 
    else if (data['route'] != null) {
      Future.delayed(const Duration(milliseconds: 400), () {
        appRouter.push('/${data['route']}', extra: data);
      });
    }
  }

  void _listenForFCMForeground() {
    if (kIsWeb) return;
    _fcmSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final data = message.data;
      final type = data['type'];
      
      if (type == 'call_ended' || type == 'call_rejected') {
        final String? channelName = data['channelName'];
        if (channelName != null && channelName.isNotEmpty) {
          await FlutterCallkitIncoming.endCall(channelName);
        } else {
          await FlutterCallkitIncoming.endAllCalls();
        }
        
        final currentRoute = appRouter.routerDelegate.currentConfiguration.uri.toString();
        if (currentRoute.contains('/call')) {
          if (appRouter.canPop()) {
            appRouter.pop();
          } else {
            appRouter.go('/');
          }
        }
      }
    });
  }

  void _listenForCallKitEvents() {
    if (kIsWeb) return;
    
    FlutterCallkitIncoming.onEvent.listen((dynamic event) {
      if (event == null) return;

      try {
        // ✅ CRITICAL FIX: Check the type before accessing properties
        // We look for the specific accepted/declined events and ignore others (like timeouts)
        String eventName = "";
        
        // Handle standard CallEvent objects
        if (event.runtimeType.toString() == 'CallEvent') {
           eventName = event.event.toString();
        } else {
           // If it's a specific action class, we map it to the event name
           if (event.runtimeType.toString() == 'CallEventActionCallAccept') {
             eventName = 'actionCallAccept';
           } else if (event.runtimeType.toString() == 'CallEventActionCallDecline') {
             eventName = 'actionCallDecline';
           }
        }

        if (eventName.contains('actionCallAccept') || eventName.contains('actionCallCallback')) {
          final data = event.body;
          if (data == null) return;

          Map<String, dynamic> extra = {};
          if (data['extra'] != null) {
            if (data['extra'] is Map) {
              extra = Map<String, dynamic>.from(data['extra']);
            } else if (data['extra'] is String) {
              try { extra = jsonDecode(data['extra']); } catch (_) {}
            }
          }

          String channelName = extra['channelName']?.toString() ?? data['id']?.toString() ?? "";
          String callerId = extra['callerId']?.toString() ?? "";
          String callerAvatar = extra['callerAvatar']?.toString() ?? data['avatar']?.toString() ?? ""; 
          bool isVideo = data['type'] == 1 || data['type'] == "1";
          String remoteName = data['nameCaller']?.toString() ?? "Alumni User";

          Future.delayed(const Duration(milliseconds: 1000), () async {
            bool isLoggedIn = await AuthService().isSessionValid();
            if (!isLoggedIn) return;

            final currentRoute = appRouter.routerDelegate.currentConfiguration.uri.toString();
            if (currentRoute.contains('/call')) return;

            appRouter.push('/call', extra: {
              'isGroupCall': false, 
              'isVideoCall': isVideo,
              'remoteName': remoteName,
              'remoteId': callerId,
              'channelName': channelName,
              'remoteAvatar': callerAvatar, 
              'isIncoming': true,
              'autoAccept': true, 
            });
          });
        } 
        else if (eventName.contains('actionCallDecline')) {
          SocketService().socket?.emit('reject_call', {'reason': 'user_busy'});
          FlutterCallkitIncoming.endAllCalls(); 
        }
      } catch (err) {
        debugPrint("CallKit Listener Error: $err");
      }
    });
  }

  void _listenForIncomingCalls() {
    _callSubscription = SocketService().callEvents.listen((event) {
      if (event['type'] == 'incoming') {
        final data = event['data'];
        
        bool isGroup = data['callerData']?['isGroupCall'] ?? false;
        String displayRemoteName = isGroup 
            ? (data['callerData']?['groupName'] ?? "Group Call") 
            : (data['callerData']?['callerName'] ?? "Alumni User");

        final currentPath = appRouter.routerDelegate.currentConfiguration.uri.path;
        
        final isAuthScreen = currentPath == '/' || currentPath == '/login';
        final isAlreadyInCall = currentPath == '/call';

        if (!isAuthScreen && !isAlreadyInCall) {
          safeNavigateToCall({
            'isGroupCall': isGroup, 
            'isVideoCall': data['callerData']?['isVideoCall'] ?? false, 
            'remoteName': displayRemoteName,
            'remoteId': data['callerId'] ?? "", 
            'channelName': data['channelName'] ?? "",
            'remoteAvatar': data['callerData']?['callerAvatar'], 
            'isIncoming': true, 
          });
        } else if (isAlreadyInCall) {
          SocketService().socket?.emit('reject_call', {
            'targetUserId': data['callerId'],
            'reason': 'user_busy'
          });
          debugPrint('Rejected background call from ${data['callerId']} because user is busy.');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp.router(
          routerConfig: appRouter, 
          title: 'ASCON Alumni',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          builder: (context, child) {
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}