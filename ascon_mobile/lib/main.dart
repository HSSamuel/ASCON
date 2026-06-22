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

import 'services/notification_service.dart';
import 'services/socket_service.dart'; 
import 'services/auth_service.dart'; 
import 'config/theme.dart';
import 'config.dart';
import 'router.dart'; 
import 'utils/error_handler.dart'; 

final GlobalKey<NavigatorState> navigatorKey = rootNavigatorKey;
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

// Global Provider Container allows us to access Riverpod outside the Widget tree
final ProviderContainer providerContainer = ProviderContainer();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(); 

  if (kIsWeb) return;

  final type = message.data['type'];
  if (type == 'incoming_call' || type == 'call_offer' || type == 'video_call') {
    
    CallKitParams callKitParams = CallKitParams(
      id: message.data['channelName'] ?? "call_${DateTime.now().millisecondsSinceEpoch}", 
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
      duration: 30000, 
      extra: <String, dynamic>{
        'channelName': message.data['channelName'],
        'callerId': message.data['callerId'],
        'callerAvatar': message.data['callerAvatar'] 
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

    await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
  } 
  else if (message.notification == null && message.data.isNotEmpty) {
    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
    
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('ic_notification');
    await localNotifications.initialize(const InitializationSettings(android: androidSettings));

    String title = "New Notification";
    String body = "You have a new update";
    
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

  // ✅ 1. Wrap the entire app in a Zoned Guard to catch asynchronous Dart errors
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

    // ✅ 2. Catch UI Rendering & Framework Errors
    FlutterError.onError = (errorDetails) {
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      } else {
        debugPrint("Flutter Error (Web): ${errorDetails.exception}");
      }
    };
    
    // ✅ 3. Catch platform/engine errors (Flutter 3.3+)
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
    // ✅ 4. The final safety net for uncaught zone errors
    debugPrint("🔴 Uncaught Zone Error: $error\n$stack");
    // ✅ FIX: Added kIsWeb check so this doesn't crash Flutter Web!
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    _setupInteractedMessage(); // ✅ Ensure notifications clicked from terminated state are handled
    _listenForIncomingCalls();
    _listenForCallKitEvents(); 
    
    _triggerColdStartSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); 
    _callSubscription?.cancel();
    super.dispose();
  }

  Future<void> _triggerColdStartSync() async {
    if (await AuthService().isSessionValid()) {
      AuthService().performGlobalSilentSync();
    }
  }

  // =======================================================================
  // 🚀 GLOBAL LIFECYCLE SYNCING
  // =======================================================================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      SocketService().disconnect(); 
      debugPrint("App Backgrounded: Socket Disconnected");
    } 
    else if (state == AppLifecycleState.resumed) {
      debugPrint("App Resumed: Reconnecting Socket and Syncing Data");
      SocketService().initSocket(); 
      
      AuthService().isSessionValid().then((isValid) {
        if (isValid) {
          AuthService().performGlobalSilentSync();
        } else {
          debugPrint("User is logged out. Skipping background sync.");
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
      final currentRoute = appRouter.routerDelegate.currentConfiguration.uri.toString();
      if (currentRoute.contains('/call')) return;

      appRouter.push('/call', extra: {
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
      appRouter.push('/${data['route']}', extra: data);
    }
  }

  void _listenForCallKitEvents() {
    if (kIsWeb) return;
    FlutterCallkitIncoming.onEvent.listen((event) {
      switch (event!.event) {
        case Event.actionCallAccept:
          final data = event.body;
          String channelName = data['extra']?['channelName'] ?? data['id'] ?? "";
          String callerId = data['extra']?['callerId'] ?? "";
          String callerAvatar = data['extra']?['callerAvatar'] ?? data['avatar'] ?? ""; 

          final currentRoute = appRouter.routerDelegate.currentConfiguration.uri.toString();
          if (currentRoute.contains('/call')) return;

          appRouter.push('/call', extra: {
            'isGroupCall': false, 
            'isVideoCall': data['type'] == 1,
            'remoteName': data['nameCaller'] ?? "Alumni User",
            'remoteId': callerId,
            'channelName': channelName,
            'remoteAvatar': callerAvatar, 
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