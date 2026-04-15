import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

// ✅ IMPORT RIVERPOD AND PROFILE VIEW MODEL
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/profile_view_model.dart';

import 'chat_screen.dart';
import 'call_screen.dart'; 
import '../widgets/full_screen_image.dart';

class CallLogDetailScreen extends ConsumerWidget {
  final String name;
  final String? avatar;
  final String? callerId;
  final List<Map<String, dynamic>> logs;

  const CallLogDetailScreen({
    super.key,
    required this.name,
    this.avatar,
    this.callerId,
    required this.logs,
  });

  // ✅ HELPER METHOD TO START EITHER VOICE OR VIDEO CALL
  void _startCall(BuildContext context, WidgetRef ref, bool isVideo) {
    if (callerId != null) {
      final userProfile = ref.read(profileProvider).userProfile;
      final currentUserName = userProfile?['fullName'] ?? "Alumni User";
      final currentUserAvatar = userProfile?['profilePicture'];

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            remoteId: callerId!,
            remoteName: name,
            remoteAvatar: avatar, 
            channelName: "call_${DateTime.now().millisecondsSinceEpoch}",
            isIncoming: false,
            isVideoCall: isVideo, // ✅ Correctly triggers Video or Voice
            currentUserName: currentUserName,      
            currentUserAvatar: currentUserAvatar,  
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) { 
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Call History", style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Theme.of(context).cardColor,
        iconTheme: IconThemeData(color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
      body: Column(
        children: [
          // HEADER: User Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Column(
              children: [
                _buildAvatar(context, avatar, name, 50),
                
                const SizedBox(height: 16),
                Text(
                  name,
                  style: GoogleFonts.lato(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                
                if (callerId != null) ...[
                  const SizedBox(height: 24),
                  
                  // ACTION BUTTONS (Voice, Video, Message)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0), // ✅ Widened to fit 3 buttons
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Button 1: Voice Call
                        Expanded(
                          child: _buildActionButton(
                            context, 
                            icon: Icons.call, 
                            label: "Voice", 
                            color: const Color(0xFF1B5E3A),
                            onTap: () => _startCall(context, ref, false),
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // ✅ NEW Button 2: Video Call
                        Expanded(
                          child: _buildActionButton(
                            context, 
                            icon: Icons.videocam, 
                            label: "Video", 
                            color: const Color(0xFF1B5E3A),
                            onTap: () => _startCall(context, ref, true),
                          ),
                        ),

                        const SizedBox(width: 12),
                        
                        // Button 3: Message
                        Expanded(
                          child: _buildActionButton(
                            context, 
                            icon: Icons.message_rounded, 
                            label: "Message", 
                            color: Colors.blue,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  receiverId: callerId!,
                                  receiverName: name,
                                  receiverProfilePic: avatar,
                                  isOnline: false,
                                  isGroup: false,
                                )
                              ));
                            },
                          ),
                        ),
                      ],
                    ),
                  )
                ]
              ],
            ),
          ),

          // HISTORY LIST
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              separatorBuilder: (c, i) => Divider(height: 1, indent: 50, color: Colors.grey.withOpacity(0.1)),
              itemBuilder: (context, index) {
                final log = logs[index];
                final String callType = log['callType'] ?? 'voice'; // ✅ Fetch Call Type

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      // ✅ Dynamic Icon (Voice vs Video)
                      Icon(_getIcon(log['type'], callType), color: _getIconColor(log['type']), size: 20),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ✅ Dynamic Label (Voice vs Video)
                            Text(
                              _getTypeLabel(log['type'], callType),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _formatFullDate(log['createdAt']),
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatTime(log['createdAt']),
                        style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: Colors.grey[600]),
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12), 
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center, 
        child: Column(
          children: [
            Icon(icon, color: color, size: 24), // ✅ Slightly smaller to prevent overflow
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)) // ✅ Adjusted font size
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, String? url, String? name, double radius) {
    Widget avatarWidget;
    
    if (url != null && url.isNotEmpty) {
      avatarWidget = CachedNetworkImage(
        imageUrl: url,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: radius, 
          backgroundImage: imageProvider
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey[200],
          child: Icon(Icons.person, size: radius, color: Colors.grey),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey[200],
          child: Text(
            (name ?? "?").substring(0, 1).toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: radius * 0.8, color: Colors.grey[600]),
          ),
        ),
      );
    } else {
      avatarWidget = CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[200],
        child: Text(
          (name ?? "?").substring(0, 1).toUpperCase(),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: radius * 0.8, color: Colors.grey[600]),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (url != null && url.isNotEmpty) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => FullScreenImage(
              imageUrl: url, 
              heroTag: "avatar_detail_${callerId ?? name}"
            )
          ));
        }
      },
      child: Hero(
        tag: "avatar_detail_${callerId ?? name}",
        child: avatarWidget,
      ),
    );
  }

  // ✅ UPDATED: Supports Video Call Icons
  IconData _getIcon(String type, String callType) {
    if (callType == 'video') {
      switch (type) {
        case 'missed': return Icons.missed_video_call;
        case 'dialed': return Icons.videocam_outlined;
        case 'received': return Icons.videocam;
        default: return Icons.videocam;
      }
    } else {
      switch (type) {
        case 'missed': return Icons.call_missed;
        case 'dialed': return Icons.call_made;
        case 'received': return Icons.call_received;
        default: return Icons.call;
      }
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'missed': return Colors.red;
      case 'dialed': return Colors.blue;
      case 'received': return Colors.green;
      default: return Colors.grey;
    }
  }

  // ✅ UPDATED: Supports Video Call Labels
  String _getTypeLabel(String type, String callType) {
    final bool isVideo = callType == 'video';
    switch (type) {
      case 'missed': return isVideo ? "Missed Video Call" : "Missed Call";
      case 'dialed': return isVideo ? "Outgoing Video Call" : "Outgoing Call";
      case 'received': return isVideo ? "Incoming Video Call" : "Incoming Call";
      default: return isVideo ? "Video Call" : "Call";
    }
  }

  String _formatFullDate(String? iso) {
    if (iso == null) return "";
    final date = DateTime.parse(iso).toLocal();
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatTime(String? iso) {
    if (iso == null) return "";
    final date = DateTime.parse(iso).toLocal();
    return DateFormat('h:mm a').format(date);
  }
}