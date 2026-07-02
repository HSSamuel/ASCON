import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart'; 
import 'package:flutter/foundation.dart';
import 'package:auto_start_flutter/auto_start_flutter.dart'; // ✅ Added AutoStart package
import 'dart:ui'; 
import '../services/notification_service.dart';

class NotificationPermissionScreen extends StatefulWidget {
  final String nextPath;

  const NotificationPermissionScreen({super.key, required this.nextPath});

  @override
  State<NotificationPermissionScreen> createState() => _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState extends State<NotificationPermissionScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _complete(bool granted) async {
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_notification_prompt', true);

    if (granted) {
      // 1. Explicitly trigger the native OS notification permission popup
      if (!kIsWeb) {
        await Permission.notification.request();
      }

      // 2. Initialize Firebase's internal permission state
      await NotificationService().requestPermission();
      
      // 3. Android-Specific Background Call Permissions
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        
        // A. Request System Alert for CallKit (Full Screen Intents)
        final status = await Permission.systemAlertWindow.status;
        if (!status.isGranted) {
           await Permission.systemAlertWindow.request();
        }

        // B. Request Battery Optimization Bypass (Prevents background socket death)
        bool isRestricted = await Permission.ignoreBatteryOptimizations.isDenied;
        if (isRestricted && mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1F2C34),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Keep Calls Connected', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: const Text(
                'To ensure you receive incoming Alumni calls even when the app is closed, please set battery optimization to "Unrestricted" in the next screen.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await Permission.ignoreBatteryOptimizations.request();
                  },
                  child: const Text('Allow', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }

        // C. Request AutoStart Bypass (Prevents Task Killers on Xiaomi/Oppo/Vivo)
        try {
          var isAutoStartAvail = await isAutoStartAvailable;
          if (isAutoStartAvail == true && mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF1F2C34),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Enable AutoStart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                content: const Text(
                  'Your device requires AutoStart to ring for background calls. Please toggle it ON for ASCON Connect in the next screen.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await getAutoStartPermission();
                    },
                    child: const Text('Enable', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }
        } catch (e) {
          debugPrint('AutoStart error: $e');
        }
      }
    }

    if (mounted) {
      context.go(widget.nextPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryGreen = const Color(0xFF1B5E3A);
    final Color accentGold = const Color(0xFFD4AF37);
    final Color bg = isDark ? const Color(0xFF121212) : Colors.white;
    final Color cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // BACKGROUND DECORATION
          Positioned(
            top: -100, right: -100,
            child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: primaryGreen.withOpacity(0.05))),
          ),
          Positioned(
            bottom: -50, left: -50,
            child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: accentGold.withOpacity(0.05))),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double availableHeight = constraints.maxHeight;
                final double imageHeight = availableHeight * 0.45; // Take 45% of height

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                  child: Column(
                    children: [
                      const Spacer(),

                      // --- ANIMATED HERO IMAGE ---
                      SizedBox(
                        height: imageHeight,
                        width: double.infinity,
                        child: TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutBack,
                          builder: (context, double value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      borderRadius: BorderRadius.circular(30),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                                          blurRadius: 30,
                                          offset: const Offset(0, 15),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(30),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.asset(
                                            'assets/images/alumni_group.png',
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, o, s) => Container(
                                              color: Colors.grey[200],
                                              child: Icon(Icons.groups_rounded, size: 80, color: Colors.grey[400]),
                                            ),
                                          ),
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 15, right: 15, 
                                    child: ScaleTransition(
                                      scale: Tween(begin: 1.0, end: 1.1).animate(_pulseController),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                                        ),
                                        child: Icon(Icons.notifications_active_rounded, color: primaryGreen, size: 24),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      SizedBox(height: availableHeight * 0.05), // 5% Gap

                      // --- TEXT SECTION ---
                      Text(
                        "Stay in the loop",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF2D3436)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Enable notifications to get real-time updates on reunions, opportunities, and the latest news from ASCON.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lato(fontSize: 14, height: 1.4, color: isDark ? Colors.white70 : Colors.grey[600]),
                      ),

                      const Spacer(),

                      // --- BUTTONS ---
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _complete(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 5,
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text("Turn on Notifications", style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                      
                      TextButton(
                        onPressed: _isLoading ? null : () => _complete(false),
                        child: Text("Maybe Later", style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
                      ),
                      
                      const SizedBox(height: 10),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}