import 'package:flutter/material.dart';
import '../services/auth_service.dart'; 

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final AuthService _authService = AuthService(); 
  bool _isLoading = false;

  Future<void> _handleReset() async {
    // 1. Validation
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email"), backgroundColor: Colors.red),
      );
      return;
    }

    // 2. Close Keyboard (UX Improvement)
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    print("🔵 START: Attempting to reset password for ${_emailController.text}");

    try {
      // 3. Call Backend
      final result = await _authService.forgotPassword(_emailController.text.trim());
      print("🟢 END: Result received: $result");

      if (!mounted) return;

      if (result['success']) {
        _showSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? "Failed to send email"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print("🔴 ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An error occurred: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      // 4. GUARANTEED: Stop Spinner
      if (mounted) {
        setState(() => _isLoading = false);
        print("⚪ SPINNER: Stopped");
      }
    }
  }

  void _showSuccessDialog() {
    // Dynamic Colors
    final dialogBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final primaryColor = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text("Email Sent", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
        content: Text("Check your inbox (and spam folder) for the password reset link.", style: TextStyle(color: textColor)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close Dialog
              Navigator.pop(context); // Go back to Login
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic Theme Colors
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Icon(Icons.lock_reset, size: 80, color: primaryColor),
              const SizedBox(height: 20),
              Text(
                "Forgot Password?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor),
              ),
              const SizedBox(height: 8),
              Text(
                "Enter your email address and we will send you a link to reset your password.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: subTextColor),
              ),
              const SizedBox(height: 40),
              
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Email Address",
                  labelStyle: TextStyle(fontSize: 13, color: subTextColor),
                  prefixIcon: Icon(Icons.email_outlined, color: primaryColor),
                ),
              ),
              
              const SizedBox(height: 24),
              
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("SEND RESET LINK", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}