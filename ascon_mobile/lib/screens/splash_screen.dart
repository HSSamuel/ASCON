import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkAuthState();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack)),
    );

    _animationController.forward();
  }

  Future<void> _checkAuthState() async {
    // 1. Give the animation time to play
    await Future.delayed(const Duration(milliseconds: 2000));
    
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    
    // 2. Check if they have ever seen the notification prompt
    final bool hasSeenPrompt = prefs.getBool('has_seen_notification_prompt') ?? false;

    // 3. Check if they are already logged in
    final authService = AuthService();
    final bool isLoggedIn = await authService.isSessionValid();

    if (!mounted) return;

    // 4. Routing Logic
    if (isLoggedIn) {
      context.go('/home');
    } else if (!hasSeenPrompt) {
      // Send them to the permission screen, and tell it to go to /login next
      context.go('/notification_permission', extra: '/login');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Extract the primary color from the current active theme
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/splash_logo_with_text.png', 
                      width: 250, 
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.school,
                          size: 100,
                          color: primaryColor, // ✅ Uses dynamic theme color
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor), // ✅ Uses dynamic theme color
                        strokeWidth: 3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}