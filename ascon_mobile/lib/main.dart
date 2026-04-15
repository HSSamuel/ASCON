import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 

import 'services/notification_service.dart';
import 'services/socket_service.dart'; 
import 'config/theme.dart';
import 'config.dart';
import 'router.dart'; 
import 'utils/error_handler.dart'; 
import 'screens/call_screen.dart'; 

final GlobalKey<NavigatorState> navigatorKey = rootNavigatorKey;
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

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
    if (details.exception.toString().contains("statusCode: 429")) return;
    FlutterError.presentError(details);
  };

  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    await dotenv.load(fileName: "env.txt");
    
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
    }

    runApp(const ProviderScope(child: MyApp()));
  }, (error, stack) {
    String errorText = error.toString();
    if (errorText.contains("Future already completed")) return;
    if (errorText.contains("statusCode: 429")) return;
    debugPrint("🔴 Uncaught Zone Error: $error");
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
  }

  void _listenForIncomingCalls() {
    _callSubscription = SocketService().callEvents.listen((event) {
      if (event['type'] == 'incoming') {
        final data = event['data'];
        
        // ✅ MAP GROUP CALL UI
        bool isGroup = data['callerData']?['isGroupCall'] ?? false;
        String displayRemoteName = isGroup 
            ? (data['callerData']?['groupName'] ?? "Group Call") 
            : (data['callerData']?['callerName'] ?? "Alumni User");

        if (navigatorKey.currentContext != null) {
          Navigator.of(navigatorKey.currentContext!, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (context) => CallScreen(
                isGroupCall: isGroup, 
                isVideoCall: data['callerData']?['isVideoCall'] ?? false, // ✅ READ VIDEO FLAG
                remoteName: displayRemoteName,
                remoteId: data['callerId'] ?? "", 
                channelName: data['channelName'] ?? "",
                remoteAvatar: data['callerData']?['callerAvatar'], 
                isIncoming: true, 
              ),
            ),
          );
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