import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'; 
import 'package:go_router/go_router.dart'; 
import 'edit_profile_screen.dart'; // ✅ Add this import

import '../services/auth_service.dart';
import '../services/notification_service.dart'; 
import '../services/socket_service.dart'; 
import '../services/biometric_service.dart'; // ✅ Added import
import '../config.dart'; 
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'welcome_dialog.dart'; 

class LoginScreen extends StatefulWidget {
  final Map<String, dynamic>? pendingNavigation;

  const LoginScreen({super.key, this.pendingNavigation});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final BiometricService _biometricService = BiometricService(); // ✅ Instance

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? AppConfig.googleWebClientId : null,
    serverClientId: kIsWeb ? null : AppConfig.googleWebClientId,
  );
  
  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true; 
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    // ✅ Only check biometrics if NOT running on Web
    if (!kIsWeb) {
      _checkBiometrics();
    }
  }

  Future<void> _checkBiometrics() async {
    bool available = await _biometricService.isBiometricAvailable;
    if (mounted) setState(() => _canCheckBiometrics = available);
  }

  // ✅ OPT-IN DIALOG for Biometrics
  void _showBiometricOptInDialog(String email, String password, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enable Biometric Login?"),
        content: const Text("Would you like to use FaceID/Fingerprint for faster access next time?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLoginSuccess(user);
            },
            child: const Text("SKIP"),
          ),
          ElevatedButton(
            onPressed: () async {
              await _authService.enableBiometrics(email, password);
              if (mounted) {
                Navigator.pop(context);
                _handleLoginSuccess(user);
              }
            },
            child: const Text("ENABLE"),
          ),
        ],
      ),
    );
  }

  // ✅ HANDLE BIOMETRIC BUTTON TAP
  Future<void> _handleBiometricLogin() async {
    bool hasConsent = await _authService.isBiometricEnabled();
    if (!hasConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in with password once to enable Biometrics.")),
      );
      return;
    }

    bool authenticated = await _biometricService.authenticate();
    if (authenticated) {
      setState(() => _isEmailLoading = true); 
      final result = await _authService.loginWithStoredCredentials();
      if (mounted) setState(() => _isEmailLoading = false);

      if (result['success']) {
        _handleLoginSuccess(result['data']['user']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Biometric login failed: ${result['message']}")),
        );
      }
    }
  }

  Future<void> _handleLoginSuccess(Map<String, dynamic> user) async {
    _syncNotificationToken();

    if (user['id'] != null || user['_id'] != null) {
      final String userId = user['id'] ?? user['_id'];
      SocketService().connectUser(userId);
    }

    String safeName = user['fullName'] ?? "Alumni"; 

    // Handle Pending Navigation from Push Notifications
    if (widget.pendingNavigation != null) {
      debugPrint("🚀 Handling Pending Navigation after Login...");
      context.go('/home');
      Future.delayed(const Duration(milliseconds: 600), () {
        NotificationService().handleNavigation(widget.pendingNavigation!);
      });
      return; 
    }

    // ✅ NEW: Check if the profile is incomplete before routing
    var year = user['yearOfAttendance'];
    bool isProfileIncomplete = year == null || 
                               year == 0 || 
                               year == "null" || 
                               year.toString().trim().isEmpty;

    bool hasSeenWelcome = user['hasSeenWelcome'] ?? false;

    if (hasSeenWelcome) {
      if (isProfileIncomplete) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EditProfileScreen(
              userData: user,
              isFirstTime: true,
            ),
          ),
        );
      } else {
        _navigateToHome(safeName);
      }
    } else {
      // First time login: Show Welcome Dialogue first
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => WelcomeDialog( // ✅ Rename to 'dialogContext'
          userName: safeName,
          onGetStarted: () async {
            // Note: If WelcomeDialog pops itself internally when clicked,
            // we MUST check `if (!mounted)` before using the outer context.
            await _markWelcomeAsSeen();
            
            if (!mounted) return; // ✅ Crucial crash prevention check
            
            if (isProfileIncomplete) {
              Navigator.pushReplacement(
                context, // ✅ Safely uses the Login Screen's context
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(
                    userData: user,
                    isFirstTime: true,
                  ),
                ),
              );
            } else {
              _navigateToHome(safeName); 
            }
          }, 
        ),
      );
    }
  }

  Future<void> _syncNotificationToken() async {
    if (kIsWeb) return; 
    try {
      await NotificationService().syncToken();
    } catch (e) {
      debugPrint("⚠️ Failed to sync token on login: $e");
    }
  }

  Future<void> _markWelcomeAsSeen() async {
    try {
      await _authService.markWelcomeSeen(); 
    } catch (e) {
      debugPrint("❌ Failed to mark welcome as seen: $e");
    }
  }

  void _navigateToHome(String userName) {
    if (!mounted) return;
    context.go('/home');
  }

  Future<void> loginUser() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill in all fields"), backgroundColor: Colors.orange));
      return;
    }
    FocusScope.of(context).unfocus();
    
    setState(() => _isEmailLoading = true);
    
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final result = await _authService.login(email, password);
      
      if (!mounted) return;

      if (result['success']) {
        setState(() => _isEmailLoading = false);
        
        // ✅ Check if we should prompt for Biometrics
        bool alreadyEnabled = await _authService.isBiometricEnabled();
        bool hardwareAvailable = await _biometricService.isBiometricAvailable;

        if (!alreadyEnabled && hardwareAvailable && mounted) {
          _showBiometricOptInDialog(email, password, result['data']['user']);
        } else {
          _handleLoginSuccess(result['data']['user']);
        }
      } else {
        setState(() => _isEmailLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) setState(() => _isEmailLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Error: ${e.toString()}"), backgroundColor: Colors.red));
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      setState(() => _isGoogleLoading = true);
      
      GoogleSignInAccount? googleUser;
      if (kIsWeb) {
        try { googleUser = await _googleSignIn.signInSilently(); } catch (e) {}
      }
      if (googleUser == null) {
  try { 
    googleUser = await _googleSignIn.signIn(); 
  } catch (error) {
    if (mounted) {
      setState(() => _isGoogleLoading = false);
      
      // ✅ Expose the error to the user and console
      debugPrint("🔴 Google Sign-In Error: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Google Sign-In Failed: ${error.toString()}"), 
          backgroundColor: Colors.red
        ),
      );
    }
    return; 
  }
}
      if (googleUser == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? tokenToSend = googleAuth.idToken ?? googleAuth.accessToken;

      if (tokenToSend == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }
      
      final result = await _authService.googleLogin(tokenToSend);
      if (!mounted) return;
      setState(() => _isGoogleLoading = false);

      if (result['success']) {
        if (result['statusCode'] == 200) {
          _handleLoginSuccess(result['data']['user']);
        } else if (result['statusCode'] == 404) {
          final googleData = result['data']['googleData'];
          Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen(
            prefilledName: googleData['fullName'], 
            prefilledEmail: googleData['email'],
            googleToken: googleAuth.idToken,
          )));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? "Google Login Failed"), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("An error occurred during Google Login."), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final cardColor = Theme.of(context).cardColor;
    final bool isAnyLoading = _isEmailLoading || _isGoogleLoading;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF0F4F8),
      body: Stack(
        children: [
          // ==========================================
          // 1. FLOATING BACKGROUND ORBS
          // ==========================================
          // Top Left Orb
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              height: 250,
              width: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(isDark ? 0.3 : 0.2),
              ),
            ),
          ),
          // Bottom Right Orb
          Positioned(
            bottom: -100,
            right: -50,
            child: Container(
              height: 300,
              width: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(isDark ? 0.4 : 0.15),
              ),
            ),
          ),
          
          // ==========================================
          // 2. FROSTED GLASS EFFECT (BackdropFilter)
          // ==========================================
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60.0, sigmaY: 60.0), // Heavy blur for premium look
              child: const SizedBox(), // Empty container to hold the blur
            ),
          ),

          // ==========================================
          // 3. THE FOREGROUND LOGIN CONTENT
          // ==========================================
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Container(
                  // The "Glass Pane" card
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.8),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          height: 90, width: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle, 
                            color: Colors.white, // Ensure logo pops on glass
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.2), 
                                blurRadius: 15, 
                                offset: const Offset(0, 8)
                              )
                            ]
                          ),
                          child: ClipOval(
                            child: Image.asset('assets/logo.png', fit: BoxFit.cover, errorBuilder: (c, o, s) => Icon(Icons.school, size: 70, color: primaryColor))
                          ),
                        ),
                      ),
                      const SizedBox(height: 16), 
                      Text('Welcome Back', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: primaryColor, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text('Sign in to access your alumni network', style: TextStyle(fontSize: 14, color: subTextColor)),
                      const SizedBox(height: 28), 

                      // Text Fields
                      TextFormField(
                        controller: _emailController, 
                        enabled: !isAnyLoading, 
                        decoration: InputDecoration(
                          labelText: 'Email Address', 
                          prefixIcon: Icon(Icons.email_outlined, color: primaryColor, size: 20),
                          filled: true,
                          fillColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5), // Semi-transparent fields
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        )
                      ),
                      const SizedBox(height: 12), 
                      TextFormField(
                        controller: _passwordController, 
                        enabled: !isAnyLoading, 
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password', 
                          prefixIcon: Icon(Icons.lock_outline, color: primaryColor, size: 20),
                          filled: true,
                          fillColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
                        ),
                      ),
                      
                      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: isAnyLoading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())), child: Text("Forgot Password?", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13)))),
                      const SizedBox(height: 8),

                      // Login & Biometric Row
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 45, // ✅ Reduced from 50 to 45
                              child: ElevatedButton(
                                onPressed: isAnyLoading ? null : loginUser, 
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor, 
                                  foregroundColor: Colors.white, 
                                  elevation: 5,
                                  shadowColor: primaryColor.withOpacity(0.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                ), 
                                child: _isEmailLoading 
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                                  : const Text('LOGIN', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.2)) // ✅ slightly reduced font size to fit better
                              )
                            ),
                          ),
                          if (_canCheckBiometrics) ...[
                            const SizedBox(width: 12),
                            Container(
                              height: 45, width: 45, // ✅ Reduced from 50x50 to perfectly match the Login button height
                              decoration: BoxDecoration(
                                color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: primaryColor.withOpacity(0.3))
                              ),
                              child: IconButton(
                                icon: Icon(Icons.fingerprint, color: primaryColor, size: 24), // ✅ Slightly reduced icon size to fit
                                onPressed: isAnyLoading ? null : _handleBiometricLogin,
                              ),
                            )
                          ]
                        ],
                      ),
                      const SizedBox(height: 16), // Spacing between buttons
                      
                      // Google Button
                      SizedBox(
                        width: double.infinity, 
                        height: 45, // ✅ Reduced from 50 to 45
                        child: OutlinedButton(
                          onPressed: isAnyLoading ? null : signInWithGoogle, 
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: primaryColor.withOpacity(0.5), width: 1.5), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
                            backgroundColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5)
                          ), 
                          child: _isGoogleLoading 
                            ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2)) 
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center, 
                                children: [
                                  Image.asset('assets/images/google_logo.png', height: 20), // ✅ Slightly reduced image size
                                  const SizedBox(width: 10), 
                                  Text("Continue with Google", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14)) // ✅ Slightly reduced text size
                                ]
                              )
                        )
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center, 
                        children: [
                          Text("New here? ", style: TextStyle(fontSize: 14, color: subTextColor)), 
                          GestureDetector(
                            onTap: () { if (!isAnyLoading) Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())); }, 
                            child: Text("Create Account", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14))
                          )
                        ]
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}