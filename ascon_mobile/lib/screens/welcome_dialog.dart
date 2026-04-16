import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WelcomeDialog extends StatefulWidget {
  final String userName;
  final VoidCallback? onGetStarted; 

  const WelcomeDialog({
    super.key, 
    required this.userName,
    this.onGetStarted, 
  });

  @override
  State<WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<WelcomeDialog> {
  // ✅ This lock prevents double-clicks!
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    
    final containerColor = isDark ? Colors.grey[800] : const Color(0xFFF5F7F6);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardColor, 
      insetPadding: const EdgeInsets.all(20), 
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4), 
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryColor, width: 2),
                ),
                child: CircleAvatar(
                  radius: 25,
                  backgroundImage: const AssetImage('assets/logo.png'), 
                  backgroundColor: isDark ? Colors.grey[200] : Colors.transparent, 
                ),
              ),
              const SizedBox(height: 15),

              Text(
                "Welcome to the ASCON Alumni Association!",
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor, 
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: containerColor, 
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
                        color: subTextColor, 
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                decoration: BoxDecoration(
                  color: containerColor, 
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
                              color: textColor, 
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

              // --- 5. BULLETPROOF BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  // ✅ Disables the button completely if it's already processing
                  onPressed: _isProcessing ? null : () {
                    setState(() {
                      _isProcessing = true; // Lock the button immediately
                    });
                    
                    if (widget.onGetStarted != null) {
                      widget.onGetStarted!(); 
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  // ✅ Shows a loading spinner so the user knows it worked
                  child: _isProcessing 
                    ? const SizedBox(
                        height: 24, 
                        width: 24, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Text(
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