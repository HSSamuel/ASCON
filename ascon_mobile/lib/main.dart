import 'dart:async'; 
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart'; 
import 'package:flutter_callkit_incoming/entities/entities.dart'; 
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:hive_flutter/hive_flutter.dart';

import 'services/notification_service.dart';
import 'services/socket_service.dart'; 
import 'config/theme.dart';
import 'config.dart';
import 'router.dart'; 
import 'utils/error_handler.dart'; 
import 'screens/call_screen.dart'; 

final GlobalKey<NavigatorState> navigatorKey = rootNavigatorKey;
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

final ProviderContainer providerContainer = ProviderContainer();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(); // Initialize isolated Firebase instance

  if (kIsWeb) return;

  final type = message.data['type'];
  if (type == 'incoming_call' || type == 'call_offer' || type == 'video_call') {
    
    CallKitParams callKitParams = CallKitParams(
      id: message.data['channelName'] ?? "call_${DateTime.now().millisecondsSinceEpoch}", // Fallback ID
      nameCaller: message.data['callerName'] ?? 'Alumni User',
      appName: 'ASCON Connect',
      avatar: message.data['callerAvatar'] ?? '',
      handle: 'Incoming Call',
      type: (message.data['isVideoCall'] == "true" || type == 'video_call') ? 1 : 0,
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      duration: 30000, // Ring for 30 seconds
      extra: <String, dynamic>{
        'channelName': message.data['channelName'],
        'callerId': message.data['callerId'],
        'callerAvatar': message.data['callerAvatar'] // ✅ FIX 1: Pass the avatar into the extra map so it survives the CallKit transition
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0F3621',
        actionColor: '#4CAF50',
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
        ringtonePath: 'system_ringtone_default',
      ),
    );

    // This forces the lock screen to show the Accept/Decline UI
    await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
  } 
  // 2. ROUTE AS STANDARD NOTIFICATION (Chat, Updates, etc.)
  else if (message.notification == null && message.data.isNotEmpty) {
    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
    
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('ic_notification');
    await localNotifications.initialize(const InitializationSettings(android: androidSettings));

    String title = "New Notification";
    String body = "You have a new update";
    
    // Attempt to extract title/body from data payload if no notification payload exists
    if (message.data.containsKey('title')) title = message.data['title'];
    if (message.data.containsKey('body')) body = message.data['body'];

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      AppConfig.notificationChannelId,
      AppConfig.notificationChannelName,
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

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
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

    if (isMobile) {
       FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }

    runApp(UncontrolledProviderScope(
      container: providerContainer, 
      child: const MyApp()
    ));
    
  }, (error, stack) {
    debugPrint("🔴 Uncaught Zone Error: $error\n$stack");
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription? _callSubscription;

  @override
  void initState() {
    super.initState();
    _listenForIncomingCalls();
    _listenForCallKitEvents(); 
    _setupInteractedMessage(); 
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
    
    // Fallback Routing for Calls (Web/Standard Push)
    if (data['type'] == 'incoming_call' || data['type'] == 'video_call') {
      // ✅ FIX 2: Added identical navigation guard to prevent double-pushing
      final currentRoute = appRouter.routerDelegate.currentConfiguration.uri.toString();
      if (currentRoute.contains('/call')) return;

      appRouter.push('/call', extra: {
        'isGroupCall': data['isGroupCall'] == 'true' || data['isGroupCall'] == true,
        'isVideoCall': data['isVideoCall'] == 'true' || data['isVideoCall'] == true,
        'remoteName': data['callerName'] ?? data['groupName'] ?? "Alumni User",
        'remoteId': data['callerId'] ?? "",
        'channelName': data['channelName'] ?? "",
        'remoteAvatar': data['callerAvatar'] ?? data['callerPic'], // ✅ Added caller avatar map
        'isIncoming': true,
      });
    } 
    // Fallback Routing for Generic Updates/Chat
    else if (data['route'] != null) {
      appRouter.push('/${data['route']}', extra: data);
    }
  }

  // Navigate to the actual call screen if user swipes "Accept" on the lock screen
  void _listenForCallKitEvents() {
    if (kIsWeb) return;
    FlutterCallkitIncoming.onEvent.listen((event) {
      switch (event!.event) {
        case Event.actionCallAccept:
          final data = event.body;
          String channelName = data['extra']?['channelName'] ?? data['id'] ?? "";
          String callerId = data['extra']?['callerId'] ?? "";
          
          // ✅ FIX 3: Plucked the avatar string from the custom 'extra' dictionary or 'avatar' root
          String callerAvatar = data['extra']?['callerAvatar'] ?? data['avatar'] ?? ""; 

          final currentRoute = appRouter.routerDelegate.currentConfiguration.uri.toString();
          if (currentRoute.contains('/call')) return;

          appRouter.push('/call', extra: {
            'isGroupCall': false, 
            'isVideoCall': data['type'] == 1,
            'remoteName': data['nameCaller'] ?? "Alumni User",
            'remoteId': callerId,
            'channelName': channelName,
            'remoteAvatar': callerAvatar, // ✅ Passed securely into the route
            'isIncoming': true,
          });
          break;
          
        case Event.actionCallDecline:
          SocketService().socket?.emit('reject_call', {'reason': 'user_busy'});
          break;
          
        default:
          break;
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
          appRouter.push('/call', extra: {
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
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
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