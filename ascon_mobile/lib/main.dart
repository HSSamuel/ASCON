import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // ✅ ADDED
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart'; // ✅ ADDED
import 'package:flutter_callkit_incoming/entities/entities.dart'; // ✅ ADDED
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

// ✅ ADDED: High-Priority Background Handler to Wake Phone
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(); // Initialize isolated Firebase instance

  if (kIsWeb) return;

  if (message.data['type'] == 'incoming_call') {
    CallKitParams callKitParams = CallKitParams(
      id: message.data['channelName'],
      nameCaller: message.data['callerName'] ?? 'Alumni User',
      appName: 'ASCON Connect',
      avatar: 'https://i.pravatar.cc/100', // Optional default avatar
      handle: 'Incoming Call',
      type: message.data['isVideoCall'] == "true" ? 1 : 0,
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
        'callerId': message.data['callerId']
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
       await NotificationService().init();
       // ✅ ADDED: Register the background handler for calls
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
    _listenForCallKitEvents(); // ✅ ADDED
  }

  // ✅ ADDED: Navigate to the actual call screen if user swipes "Accept" on the lock screen
  void _listenForCallKitEvents() {
    if (kIsWeb) return;
    FlutterCallkitIncoming.onEvent.listen((event) {
      switch (event!.event) {
        case Event.actionCallAccept:
          final data = event.body;
          String channelName = data['extra']?['channelName'] ?? data['id'] ?? "";
          String callerId = data['extra']?['callerId'] ?? "";
          
          appRouter.push('/call', extra: {
            'isGroupCall': false, 
            'isVideoCall': data['type'] == 1,
            'remoteName': data['nameCaller'] ?? "Alumni User",
            'remoteId': callerId,
            'channelName': channelName,
            'isIncoming': true,
          });
          break;
          
        case Event.actionCallDecline:
          // Emit a reject signal to the server if they decline from the lock screen
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