import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; 
import 'package:go_router/go_router.dart'; 

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final dividerColor = Theme.of(context).dividerColor;

    return PopScope(
      canPop: false, 
      onPopInvoked: (didPop) {
        if (didPop) return;
        context.go('/home'); // Go to Home Tab
      },
      child: Scaffold(
        backgroundColor: scaffoldBg, 
        appBar: AppBar(
          title: Text("About ASCON", style: GoogleFonts.lato(fontWeight: FontWeight.w600, fontSize: 18)),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // --- 1. ENHANCED HERO SECTION ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1B5E3A), Color(0xFF2E8B57)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset('assets/logo.png', height: 60, width: 60),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Administrative Staff College of Nigeria",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "...the natural place for human capacity building.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lato(
                          color: const Color(0xFFFFD700), // Gold
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          fontStyle: FontStyle.italic, 
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // --- 2. LEADERSHIP & CARDS ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    
                    // ✅ DIRECTOR GENERAL CARD
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3), width: 1), 
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 80, height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                                  image: const DecorationImage(
                                    image: AssetImage('assets/ascondg.jpg'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ✅ UPDATED: Styled Name with "Ph.D" in Black/Thin
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: "Mrs. Funke F. Adepoju ",
                                            style: GoogleFonts.lato(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor,
                                            ),
                                          ),
                                          TextSpan(
                                            text: "Ph.D",
                                            style: GoogleFonts.lato(
                                              fontSize: 16, 
                                              fontWeight: FontWeight.w500, // Thin
                                              color: isDark ? Colors.white70 : Colors.black, // Black (Adaptive)
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Director-General",
                                      style: GoogleFonts.lato(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFD4AF37), // Gold
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Leading ASCON's mission to shape the future of public service in Nigeria.",
                                      style: GoogleFonts.lato(
                                        fontSize: 12,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                        fontStyle: FontStyle.italic
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "\"Our mission is clear: we are building a more effective, responsive, and forward-thinking public sector that meets the evolving needs of our nation.\"",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.lato(
                                fontSize: 13,
                                height: 1.4,
                                color: isDark ? Colors.grey[300] : Colors.grey[800],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Vision Card
                    _buildInfoCard(
                      context,
                      icon: Icons.visibility_outlined,
                      title: "Our Vision",
                      content: "To be the leading public administration training institution in Africa, setting the benchmark for excellence in civil service education, enhancing governmental effectiveness, and contributing to Nigeria’s sustainable development through capacity-building programs, leadership training, and policy research.",
                    ),
                    
                    const SizedBox(height: 16),

                    // Mission Card
                    _buildInfoCard(
                      context,
                      icon: Icons.track_changes_outlined,
                      title: "Our Mission",
                      content: "To provide cutting-edge administrative training, policy research, and advisory services that foster efficiency, accountability, and innovation in Nigeria’s public sector. We strive to equip government officials with the right skills, ethical standards, and strategic thinking capabilities to meet the demands of modern governance.",
                    ),
                    
                    const SizedBox(height: 16),

                    // Contact Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor, 
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Column(
                        children: [
                            Text(
                            "Contact Information",
                            style: GoogleFonts.lato(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildContactRow(context, Icons.location_on_outlined, "Topo, Badagry, Lagos State, Nigeria"),
                          Divider(height: 24, thickness: 0.5, color: dividerColor),
                          _buildContactRow(context, Icons.email_outlined, "info@ascon.gov.ng", onTap: () => _launchURL("mailto:info@ascon.gov.ng")),
                          Divider(height: 24, thickness: 0.5, color: dividerColor),
                          _buildContactRow(context, Icons.phone_outlined, "09010121012", onTap: () => _launchURL("tel:09010121012")),
                          Divider(height: 24, thickness: 0.5, color: dividerColor),
                          _buildContactRow(context, Icons.language, "www.ascon.gov.ng", onTap: () => _launchURL("https://ascon.gov.ng")),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Connect with ASCON
                    Text(
                      "Connect with ASCON", 
                      style: GoogleFonts.lato(
                        fontSize: 14, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.grey[600]
                      )
                    ),
                    const SizedBox(height: 15),
                    
                    // Social Icons Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSocialIcon(FontAwesomeIcons.facebook, const Color(0xFF1877F2), "https://web.facebook.com/ascontopobadagry"),
                        const SizedBox(width: 20),
                        _buildSocialIcon(FontAwesomeIcons.xTwitter, isDark ? Colors.white : Colors.black, "https://x.com/AsconBadagry"),
                        const SizedBox(width: 20),
                        _buildSocialIcon(FontAwesomeIcons.linkedin, const Color(0xFF0077B5), "https://www.linkedin.com/company/administrative-staff-college-of-nigeria-ascon/about"),
                        const SizedBox(width: 20),
                        _buildSocialIcon(FontAwesomeIcons.instagram, const Color(0xFFE4405F), "https://www.instagram.com/asconbadagry"),
                        const SizedBox(width: 20),
                        _buildSocialIcon(FontAwesomeIcons.youtube, const Color(0xFFFF0000), "https://www.youtube.com/@asconbadagry9403"),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // Visit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => _launchURL("https://ascon.gov.ng"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          "VISIT OFFICIAL WEBSITE",
                          style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    
                    Text(
                      "ASCON Alumni App v2.0.0",
                      style: GoogleFonts.lato(color: Colors.grey[400], fontSize: 12),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER: Info Card ---
  Widget _buildInfoCard(BuildContext context, {required IconData icon, required String title, required String content}) {
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primaryColor, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.lato(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            textAlign: TextAlign.justify, 
            style: GoogleFonts.lato(
              fontSize: 14,
              height: 1.5,
              color: subTextColor,
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER: Contact Row ---
  Widget _buildContactRow(BuildContext context, IconData icon, String text, {VoidCallback? onTap}) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Icon(icon, color: const Color(0xFFD4AF37), size: 18),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center, 
              style: GoogleFonts.lato(
                fontSize: 14, 
                color: onTap != null ? Theme.of(context).primaryColor : textColor, 
                fontWeight: FontWeight.w500,
                decoration: onTap != null ? TextDecoration.underline : TextDecoration.none, 
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER: Social Icon ---
  Widget _buildSocialIcon(IconData icon, Color color, String url) {
    return InkWell(
      onTap: () => _launchURL(url),
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: FaIcon(icon, color: color, size: 22),
      ),
    );
  }
}