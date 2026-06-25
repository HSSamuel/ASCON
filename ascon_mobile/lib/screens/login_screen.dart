import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:go_router/go_router.dart'; 

import '../services/auth_service.dart';
import '../services/notification_service.dart'; 
import '../services/socket_service.dart'; 
import '../services/biometric_service.dart'; 
import 'register_screen.dart';
import 'forgot_password_screen.dart';

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
  final BiometricService _biometricService = BiometricService(); 
  
  bool _isEmailLoading = false;
  bool _obscurePassword = true; 
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _checkBiometrics();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    bool available = await _biometricService.isBiometricAvailable;
    if (mounted) setState(() => _canCheckBiometrics = available);
  }

  // ✅ FIX 1: Pass email and password into the Dialog
  void _showBiometricOptInDialog(Map<String, dynamic> user, String email, String password) {
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
              // ✅ FIX 2: Pass email and password to the Auth Service
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

  Future<void> _handleBiometricLogin() async {
    bool hasConsent = await _authService.isBiometricEnabled();
    if (!hasConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in with your password once to enable Biometrics.")),
      );
      return;
    }

    bool authenticated = await _biometricService.authenticate();
    if (authenticated) {
      setState(() => _isEmailLoading = true); 

      // ✅ FIX 3: Fetch the stored credentials to perform a silent login
      final creds = await _authService.getBiometricCredentials();
      
      if (creds != null) {
        final result = await _authService.login(creds['email']!, creds['password']!);
        if (mounted) setState(() => _isEmailLoading = false);

        if (result['success']) {
          _handleLoginSuccess(result['data']['user']);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message']), backgroundColor: Colors.red)
          );
        }
      } else {
        // Fallback to token if credentials missing
        String? validToken = await _authService.getToken();
        if (mounted) setState(() => _isEmailLoading = false);

        if (validToken != null) {
          final user = await _authService.getCachedUser();
          if (user != null) {
            _handleLoginSuccess(user);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Profile data missing. Please log in manually."))
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Session expired. Please log in manually."))
          );
        }
      }
    }
  }

  Future<void> _handleLoginSuccess(Map<String, dynamic> user) async {
    _syncNotificationToken();

    if (user['id'] != null || user['_id'] != null) {
      final String userId = user['id'] ?? user['_id'];
      SocketService().connectUser(userId);
    }

    if (widget.pendingNavigation != null) {
      context.go('/home');
      Future.delayed(const Duration(milliseconds: 600), () {
        NotificationService().handleNavigation(widget.pendingNavigation!);
      });
      return; 
    }

    _navigateToHome(); 
  }

  Future<void> _syncNotificationToken() async {
    if (kIsWeb) return; 
    try {
      await NotificationService().syncToken();
    } catch (e) {
      debugPrint("⚠️ Failed to sync token on login: $e");
    }
  }

  void _navigateToHome() {
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
        
        bool alreadyEnabled = await _authService.isBiometricEnabled();
        bool hardwareAvailable = await _biometricService.isBiometricAvailable;

        if (!alreadyEnabled && hardwareAvailable && mounted) {
          // ✅ FIX 4: Pass the typed email and password here
          _showBiometricOptInDialog(result['data']['user'], email, password);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final bool isAnyLoading = _isEmailLoading; 

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF0F4F8),
      body: Stack(
        children: [
          Positioned(
            top: -50, left: -50,
            child: Container(
              height: 250, width: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, color: primaryColor.withOpacity(isDark ? 0.3 : 0.2)),
            ),
          ),
          Positioned(
            bottom: -100, right: -50,
            child: Container(
              height: 300, width: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: primaryColor.withOpacity(isDark ? 0.4 : 0.15)),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 60.0, sigmaY: 60.0), child: const SizedBox()),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.8), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          height: 90, width: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle, color: Colors.white, 
                            boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))]
                          ),
                          child: ClipOval(child: Image.asset('assets/logo.png', fit: BoxFit.cover, errorBuilder: (c, o, s) => Icon(Icons.school, size: 70, color: primaryColor))),
                        ),
                      ),
                      const SizedBox(height: 16), 
                      Text('Welcome Back', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: primaryColor, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text('Sign in to access your alumni network', style: TextStyle(fontSize: 14, color: subTextColor)),
                      const SizedBox(height: 28), 

                      TextFormField(
                        controller: _emailController, enabled: !isAnyLoading, 
                        decoration: InputDecoration(
                          labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined, color: primaryColor, size: 20),
                          filled: true, fillColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5), 
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        )
                      ),
                      const SizedBox(height: 12), 
                      TextFormField(
                        controller: _passwordController, enabled: !isAnyLoading, obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password', prefixIcon: Icon(Icons.lock_outline, color: primaryColor, size: 20),
                          filled: true, fillColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
                        ),
                      ),
                      
                      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: isAnyLoading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())), child: Text("Forgot Password?", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13)))),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 45, 
                              child: ElevatedButton(
                                onPressed: isAnyLoading ? null : loginUser, 
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor, foregroundColor: Colors.white, 
                                  elevation: 5, shadowColor: primaryColor.withOpacity(0.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                ), 
                                child: _isEmailLoading 
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                                  : const Text('LOGIN', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.2)) 
                              )
                            ),
                          ),
                          if (_canCheckBiometrics) ...[
                            const SizedBox(width: 12),
                            Container(
                              height: 45, width: 45, 
                              decoration: BoxDecoration(
                                color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12), border: Border.all(color: primaryColor.withOpacity(0.3))
                              ),
                              child: IconButton(icon: Icon(Icons.fingerprint, color: primaryColor, size: 24), onPressed: isAnyLoading ? null : _handleBiometricLogin),
                            )
                          ]
                        ],
                      ),
                      const SizedBox(height: 16), 

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