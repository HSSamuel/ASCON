import 'dart:ui'; // ✅ Needed for Glassmorphism blur
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl/intl.dart'; // ✅ Needed for Date Format
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../widgets/loading_dialog.dart';
import 'edit_profile_screen.dart'; // ✅ Add this import

class RegisterScreen extends StatefulWidget {
  final String? prefilledName;
  final String? prefilledEmail;
  final String? googleToken;

  const RegisterScreen({
    super.key, 
    this.prefilledName, 
    this.prefilledEmail, 
    this.googleToken
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // ✅ DOB Controller
  final TextEditingController _dobController = TextEditingController();
  DateTime? _selectedDate;

  String _completePhoneNumber = ""; 

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.prefilledName ?? '');
    _emailController = TextEditingController(text: widget.prefilledEmail ?? '');
  }

  @override
  void dispose() {
    _dobController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ✅ Date Picker Logic
  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    // Normalize to Midnight to avoid time conflicts
    final DateTime today = DateTime(now.year, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990), // Default starting point
      firstDate: DateTime(1900),   // ✅ Expanded range for older alumni
      lastDate: today,             // ✅ Strictly today (no future birthdays)
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor, 
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('MMM d, y').format(picked);
      });
    }
  }

  void _showSuccessDialog(Map<String, dynamic> user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (dialogContext) { // ✅ Rename to 'dialogContext' to avoid shadowing
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: bgColor,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.green[900] : Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.green, size: 60),
                ),
                const SizedBox(height: 20),
                
                Text(
                  "Registration Successful!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
                ),
                const SizedBox(height: 10),
                
                Text(
                  "Your account has been created.\nLet's complete your profile to set up your Digital ID and Class Group.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color),
                ),
                const SizedBox(height: 25),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // ✅ 1. Pop the dialog using its own context
                      Navigator.pop(dialogContext); 
                      
                      // ✅ 2. Ensure the Register Screen is still active
                      if (!mounted) return; 
                      
                      // ✅ 3. Navigate using the Register Screen's main context
                      Navigator.pushReplacement(
                        context, 
                        MaterialPageRoute(
                          builder: (_) => EditProfileScreen(
                            userData: user,
                            isFirstTime: true,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("COMPLETE PROFILE", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_completePhoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid phone number"), backgroundColor: Colors.red),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match"), backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LoadingDialog(message: "Creating Account..."),
    );

    try {
      final AuthService authService = AuthService();
      final result = await authService.register(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phoneNumber: _completePhoneNumber, 
        programmeTitle: "",
        yearOfAttendance: "",
        googleToken: widget.googleToken,
        dateOfBirth: _selectedDate?.toIso8601String(),
      );

      if (!mounted) return;

      Navigator.of(context).pop(); 

      if (result['success']) {
        // ✅ Extract the user data returned from your Node.js backend
        final user = result['data']['user'] ?? {}; 
        _showSuccessDialog(user); // ✅ Pass user data here
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? "Registration Failed"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF0F4F8),
      extendBodyBehindAppBar: true, // ✅ Allows glassmorphism to flow under AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent, // ✅ Transparent to see the blur
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // ==========================================
          // 1. FLOATING BACKGROUND ORBS
          // ==========================================
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
              filter: ImageFilter.blur(sigmaX: 60.0, sigmaY: 60.0),
              child: const SizedBox(),
            ),
          ),

          // ==========================================
          // 3. FOREGROUND CONTENT
          // ==========================================
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
              child: Container(
                // ✅ The "Glass Pane" Card
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          height: 90, width: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle, 
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.2), 
                                blurRadius: 15, 
                                offset: const Offset(0, 8)
                              )
                            ]
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/logo.png', 
                              fit: BoxFit.cover,
                              errorBuilder: (c,o,s) => Icon(Icons.school, size: 70, color: primaryColor)
                            )
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),

                      Text(
                        "Create Account",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: primaryColor, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Join the ASCON Alumni Network",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: subTextColor),
                      ),
                      const SizedBox(height: 30),

                      _buildTextField("Full Name", _nameController, Icons.person_outline),
                      const SizedBox(height: 16),
                      _buildTextField("Email Address", _emailController, Icons.email_outlined),
                      const SizedBox(height: 16),

                      _buildTextField(
                        "Date of Birth (Optional)",
                        _dobController,
                        Icons.cake_outlined,
                        readOnly: true,
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 16),

                      IntlPhoneField(
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          labelStyle: TextStyle(fontSize: 13, color: subTextColor),
                          filled: true,
                          fillColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5), // ✅ Premium transparency
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), // ✅ Removed hard border
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                        ),
                        initialCountryCode: 'NG', 
                        style: TextStyle(fontSize: 14, color: textColor),
                        dropdownTextStyle: TextStyle(fontSize: 14, color: textColor),
                        onChanged: (phone) {
                          _completePhoneNumber = phone.completeNumber; 
                        },
                      ),

                      const SizedBox(height: 16),
                      
                      _buildTextField("Password", _passwordController, Icons.lock_outline, isPassword: true),
                      const SizedBox(height: 16),
                      _buildTextField("Confirm Password", _confirmPasswordController, Icons.lock_outline, isPassword: true),

                      const SizedBox(height: 32),

                      SizedBox(
                        height: 50, // ✅ Taller for premium feel
                        child: ElevatedButton(
                          onPressed: _handleRegister, 
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 5,
                            shadowColor: primaryColor.withOpacity(0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("REGISTER", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Already a member? ", style: TextStyle(fontSize: 14, color: subTextColor)),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushAndRemoveUntil(
                                context, 
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                                (route) => false
                              );
                            },
                            child: Text("Login", style: TextStyle(color: primaryColor, fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ],
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

  // ✅ Updated to match the Glassmorphism aesthetics
  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isPassword = false, bool isNumber = false, bool readOnly = false, VoidCallback? onTap}) {
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final primaryColor = Theme.of(context).primaryColor;

    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      readOnly: readOnly,
      onTap: onTap,
      style: TextStyle(fontSize: 14, color: textColor),
      validator: (value) {
        if (label.contains("Optional")) return null; 
        return value == null || value.isEmpty ? 'Field required' : null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: subTextColor),
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5), // ✅ Transparent background
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), // ✅ Soft rounded corners
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ) 
          : null,
      ),
    );
  }
}