import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../services/data_service.dart';

class ChapterCard extends StatefulWidget {
  const ChapterCard({super.key});

  @override
  State<ChapterCard> createState() => _ChapterCardState();
}

class _ChapterCardState extends State<ChapterCard> {
  List<dynamic> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    try {
      final groups = await DataService().fetchMyGroups();
      if (mounted) {
        setState(() {
          _groups = groups;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToChat(BuildContext context, Map<String, dynamic> group) {
    context.push('/chat_detail', extra: {
      'conversationId': null,
      'receiverId': group['_id'],       
      'receiverName': group['name'],
      'receiverProfilePic': group['icon'],
      'isOnline': false,
      'lastSeen': null,
      'isGroup': true,        
      'groupId': group['_id'],          
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3F4F6);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final iconBgColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;

    if (_groups.isEmpty) {
       return Container(
         margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
         padding: const EdgeInsets.all(16),
         decoration: BoxDecoration(
           color: isDark ? Colors.grey[900] : Colors.grey[100], 
           borderRadius: BorderRadius.circular(16)
         ),
         child: Text(
           "You are not in any Chapters yet.", 
           style: TextStyle(color: subTextColor) 
         ),
       );
    }

    final group = _groups.first;
    final name = group['name'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: cardColor,
        // ✅ FIXED: Removed 'borderRadius' here because 'shape' is used below.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.withOpacity(0.2)),
        ),
        child: InkWell(
          onTap: () => _navigateToChat(context, group),
          splashColor: Colors.teal.withOpacity(0.1),
          highlightColor: Colors.teal.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle
                  ),
                  child: const Icon(Icons.groups, color: Colors.teal, size: 24),
                ),
                const SizedBox(width: 12),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "MY COMMUNITY", 
                        style: GoogleFonts.lato(fontSize: 9, fontWeight: FontWeight.w900, color: subTextColor)
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name, 
                        style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2)
                      )
                    ]
                  ),
                  child: const Row(
                    children: [
                      Text("Chat", style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 8, color: Colors.white70)
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}