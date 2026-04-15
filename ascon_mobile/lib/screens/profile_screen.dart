import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; 
import 'package:google_fonts/google_fonts.dart'; 

import '../viewmodels/profile_view_model.dart';
import '../utils/presence_formatter.dart'; 
import '../widgets/shimmer_utils.dart'; 
import '../widgets/full_screen_image.dart'; 

import 'edit_profile_screen.dart';
import 'document_request_screen.dart'; 
import 'mentorship_dashboard_screen.dart'; 

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userName; 
  const ProfileScreen({super.key, this.userName}); 

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // ✅ NEW: Scroll Controller and State to track scroll position
  late ScrollController _scrollController;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  // ✅ NEW: Listener function to update UI when scrolled past header
  void _onScroll() {
    // 120px is roughly where the green header ends behind the AppBar
    if (_scrollController.offset > 120 && !_isScrolled) {
      setState(() {
        _isScrolled = true;
      });
    } else if (_scrollController.offset <= 120 && _isScrolled) {
      setState(() {
        _isScrolled = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> _logout() async {
    final dialogBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text("Logout", style: TextStyle(color: textColor)),
        content: Text("Are you sure you want to logout?", style: TextStyle(color: textColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Logout", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await ref.read(profileProvider.notifier).logout();
      if (!mounted) return;
      context.go('/login');
    }
  }

  ImageProvider? getProfileImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    if (imagePath.startsWith('http')) return NetworkImage(imagePath);
    try { return MemoryImage(base64Decode(imagePath)); } catch (e) { return null; }
  }

  String _formatLastSeen(String? dateString) {
    if (dateString == null) return "Offline";
    final formatted = PresenceFormatter.format(dateString);
    if (formatted == "Just now" || formatted == "Active just now") return "Active just now";
    return "Last seen $formatted";
  }

  String _formatPhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) return 'Add Phone Number';
    return phone; 
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final userProfile = profileState.userProfile;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    if (profileState.isLoading) return Scaffold(backgroundColor: scaffoldBg, body: const ProfileSkeleton());

    final String fullName = userProfile?['fullName'] ?? widget.userName ?? "Alumni";
    final String jobTitle = userProfile?['jobTitle'] ?? '';
    final String org = userProfile?['organization'] ?? '';
    final String industry = userProfile?['industry'] ?? '';

    final String programme = (userProfile?['programmeTitle']?.toString().isNotEmpty ?? false)
        ? userProfile!['programmeTitle'] : 'Add Programme';
    final String year = userProfile?['yearOfAttendance']?.toString() ?? 'N/A';
    final String email = userProfile?['email'] ?? 'No Email';
    final String phone = _formatPhoneNumber(userProfile?['phoneNumber']);
    final String bio = userProfile?['bio'] ?? '';
    final String statusText = profileState.isOnline ? "Active Now" : _formatLastSeen(profileState.lastSeen);
    
    final String? profilePicString = userProfile?['profilePicture'];

    return Scaffold(
      backgroundColor: scaffoldBg,
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        // ✅ UPDATED: Fade in a background color for the AppBar to keep it clean when scrolled
        backgroundColor: _isScrolled ? scaffoldBg.withOpacity(0.95) : Colors.transparent,
        elevation: _isScrolled ? 1 : 0,
        actions: [
          IconButton(
            // ✅ UPDATED: Dynamic Icon that turns Black (or White in Dark Mode) and gets bolder
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                Icons.logout_rounded, // Rounded makes it naturally slightly bolder
                key: ValueKey<bool>(_isScrolled),
                color: _isScrolled ? (isDark ? Colors.white : Colors.black87) : Colors.white,
                size: _isScrolled ? 28 : 24, // Enlarge it slightly to make it pop more
                shadows: !_isScrolled 
                    ? [const Shadow(color: Colors.black26, blurRadius: 4)] // Helps visibility on the green gradient
                    : null, 
              ),
            ),
            tooltip: "Logout",
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(profileProvider.notifier).loadProfile(), 
        color: primaryColor,
        child: SingleChildScrollView(
          controller: _scrollController, // ✅ ADDED: Attached the scroll controller
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // --- HEADER SECTION ---
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1B5E3A), Color(0xFF2E8B57)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                    ),
                  ),
                  Positioned(
                    top: 90, 
                    child: Text("My Profile", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  Positioned(
                    top: 140, 
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 100, height: 100,
                          child: CircularProgressIndicator(
                            value: profileState.completionPercent,
                            strokeWidth: 3,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            color: Colors.amber, 
                          ),
                        ),
                        
                        GestureDetector(
                          onTap: () {
                            if (profilePicString != null && profilePicString.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullScreenImage(
                                    imageUrl: profilePicString,
                                    heroTag: 'my_profile_pic', 
                                  ),
                                ),
                              );
                            }
                          },
                          child: Hero(
                            tag: 'my_profile_pic',
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: cardColor, width: 4),
                              ),
                              child: CircleAvatar(
                                radius: 45,
                                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                                backgroundImage: getProfileImage(profilePicString),
                                child: getProfileImage(profilePicString) == null
                                    ? Icon(Icons.person, size: 60, color: Colors.grey[400])
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 60), 
              
              // --- NAME & BADGES ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16), 
                child: Column(
                  children: [
                    Text(fullName, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 4), 
                    if (jobTitle.isNotEmpty || org.isNotEmpty)
                      Text("$jobTitle ${org.isNotEmpty ? 'at $org' : ''}", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: subTextColor, fontWeight: FontWeight.w500)),
                    
                    const SizedBox(height: 8),

                    // Presence
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: profileState.isOnline ? Colors.green : Colors.grey[400], shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusText, 
                          style: TextStyle(color: profileState.isOnline ? Colors.green[700] : Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12), 

                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8, runSpacing: 8,
                      children: [
                        _buildBadge(Icons.school, programme, isPlaceholder: programme == 'Add Programme', context: context),
                        _buildBadge(Icons.calendar_today, "Class of $year", isPlaceholder: year == 'N/A', context: context),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25), 

              // --- ABOUT ME ---
              if (bio.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("About Me", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor)),
                      const SizedBox(height: 8),
                      Text(bio, textAlign: TextAlign.justify, style: TextStyle(fontSize: 14, color: textColor, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // CAREER TIMELINE
              if (jobTitle.isNotEmpty || org.isNotEmpty || industry.isNotEmpty) 
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.timeline, size: 20, color: primaryColor),
                          const SizedBox(width: 8),
                          Text("Career Journey", style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      _buildTimelineItem(
                        title: jobTitle.isNotEmpty ? jobTitle : "Alumni",
                        subtitle: org.isNotEmpty ? org : "ASCON",
                        date: "Present",
                        isFirst: true,
                        isLast: false,
                        isActive: true,
                        lineColor: primaryColor,
                      ),
                      
                      _buildTimelineItem(
                        title: "Student",
                        subtitle: programme,
                        date: year,
                        isFirst: false,
                        isLast: true,
                        isActive: false,
                        lineColor: primaryColor,
                      ),
                    ],
                  ),
                ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 45, 
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen(userData: userProfile ?? {})));
                      if (result == true) ref.read(profileProvider.notifier).loadProfile(); 
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text("Edit Details", style: TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20), 

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16), 
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), 
                decoration: BoxDecoration(
                  color: cardColor, 
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Contact Information", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor)),
                    const SizedBox(height: 12),
                    _buildContactRow(Icons.email_outlined, "Email", email, context),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: Theme.of(context).dividerColor)),
                    _buildContactRow(Icons.phone_outlined, "Phone", phone, context), 
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem({
    required String title,
    required String subtitle,
    required String date,
    required bool isFirst,
    required bool isLast,
    required bool isActive,
    required Color lineColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            date, 
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, color: isActive ? lineColor : Colors.grey, fontWeight: FontWeight.bold)
          ),
        ),
        const SizedBox(width: 12),
        Column(
          children: [
            Container(width: 2, height: 10, color: isFirst ? Colors.transparent : Colors.grey[300]),
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: isActive ? lineColor : Colors.grey[300],
                shape: BoxShape.circle,
                border: isActive ? Border.all(color: Colors.white, width: 2) : null
              ),
            ),
            Container(width: 2, height: 40, color: isLast ? Colors.transparent : Colors.grey[300]),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6), 
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 20),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildBadge(IconData icon, String text, {required bool isPlaceholder, required BuildContext context}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isPlaceholder 
            ? (isDark ? Colors.orange[900]!.withOpacity(0.3) : Colors.orange[50]) 
            : primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPlaceholder 
              ? (isDark ? Colors.orange[700]! : Colors.orange.withOpacity(0.3)) 
              : primaryColor.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isPlaceholder ? Colors.orange[700] : primaryColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text, 
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isPlaceholder ? Colors.orange[700] : primaryColor), 
              overflow: TextOverflow.ellipsis
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconBg = isDark ? Colors.grey[800] : Colors.grey[50];
    final labelColor = Theme.of(context).textTheme.bodyMedium?.color;
    final valueColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8), 
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.grey[600], size: 18), 
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: labelColor)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: valueColor)),
            ],
          ),
        ),
      ],
    );
  }
}