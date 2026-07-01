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
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 

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

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(); 
  await dotenv.load(fileName: "env.txt"); 

  if (kIsWeb) return;

  final type = message.data['type'];

  // SILENT BACKGROUND DELIVERY RECEIPT 
  if (type == 'chat_message') {
    final String? messageId = message.data['messageId'];
    if (messageId != null) {
      const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
      String? token = await storage.read(key: 'auth_token');
      
      if (token == null) {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('auth_token');
      }

      if (token != null) {
        try {
          await http.put(
            Uri.parse('${AppConfig.baseUrl}/api/chat/message/$messageId/delivered'),
            headers: {'auth-token': token},
          );
        } catch (e) {
          debugPrint("Delivery receipt failed: $e");
        }
      }
    }
  }

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
    await localNotifications.initialize(
      const InitializationSettings(android: androidSettings),
      // ✅ CRITICAL: This tells Android what function to run when "Reply" is tapped in the background
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground, 
    );

    String title = message.data['title'] ?? "New Notification";
    String body = message.data['body'] ?? "You have a new update";
    String? imageUrl = message.data['image'] ?? message.data['profilePicture'];

    ByteArrayAndroidBitmap? largeIcon;
    StyleInformation? styleInfo;

    // ✅ 1. Download Avatar Image
    if (imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
      try {
        final response = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          largeIcon = ByteArrayAndroidBitmap(response.bodyBytes);
          
          if (message.data['type'] == 'chat_message') {
            final person = Person(name: title, icon: ByteArrayAndroidIcon(response.bodyBytes));
            styleInfo = MessagingStyleInformation(person, messages: [Message(body, DateTime.now(), person)]);
          } else {
            styleInfo = BigPictureStyleInformation(largeIcon, largeIcon: largeIcon, contentTitle: title, summaryText: body, htmlFormatContentTitle: true, htmlFormatSummaryText: true);
          }
        }
      } catch (e) {
        debugPrint("Bg Image download failed: $e");
      }
    }

    // ✅ 2. Fallback for Chat Messages if user has no Profile Picture
    if (styleInfo == null && message.data['type'] == 'chat_message') {
       final person = Person(name: title);
       styleInfo = MessagingStyleInformation(person, messages: [Message(body, DateTime.now(), person)]);
    }

    // ✅ 3. Attach Quick Actions
    List<AndroidNotificationAction> actions = [];
    if (message.data['type'] == 'chat_message') {
      actions = [
        const AndroidNotificationAction(
          'REPLY_ACTION', 'Reply', allowGeneratedReplies: true, showsUserInterface: false, 
          inputs: [AndroidNotificationActionInput(label: 'Type a message...')]
        ),
        const AndroidNotificationAction('MARK_READ_ACTION', 'Mark as Read', showsUserInterface: false),
      ];
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      AppConfig.notificationChannelId,
      AppConfig.notificationChannelName,
      channelDescription: AppConfig.notificationChannelDesc,
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
    // ✅ FIX: Prevent Crashlytics from executing and crashing on Web
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
  static bool _isNavigatingToCall = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    _listenForIncomingCalls();
    _listenForCallKitEvents(); 
    _setupInteractedMessage();
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
      await NotificationService().init();
      AuthService().performGlobalSilentSync();
    }
  }

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

  void _handleNotificationClick(RemoteMessage message) async {
    // ✅ FIX: Wait for Splash Screen
    int waitCount = 0;
    while (appRouter.routerDelegate.currentConfiguration.uri.path == '/' && waitCount < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
    }
    final data = message.data;
    
    if (data['type'] == 'incoming_call' || data['type'] == 'video_call') {
      if (_isNavigatingToCall) return; // ✅ Block double-push
      _isNavigatingToCall = true;
      Future.delayed(const Duration(seconds: 2), () => _isNavigatingToCall = false);

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
    FlutterCallkitIncoming.onEvent.listen((event) async { // Make sure this is async
      switch (event!.event) {
        case Event.actionCallAccept:
          // ✅ FIX: Wait for Splash Screen
          int waitCount = 0;
          while (appRouter.routerDelegate.currentConfiguration.uri.path == '/' && waitCount < 50) {
            await Future.delayed(const Duration(milliseconds: 100));
            waitCount++;
          }
          if (_isNavigatingToCall) return; // ✅ Block double-push
          _isNavigatingToCall = true;
          Future.delayed(const Duration(seconds: 2), () => _isNavigatingToCall = false);

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
            'autoAccept': true,
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

        if (isAlreadyInCall) {
          SocketService().socket?.emit('reject_call', {
            'targetUserId': data['callerId'],
            'reason': 'user_busy'
          });
          debugPrint('Rejected background call from ${data['callerId']} because user is busy.');
          return;
        }

        if (!isAuthScreen) {
          final callArgs = {
            'isGroupCall': isGroup, 
            'isVideoCall': data['callerData']?['isVideoCall'] ?? false, 
            'remoteName': displayRemoteName,
            'remoteId': data['callerId'] ?? "", 
            'channelName': data['channelName'] ?? "",
            'remoteAvatar': data['callerData']?['callerAvatar'], 
            'isIncoming': true, 
          };

          if (kIsWeb) {
            _showWebCallBanner(callArgs);
          } else {
            // ✅ FIX: Add the debounce lock to the Socket Listener!
            // This stops the Socket from pushing a 2nd screen if the Notification already did it.
            if (_isNavigatingToCall) return; 
            _isNavigatingToCall = true;
            Future.delayed(const Duration(seconds: 3), () => _isNavigatingToCall = false);

            appRouter.push('/call', extra: callArgs);
          }
        }
      }
    });
  }

  // ✅ NEW METHOD: Display a sliding banner for incoming web calls
  void _showWebCallBanner(Map<String, dynamic> callArgs) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
                padding: const EdgeInsets.all(16),
                constraints: const BoxConstraints(maxWidth: 500), // Keep it centered on wide screens
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2), 
                      blurRadius: 20, 
                      offset: const Offset(0, 10)
                    )
                  ]
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: (callArgs['remoteAvatar'] != null && callArgs['remoteAvatar'].toString().isNotEmpty && !callArgs['remoteAvatar'].toString().contains('profile/picture')) 
                          ? NetworkImage(callArgs['remoteAvatar']) 
                          : null,
                      child: (callArgs['remoteAvatar'] == null || callArgs['remoteAvatar'].toString().isEmpty || callArgs['remoteAvatar'].toString().contains('profile/picture')) 
                          ? Icon(Icons.person, color: Colors.grey[600], size: 28) 
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            callArgs['remoteName'], 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)
                          ),
                          const SizedBox(height: 4),
                          Text(
                            callArgs['isVideoCall'] ? "Incoming Video Call..." : "Incoming Voice Call...", 
                            style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 13, fontWeight: FontWeight.w600)
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Decline Button
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        SocketService().socket?.emit('reject_call', {
                          'targetUserId': callArgs['remoteId'],
                          'reason': 'declined'
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.call_end, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Accept Button
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        // ✅ User interacted! Audio autoplay is now unlocked.
                        appRouter.push('/call', extra: callArgs);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
                        child: Icon(callArgs['isVideoCall'] ? Icons.videocam : Icons.call, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        // Slide down from top effect
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1), 
            end: Offset.zero
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutBack)),
          child: child,
        );
      },
    );
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