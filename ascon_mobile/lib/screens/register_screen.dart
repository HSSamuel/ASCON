import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../widgets/loading_dialog.dart';

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
  
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Profile Fields
  final _jobController = TextEditingController();
  final _orgController = TextEditingController();
  final _yearController = TextEditingController();
  final _otherProgrammeController = TextEditingController();
  final _bioController = TextEditingController();

  bool _obscurePassword = true;
  String? _selectedProgramme;

  final List<String> _programmeOptions = [
    "Management Programme",
    "Computer Programme",
    "Financial Management",
    "Leadership Development Programme",
    "Public Administration and Management",
    "Public Administration and Policy (Advanced)",
    "Public Sector Management Course",
    "Performance Improvement Course",
    "Creativity and Innovation Course",
    "Mandatory & Executive Programmes",
    "Postgraduate Diploma in Public Administration and Management",
    "Other"
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.prefilledName ?? '');
    _emailController = TextEditingController(text: widget.prefilledEmail ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _jobController.dispose();
    _orgController.dispose();
    _yearController.dispose();
    _otherProgrammeController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _showSuccessDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (dialogContext) { 
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
                  decoration: BoxDecoration(color: isDark ? Colors.green[900] : Colors.green[50], shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle, color: Colors.green, size: 60),
                ),
                const SizedBox(height: 20),
                
                Text("Registration Successful!", textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                const SizedBox(height: 10),
                
                Text(
                  "Your account has been created successfully. Please login to continue.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color),
                ),
                const SizedBox(height: 25),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext); 
                      if (!mounted) return; 
                      Navigator.pushAndRemoveUntil(
                        context, 
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("PROCEED TO LOGIN", style: TextStyle(fontWeight: FontWeight.bold)),
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
    
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match"), backgroundColor: Colors.red));
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (context) => const LoadingDialog(message: "Creating Account..."));

    try {
      final AuthService authService = AuthService();
      final result = await authService.register(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        programmeTitle: _selectedProgramme == "Other" ? "Other" : _selectedProgramme!,
        customProgramme: _selectedProgramme == "Other" ? _otherProgrammeController.text.trim() : "",
        yearOfAttendance: _yearController.text.trim(),
        jobTitle: _jobController.text.trim(),
        organization: _orgController.text.trim(),
        bio: _bioController.text.trim(),
        googleToken: widget.googleToken,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); 

      if (result['success']) {
        _showSuccessDialog(); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? "Registration Failed"), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF0F4F8),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: primaryColor), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          Positioned(top: -50, left: -50, child: Container(height: 250, width: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: primaryColor.withOpacity(isDark ? 0.3 : 0.2)))),
          Positioned(bottom: -100, right: -50, child: Container(height: 300, width: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: primaryColor.withOpacity(isDark ? 0.4 : 0.15)))),
          Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 60.0, sigmaY: 60.0), child: const SizedBox())),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.8), width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          height: 90, width: 90,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))]),
                          child: ClipOval(child: Image.asset('assets/logo.png', fit: BoxFit.cover, errorBuilder: (c,o,s) => Icon(Icons.school, size: 70, color: primaryColor))),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text("Create Account", textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: primaryColor, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text("Join the ASCON Alumni Network", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: subTextColor)),
                      const SizedBox(height: 30),

                      Text("Account Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor)),
                      const SizedBox(height: 10),
                      _buildTextField("Full Name", _nameController, Icons.person_outline),
                      const SizedBox(height: 12),
                      _buildTextField("Email Address", _emailController, Icons.email_outlined),
                      const SizedBox(height: 12),
                      _buildTextField("Password", _passwordController, Icons.lock_outline, isPassword: true),
                      const SizedBox(height: 12),
                      _buildTextField("Confirm Password", _confirmPasswordController, Icons.lock_outline, isPassword: true),

                      const SizedBox(height: 24),
                      Text("Professional Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor)),
                      const SizedBox(height: 10),

                      DropdownButtonFormField<String>(
                        value: _selectedProgramme,
                        isExpanded: true, isDense: true, dropdownColor: cardColor,
                        decoration: InputDecoration(
                          labelText: "Programme Attended",
                          labelStyle: TextStyle(fontSize: 13, color: subTextColor),
                          prefixIcon: Icon(Icons.school_outlined, color: primaryColor, size: 20),
                          filled: true, fillColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        items: _programmeOptions.map((String value) {
                          return DropdownMenuItem<String>(value: value, child: Text(value, style: TextStyle(fontSize: 14, color: textColor), overflow: TextOverflow.ellipsis));
                        }).toList(),
                        onChanged: (newValue) => setState(() => _selectedProgramme = newValue),
                        validator: (value) => value == null ? 'Please select a programme' : null,
                      ),

                      if (_selectedProgramme == "Other") ...[
                        const SizedBox(height: 12),
                        _buildTextField("Specify Programme Name", _otherProgrammeController, Icons.edit_note),
                      ],
                      const SizedBox(height: 12),
                      _buildTextField("Class Year (e.g. 2023)", _yearController, Icons.calendar_today_outlined, isNumber: true),
                      const SizedBox(height: 12),
                      _buildTextField("Job Title (Optional)", _jobController, Icons.work_outline),
                      const SizedBox(height: 12),
                      _buildTextField("Organization (Optional)", _orgController, Icons.business_outlined),
                      const SizedBox(height: 12),
                      _buildTextField("Short Bio (Optional)", _bioController, Icons.person_outline, maxLines: 3),

                      const SizedBox(height: 32),

                      SizedBox(
                        height: 45,
                        child: ElevatedButton(
                          onPressed: _handleRegister, 
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor, foregroundColor: Colors.white,
                            elevation: 5, shadowColor: primaryColor.withOpacity(0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("REGISTER", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Already a member? ", style: TextStyle(fontSize: 14, color: subTextColor)),
                          GestureDetector(
                            onTap: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false),
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

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isPassword = false, bool isNumber = false, int maxLines = 1}) {
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final primaryColor = Theme.of(context).primaryColor;

    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: TextStyle(fontSize: 14, color: textColor),
      validator: (value) {
        if (label.contains("Optional")) return null; 
        if (label == "Specify Programme Name" && _selectedProgramme == "Other" && (value == null || value.isEmpty)) return "Please specify";
        return value == null || value.isEmpty ? 'Field required' : null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: subTextColor),
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        filled: true, fillColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        suffixIcon: isPassword 
          ? IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)) 
          : null,
      ),
    );
  }
}