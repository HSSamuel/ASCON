import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async'; 
import 'package:url_launcher/url_launcher.dart'; 

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/profile_view_model.dart'; 

import '../widgets/full_screen_image.dart'; 
import '../widgets/robust_avatar.dart'; // ✅ NEW IMPORT
import 'chat_screen.dart'; 
import 'call_screen.dart'; 
import '../services/data_service.dart';
import '../services/socket_service.dart';
import '../utils/presence_formatter.dart'; 

class AlumniDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> alumniData;

  const AlumniDetailScreen({super.key, required this.alumniData});

  @override
  ConsumerState<AlumniDetailScreen> createState() => _AlumniDetailScreenState();
}

class _AlumniDetailScreenState extends ConsumerState<AlumniDetailScreen> {
  final DataService _dataService = DataService();
  
  late Map<String, dynamic> _currentAlumniData;
  
  bool _isLoadingFullProfile = true; 
  bool _profileExists = true; 

  String _mentorshipStatus = "Loading"; 
  String? _requestId; 
  bool _isLoadingStatus = false;

  late bool _isOnline;
  String? _lastSeen;
  
  StreamSubscription? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _currentAlumniData = Map<String, dynamic>.from(widget.alumniData);

    _isOnline = _currentAlumniData['isOnline'] == true;
    _lastSeen = _currentAlumniData['lastSeen']?.toString();

    _fetchFullDetails();

    if (_currentAlumniData['isOpenToMentorship'] == true) {
      _checkStatus();
    } else {
      _mentorshipStatus = "None"; 
    }

