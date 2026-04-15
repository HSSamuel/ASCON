import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart'; // ✅ Import GoRouter

class WelcomeDialog extends StatelessWidget {
  final String userName;
  final VoidCallback? onGetStarted; 

  const WelcomeDialog({
    super.key, 
    required this.userName,
    this.onGetStarted, 
  });

  @override
  Widget build(BuildContext context) {
    // ✅ AUTO-DETECT THEME COLORS
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    
    // Dynamic Box Color: Light Grey in Day, Dark Grey in Night
    final containerColor = isDark ? Colors.grey[800] : const Color(0xFFF5F7F6);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardColor, // ✅ Dynamic Background
      insetPadding: const EdgeInsets.all(20), 
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- 1. TOP LOGO ---
              Container(
                padding: const EdgeInsets.all(4), 
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryColor, width: 2),
                ),
                child: CircleAvatar(
                  radius: 25,
                  backgroundImage: const AssetImage('assets/logo.png'), 
                  backgroundColor: isDark ? Colors.grey[200] : Colors.transparent, // Ensure logo is visible
                ),
              ),
              const SizedBox(height: 15),

              // --- 2. TITLE ---
              Text(
                "Welcome to the ASCON Alumni Association!",
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor, // ✅ Dynamic Text
                ),
              ),
              const SizedBox(height: 20),

              // --- 3. MESSAGE BODY (Dynamic Box) ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: containerColor, // ✅ Dynamic Box Color
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"Dear Esteemed Alumnus,',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: subTextColor, 
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    Text(
                      "On behalf of the Administrative Staff College of Nigeria (ASCON), I warmly welcome you to our Alumni Association.\n\n"
                      "This platform has been designed to strengthen the bonds we share as members of the ASCON family and to provide opportunities for continued professional development, networking, and collaboration.\n\n"
                      "Together, we will continue to uphold the values of excellence, integrity, and innovation that define ASCON.\n\n"
                      'Welcome aboard!"',
                      textAlign: TextAlign.justify,
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        height: 1.5, 
                        color: subTextColor, // ✅ Dynamic Text
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- 4. SIGNATURE BLOCK ---
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                decoration: BoxDecoration(
                  color: containerColor, // ✅ Dynamic Box Color
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 25,
                      backgroundImage: AssetImage('assets/ascondg.jpg'), 
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Mrs. Funke Femi Adepoju Ph.D",
                            style: GoogleFonts.lato(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: textColor, // ✅ Dynamic Text
                            ),
                          ),
                          Text(
                            "Director General, ASCON",
                            style: GoogleFonts.lato(
                              fontSize: 12,
                              color: subTextColor, 
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // --- 5. GET STARTED BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // ✅ 1. Trigger Backend Update
                    if (onGetStarted != null) onGetStarted!();

                    // ✅ 2. CLOSE DIALOG
                    Navigator.of(context).pop(); 
                    
                    // ✅ 3. NAVIGATE TO HOME SCREEN (Using GoRouter)
                    context.go('/home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Get Started",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}