import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:async'; 
import 'package:intl/intl.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import 'package:cached_network_image/cached_network_image.dart'; 

// ✅ IMPORT RIVERPOD & PROFILE VIEW MODEL
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/profile_view_model.dart'; 

import '../widgets/full_screen_image.dart'; 
import 'chat_screen.dart'; 
import 'call_screen.dart'; // ✅ Import Call Screen
import '../services/data_service.dart';
import '../services/socket_service.dart';
import '../utils/presence_formatter.dart'; 

// ✅ CHANGE TO ConsumerStatefulWidget
class AlumniDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> alumniData;

  const AlumniDetailScreen({super.key, required this.alumniData});

  @override
  ConsumerState<AlumniDetailScreen> createState() => _AlumniDetailScreenState();
}

// ✅ CHANGE TO ConsumerState
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
    _lastSeen = _currentAlumniData['lastSeen'];

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
         _profileExists = false; 
       });
       
       await showDialog(
         context: context,
         barrierDismissible: false,
         builder: (ctx) => AlertDialog(
           title: const Text("Profile Unavailable"),
           content: const Text("This user profile no longer exists."),
           actions: [
             TextButton(
               onPressed: () {
                 Navigator.pop(ctx); 
                 Navigator.pop(context); 
               },
               child: const Text("OK"),
             )
           ],
         ),
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
          _isOnline = data['isOnline'];
          if (!_isOnline) _lastSeen = data['lastSeen'];
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

  // ✅ FIXED: Using ref.read to get current user data
  void _startVoiceCall() {
    final String targetId = _currentAlumniData['userId'] ?? _currentAlumniData['_id'];
    final String fullName = _currentAlumniData['fullName'] ?? 'Alumni Member';
    final String? profilePic = _currentAlumniData['profilePicture']; 

    String uniqueChannel = "call_${DateTime.now().millisecondsSinceEpoch}";

    // ✅ Fetch current user details from profileProvider
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
          currentUserName: currentUserName,      // ✅ Correctly defined now
          currentUserAvatar: currentUserAvatar,  // ✅ Correctly defined now
        ),
      ),
    );
  }

  String _formatLastSeen(String? dateString) {
    if (dateString == null) return "Offline";
    final formatted = PresenceFormatter.format(dateString);
    if (formatted == "Just now" || formatted == "Active just now") return "Active just now";
    return "Last seen $formatted";
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
    final String bio = rawBio.trim().isNotEmpty 
        ? rawBio 
        : (_isLoadingFullProfile ? 'Loading biography...' : 'No biography provided.');

    final bool showPhone = _currentAlumniData['isPhoneVisible'] == true;
    final bool isMentor = _currentAlumniData['isOpenToMentorship'] == true;
    
    final String statusText = _isOnline ? "Active Now" : _formatLastSeen(_lastSeen);

    final String phone = _currentAlumniData['phoneNumber'] ?? '';
    final String linkedin = _currentAlumniData['linkedin'] ?? '';
    final String email = _currentAlumniData['email'] ?? '';
    final String year = _currentAlumniData['yearOfAttendance']?.toString() ?? 'Unknown';
    final String imageString = _currentAlumniData['profilePicture'] ?? '';
    
    final String zoomHeroTag = "zoom_profile_${_currentAlumniData['_id'] ?? DateTime.now().millisecondsSinceEpoch}";

    final String programme = (_currentAlumniData['programmeTitle'] != null && _currentAlumniData['programmeTitle'].toString().isNotEmpty) 
        ? _currentAlumniData['programmeTitle'] 
        : (_isLoadingFullProfile ? 'Loading...' : 'Not Specified');

    Widget buildMentorshipButton() {
      if (!isMentor || !_profileExists) return const SizedBox.shrink();

      if (_isLoadingFullProfile || _isLoadingStatus) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(12.0), 
            child: CircularProgressIndicator(strokeWidth: 2)
          )
        );
      }

      String label = "Request Mentorship";
      Color btnColor = Colors.amber[800]!;
      VoidCallback? action = _handleRequest;
      IconData icon = Icons.handshake_rounded;

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

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 10),
        child: ElevatedButton.icon(
          onPressed: action,
          icon: Icon(icon, color: Colors.white, size: 20),
          label: Text(label, style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: btnColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(vertical: 10),
            elevation: 2,
          ),
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
                              if (imageString.isNotEmpty && (imageString.startsWith('http') || imageString.length > 100)) {
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
                                child: _buildRobustAvatar(imageString, isDark),
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
                                  color: _isOnline ? Colors.green : Colors.grey[400],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusText, 
                                style: GoogleFonts.lato(
                                  color: _isOnline ? Colors.green[700] : Colors.grey[600],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 10),
                        
                        if (isMentor)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                          ),
                          child: Text(
                            "Class of $year",
                            style: GoogleFonts.lato(color: const Color(0xFFB8860B), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  buildMentorshipButton(),

                  const SizedBox(height: 10),

                  // ✅ ACTION BUTTONS
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

                        // ✅ NEW CALL BUTTON
                        _buildCircleAction(context, Icons.call, "Voice Call", Colors.purple[700]!, _startVoiceCall),

                        if (linkedin.isNotEmpty)
                          _buildCircleAction(context, Icons.link, "LinkedIn", Colors.blue[700]!, () => _launchURL(linkedin)),
                        
                        if (email.isNotEmpty)
                          _buildCircleAction(context, Icons.email, "Email", Colors.red[400]!, () => _launchURL("mailto:$email")),
                        
                        // Regular phone call (GSM)
                        if (showPhone && phone.isNotEmpty)
                          _buildCircleAction(context, Icons.phone_android, "Phone", Colors.green[600]!, () => _launchURL("tel:$phone")),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // --- 4. DETAILS CARDS ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // About Me Card
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
                                bio,
                                style: GoogleFonts.lato(
                                  fontSize: 14, 
                                  height: 1.6, 
                                  color: _isLoadingFullProfile ? Colors.grey : subTextColor,
                                  fontStyle: _isLoadingFullProfile ? FontStyle.italic : FontStyle.normal,
                                ),
                                textAlign: TextAlign.justify,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (job.isNotEmpty || org.isNotEmpty || industry.isNotEmpty) 
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
                                if (job.isNotEmpty) _buildDetailRow(Icons.badge_outlined, "Role", job, textColor),
                                if (job.isNotEmpty && org.isNotEmpty) const SizedBox(height: 8),
                                if (org.isNotEmpty) _buildDetailRow(Icons.apartment_rounded, "Organization", org, textColor),
                                if ((job.isNotEmpty || org.isNotEmpty) && industry.isNotEmpty) const SizedBox(height: 8),
                                if (industry.isNotEmpty) _buildDetailRow(Icons.category_outlined, "Industry", industry, textColor),
                              ],
                            ),
                          ),

                        // Programme Card
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

  Widget _buildRobustAvatar(String imageString, bool isDark) {
    if (imageString.isEmpty) {
      return _buildPlaceholder(isDark);
    }

    if (imageString.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageString,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: 45,
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => _buildPlaceholder(isDark),
        errorWidget: (context, url, error) => _buildPlaceholder(isDark),
      );
    }

    try {
      return CircleAvatar(
        radius: 45,
        backgroundImage: MemoryImage(base64Decode(imageString)),
      );
    } catch (e) {
      return _buildPlaceholder(isDark);
    }
  }

  Widget _buildPlaceholder(bool isDark) {
    return CircleAvatar(
      radius: 45,
      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
      child: Icon(Icons.person, size: 45, color: isDark ? Colors.grey[500] : Colors.grey),
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