    _setupSocketListeners();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel(); 
    super.dispose();
  }

  Future<void> _fetchFullDetails() async {
    final String lookupId = _currentAlumniData['userId'] ?? _currentAlumniData['_id'];
    
    final fullData = await _dataService.fetchAlumniById(lookupId);
    
    if (!mounted) return;

    if (fullData == null) {
       setState(() {
         _isLoadingFullProfile = false;
       });
       
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text("Could not sync latest profile data. Showing cached version."))
       );
       return;
    }

    setState(() {
      _currentAlumniData.addAll(fullData);
      _isLoadingFullProfile = false;
      _profileExists = true;
    });
  }

  void _setupSocketListeners() {
    final socket = SocketService().socket;
    if (socket == null) return;
    
    final targetUserId = _currentAlumniData['userId'] ?? _currentAlumniData['_id'];

    SocketService().checkUserStatus(targetUserId);

    _statusSubscription = SocketService().userStatusStream.listen((data) {
      if (!mounted) return;
      if (data['userId'] == targetUserId) {
        setState(() {
          _isOnline = data['isOnline'] == true;
          if (data['lastSeen'] != null) {
            _lastSeen = data['lastSeen'].toString();
          }
        });
      }
    });
  }

  Future<void> _checkStatus() async {
    if (_mentorshipStatus == "Loading") setState(() => _isLoadingStatus = true);
    
    final targetId = _currentAlumniData['userId'] ?? _currentAlumniData['_id'];
    
    final result = await _dataService.getMentorshipStatusFull(targetId);
    if (mounted) {
      setState(() {
        _mentorshipStatus = result['status'];
        _requestId = result['requestId']; 
        _isLoadingStatus = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isLoadingFullProfile = true); 
    
    await _fetchFullDetails();

    if (_currentAlumniData['isOpenToMentorship'] == true) {
      await _checkStatus();
    }

    final targetUserId = _currentAlumniData['userId'] ?? _currentAlumniData['_id'];
    SocketService().checkUserStatus(targetUserId);
  }

  Future<void> _handleRequest() async {
    if (!_profileExists) return;

    TextEditingController pitchCtrl = TextEditingController();
    
    final bool? send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Request Mentorship", style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Write a short note introducing yourself:"),
            const SizedBox(height: 10),
            TextField(
              controller: pitchCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Hi, I admire your work in...",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white),
            child: const Text("Send Request"),
          ),
        ],
      ),
    );

    if (send == true) {
      setState(() => _isLoadingStatus = true);
      
      final String targetId = _currentAlumniData['userId'] ?? _currentAlumniData['_id'];
      
      final response = await _dataService.sendMentorshipRequest(targetId, pitchCtrl.text);
      final bool success = response['success'] == true;
      final String message = response['message'] ?? "Failed to send request.";

      if (mounted) {
        await _checkStatus();
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message), 
          backgroundColor: success ? Colors.green : Colors.red,
        ));
      }
    }
  }

  Future<void> _launchURL(String urlString) async {
    if (urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch $url');
      }
    } catch (e) {
      debugPrint("Error launching URL: $e");
    }
  }

  void _startVoiceCall() {
    final String targetId = _currentAlumniData['userId'] ?? _currentAlumniData['_id'];
    final String fullName = _currentAlumniData['fullName'] ?? 'Alumni Member';
    final String? profilePic = _currentAlumniData['profilePicture']; 

    String uniqueChannel = "call_${DateTime.now().millisecondsSinceEpoch}";

    final userProfile = ref.read(profileProvider).userProfile;
    final String currentUserName = userProfile?['fullName'] ?? "Alumni User";
    final String? currentUserAvatar = userProfile?['profilePicture'];

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          remoteName: fullName,
          remoteId: targetId,
          channelName: uniqueChannel,
          remoteAvatar: profilePic,
          isIncoming: false,
          currentUserName: currentUserName,      
          currentUserAvatar: currentUserAvatar,  
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final scaffoldBg = isDark ? const Color(0xFF121212) : Colors.grey[50];
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryColor = const Color(0xFF1B5E3A);
    
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[700];

    final String fullName = _currentAlumniData['fullName'] ?? 'Unknown Alumnus';
    final String job = _currentAlumniData['jobTitle'] ?? '';
    final String org = _currentAlumniData['organization'] ?? '';
    final String industry = _currentAlumniData['industry'] ?? '';
    
    String rawBio = _currentAlumniData['bio'] ?? '';
    final bool hasBio = rawBio.trim().isNotEmpty;
    final String bioText = hasBio ? rawBio : (_isLoadingFullProfile ? 'Loading biography...' : 'No biography provided.');

    final bool showPhone = _currentAlumniData['isPhoneVisible'] == true;
    final bool isMentor = _currentAlumniData['isOpenToMentorship'] == true;
    
    final String statusText = PresenceFormatter.getStatusText(isOnline: _isOnline, lastSeen: _lastSeen);

    final String phone = _currentAlumniData['phoneNumber'] ?? '';
    final String linkedin = _currentAlumniData['linkedin'] ?? '';
    final String email = _currentAlumniData['email'] ?? '';
    
    final String rawYear = _currentAlumniData['yearOfAttendance']?.toString() ?? '';
    final bool isGeneralYear = rawYear.trim().isEmpty || rawYear == 'null' || rawYear == 'Unknown' || rawYear == 'Others' || rawYear == 'General';
    final String yearBadgeText = isGeneralYear ? "General Alumni" : "Class of $rawYear";
    
    final String imageString = _currentAlumniData['profilePicture'] ?? '';
    
    final String zoomHeroTag = "zoom_profile_${_currentAlumniData['_id'] ?? DateTime.now().millisecondsSinceEpoch}";

    final String programme = (_currentAlumniData['programmeTitle'] != null && _currentAlumniData['programmeTitle'].toString().isNotEmpty) 
        ? _currentAlumniData['programmeTitle'] 
        : (_isLoadingFullProfile ? 'Loading...' : 'Not Specified');

    Widget buildMentorshipButton() {
      if (!isMentor || !_profileExists) return const SizedBox.shrink();

      String label = "Request Mentorship";
      Color btnColor = Colors.amber[800]!;
      VoidCallback? action = _handleRequest;
      IconData icon = Icons.handshake_rounded;
      
      final bool isCurrentlyLoading = _isLoadingFullProfile || _isLoadingStatus;

      if (!isCurrentlyLoading) {
        if (_mentorshipStatus == "Pending") {
          label = "Withdraw Request"; 
          btnColor = Colors.orange[800]!;
          icon = Icons.cancel_outlined;
          
          action = () async {
             final confirm = await showDialog(
               context: context, 
               builder: (c) => AlertDialog(
                 title: const Text("Withdraw Request?"),
                 content: const Text("Are you sure you want to cancel this mentorship request?"),
                 actions: [
                   TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("No")),
                   TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Yes", style: TextStyle(color: Colors.red))),
                 ],
               )
             );

             if (confirm == true && _requestId != null) {
               setState(() => _isLoadingStatus = true);
               final success = await _dataService.deleteMentorshipInteraction(_requestId!, 'cancel');
               if (mounted) {
                 await _checkStatus(); 
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                   content: Text(success ? "Request Withdrawn" : "Failed to withdraw"),
                   backgroundColor: success ? Colors.grey : Colors.red,
                 ));
               }
             }
          };
        } else if (_mentorshipStatus == "Accepted") {
          label = "Message Mentor";
          btnColor = Colors.green[700]!;
          icon = Icons.chat;
          action = () {
             final targetId = _currentAlumniData['userId'] ?? _currentAlumniData['_id'];
             Navigator.of(context, rootNavigator: true).push(
               MaterialPageRoute(builder: (_) => ChatScreen(
                receiverId: targetId,
                receiverName: fullName,
                receiverProfilePic: imageString,
                isOnline: _isOnline, 
                lastSeen: _lastSeen, 
             )));
          };
        } else if (_mentorshipStatus == "Rejected") {
          label = "Request Declined";
          btnColor = Colors.red[300]!;
          action = null;
          icon = Icons.block;
        }
      } else {
        btnColor = Colors.amber[800]!.withOpacity(0.5);
        action = null; 
      }

      return ElevatedButton.icon(
        onPressed: action,
        icon: isCurrentlyLoading 
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon, color: Colors.white, size: 16),
        label: Text(isCurrentlyLoading ? "Checking..." : label, style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: btnColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          minimumSize: const Size(0, 34),
          elevation: isCurrentlyLoading ? 0 : 1,
        ),
      );
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _onRefresh,
            color: primaryColor,
            backgroundColor: isDark ? Colors.grey[800] : Colors.white,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  SizedBox(
                    height: 180, 
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 140, 
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
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              final cleanImg = imageString.toLowerCase().trim();
                              if (cleanImg.isNotEmpty && 
                                  !cleanImg.contains('profile/picture') && 
                                  !cleanImg.contains('default-user') &&
                                  (cleanImg.startsWith('http') || cleanImg.length > 100)) {
                                Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute(
                                    builder: (_) => FullScreenImage(
                                      imageUrl: imageString,
                                      heroTag: zoomHeroTag,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Hero(
                              tag: zoomHeroTag,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: cardColor, width: 4),
                                  boxShadow: [
                                    if (!isDark)
                                      BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 5))
                                  ],
                                ),
                                // ✅ UPDATED: Call RobustAvatar directly
                                child: RobustAvatar(imageUrl: imageString, radius: 45, isDark: isDark),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10), 

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Text(
                          fullName,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lato(
                            fontSize: 22, 
                            fontWeight: FontWeight.bold, 
                            color: textColor 
                          ),
                        ),
                        const SizedBox(height: 4),
                        
                        if (job.isNotEmpty || org.isNotEmpty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.work_outline, size: 14, color: subTextColor),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  "$job${(job.isNotEmpty && org.isNotEmpty) ? ' at ' : ''}$org",
                                  style: GoogleFonts.lato(fontSize: 13, color: subTextColor, fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  color: PresenceFormatter.getStatusColor(_isOnline), 
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusText, 
                                style: GoogleFonts.lato(
                                  color: PresenceFormatter.getStatusColor(_isOnline), 
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // 1. "Class Of" Badge moved to the top
                        Container(
                          margin: const EdgeInsets.only(bottom: 12), // Added margin to space it from the mentorship block
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                          ),
                          child: Text(
                            yearBadgeText,
                            style: GoogleFonts.lato(color: const Color(0xFFB8860B), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),

                        // 2. Mentorship Section moved below
                        if (isMentor)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 10,
                              children: [
                                Container(
                                  height: 34,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.amber.shade600),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.stars_rounded, color: Colors.amber.shade700, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Open to Mentoring",
                                        style: GoogleFonts.lato(color: Colors.amber.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                buildMentorshipButton(),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCircleAction(context, Icons.chat_bubble_outline, "Message", primaryColor, () {
                          final targetId = _currentAlumniData['userId'] ?? _currentAlumniData['_id'];
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                receiverId: targetId,
                                receiverName: fullName,
                                receiverProfilePic: imageString,
                                isOnline: _isOnline, 
                                lastSeen: _lastSeen, 
                              ),
                            ),
                          );
                        }),

                        _buildCircleAction(context, Icons.call, "Voice Call", Colors.purple[700]!, _startVoiceCall),

                        if (linkedin.isNotEmpty)
                          _buildCircleAction(context, Icons.link, "LinkedIn", Colors.blue[700]!, () => _launchURL(linkedin)),
                        
                        if (email.isNotEmpty)
                          _buildCircleAction(context, Icons.email, "Email", Colors.red[400]!, () => _launchURL("mailto:$email")),
                        
                        if (showPhone && phone.isNotEmpty)
                          _buildCircleAction(context, Icons.phone_android, "Phone", Colors.green[600]!, () => _launchURL("tel:$phone")),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.person_outline_rounded, size: 20, color: primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    "About Me",
                                    style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor),
                                  ),
                                  const Spacer(),
                                  if (_isLoadingFullProfile)
                                    SizedBox(
                                      width: 14, height: 14, 
                                      child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor.withOpacity(0.5))
                                    )
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                bioText,
                                style: GoogleFonts.lato(
                                  fontSize: 14, 
                                  height: 1.6, 
                                  color: _isLoadingFullProfile && !hasBio ? Colors.grey : subTextColor,
                                  fontStyle: _isLoadingFullProfile || !hasBio ? FontStyle.italic : FontStyle.normal,
                                ),
                                textAlign: TextAlign.justify,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (job.isNotEmpty || org.isNotEmpty || industry.isNotEmpty || _isLoadingFullProfile) 
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.business_center_outlined, size: 20, color: primaryColor),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Professional Profile",
                                      style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (_isLoadingFullProfile && job.isEmpty && org.isEmpty && industry.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 4.0),
                                    child: Text("Loading professional details...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13)),
                                  )
                                else ...[
                                  if (job.isNotEmpty) _buildDetailRow(Icons.badge_outlined, "Role", job, textColor),
                                  if (job.isNotEmpty && org.isNotEmpty) const SizedBox(height: 8),
                                  if (org.isNotEmpty) _buildDetailRow(Icons.apartment_rounded, "Organization", org, textColor),
                                  if ((job.isNotEmpty || org.isNotEmpty) && industry.isNotEmpty) const SizedBox(height: 8),
                                  if (industry.isNotEmpty) _buildDetailRow(Icons.category_outlined, "Industry", industry, textColor),
                                ]
                              ],
                            ),
                          ),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              if (!isDark)
                                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.school_outlined, color: primaryColor, size: 22),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Programme Attended",
                                      style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w600, color: subTextColor),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      programme,
                                      style: GoogleFonts.lato(
                                        fontSize: 14, 
                                        fontWeight: FontWeight.bold, 
                                        color: (programme == 'Not Specified' || _isLoadingFullProfile) ? Colors.grey : textColor,
                                        fontStyle: _isLoadingFullProfile ? FontStyle.italic : FontStyle.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          Positioned(
            top: 40, 
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2), 
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: Colors.grey[500]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.lato(fontSize: 11, color: Colors.grey[500]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCircleAction(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white; 
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.3)),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3))
                ],
              ),
              child: Icon(icon, color: color, size: 22),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}