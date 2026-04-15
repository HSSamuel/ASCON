import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:go_router/go_router.dart'; 

import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/socket_service.dart';
import 'edit_profile_screen.dart'; 

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    
    _controller.forward();
    _checkSessionAndNavigate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkSessionAndNavigate() async {
    // 1. Wait for animation
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // 2. Check Session Validity
    final bool isValid = await _authService.isSessionValid();
    
    // 3. Determine Next Destination (Default)
    String nextPath = isValid ? '/home' : '/login';

    // ✅ FIX 1: Notification Permission Check (Runs for EVERYONE now)
    final prefs = await SharedPreferences.getInstance();
    bool hasSeenPrompt = prefs.getBool('has_seen_notification_prompt') ?? false;
    
    // Check actual system permission (only on Mobile)
    bool isAuthorized = false;
    if (!kIsWeb) {
       final status = await NotificationService().getAuthorizationStatus();
       isAuthorized = status == AuthorizationStatus.authorized;
    }

    // If never seen prompt AND not authorized -> Go to Permission Screen FIRST
    // We pass 'nextPath' so it knows where to go AFTER permission is handled.
    if (!hasSeenPrompt && !isAuthorized) {
      if (mounted) {
        context.go('/notification_permission', extra: nextPath);
      }
      return; // 🛑 STOP HERE
    }

    // 4. Session & Profile Checks (Only if Logged In)
    if (isValid) {
      try {
        SocketService().initSocket();
        NotificationService().init();
      } catch (e) {
        debugPrint("⚠️ Init error: $e");
      }

      // 4b. Splash Guard: Check Profile Completeness
      final user = await _authService.getCachedUser();
      var year = user?['yearOfAttendance'];
      
      bool isProfileIncomplete = year == null || 
                                 year == 0 || 
                                 year == "null" || 
                                 year.toString().trim().isEmpty;

      if (isProfileIncomplete) {
        debugPrint("⚠️ Splash Guard: Incomplete Profile. Redirecting.");
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => EditProfileScreen(
                userData: user ?? {},
                isFirstTime: true,
              ),
            ),
          );
        }
        return; 
      }
      
      // 4c. Check for Deep Links (Chat/Notifications)
      RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null && _isChatMessage(initialMessage)) {
        // The router/notification service will handle the specific path
        // We just ensure we go to home first to initialize the shell
        nextPath = '/home'; 
      }
    }

    // 5. Final Navigation
    if (mounted) {
      context.go(nextPath);
    }
  }

  bool _isChatMessage(RemoteMessage message) {
    return message.data['type'] == 'chat_message' ||
           message.data['route'] == 'chat_screen';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    const asconGreen = Color(0xFF1B5E20); 
    final glowColor = Colors.greenAccent.withOpacity(0.8);

    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double logoSize = (screenWidth < screenHeight ? screenWidth : screenHeight) * 0.5; 
    if (logoSize > 300) logoSize = 300;

    return Scaffold(
      backgroundColor: scaffoldBg, 
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.grey[900] : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black54 : Colors.black26,
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 30), 
                Text(
                  "... the natural place for human capacity building.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14, 
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white.withOpacity(0.9) : asconGreen,
                    shadows: [
                      Shadow(blurRadius: 15.0, color: glowColor, offset: const Offset(0, 0)),
                      Shadow(blurRadius: 5.0, color: glowColor, offset: const Offset(0, 0)),
                    ],
                  ),
                ),
                const SizedBox(height: 50),
                CircularProgressIndicator(color: Theme.of(context).primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}