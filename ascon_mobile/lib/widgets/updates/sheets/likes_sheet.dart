import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../viewmodels/updates_view_model.dart';
import '../../../screens/alumni_detail_screen.dart';

class LikesSheet extends ConsumerWidget {
  final String postId;

  const LikesSheet({super.key, required this.postId});

  static void show(BuildContext context, String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => LikesSheet(postId: postId),
    );
  }

  void _viewProfile(BuildContext context, Map<String, dynamic> user) {
    final userId = user['_id'] ?? user['userId'] ?? user['id'];
    if (userId == null) return;
    
    final alumniData = {
      ...user,
      'userId': userId,
      '_id': userId,
      'fullName': user['fullName'] ?? "User",
    };
    Navigator.push(context, MaterialPageRoute(builder: (_) => AlumniDetailScreen(alumniData: alumniData)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return FutureBuilder<List<dynamic>>(
          future: ref.read(updatesProvider.notifier).fetchLikers(postId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final likers = snapshot.data!;

            return Column(
              children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                Text("Likes", style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                const Divider(),
                Expanded(
                  child: likers.isEmpty 
                    ? Center(child: Text("No likes yet", style: GoogleFonts.lato(color: Colors.grey)))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: likers.length,
                        itemBuilder: (context, index) {
                          final user = likers[index];
                          final bool isOnline = user['isOnline'] == true;

                          return ListTile(
                            onTap: () => _viewProfile(context, user),
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundImage: (user['profilePicture'] != null && user['profilePicture'].toString().startsWith('http') && !user['profilePicture'].toString().contains('profile/picture/')) 
                                      ? CachedNetworkImageProvider(user['profilePicture']) 
                                      : null,
                                  child: (user['profilePicture'] == null || user['profilePicture'].toString().contains('profile/picture/')) ? const Icon(Icons.person) : null,
                                ),
                                if (isOnline)
                                  Positioned(
                                    right: 0, bottom: 0,
                                    child: Container(
                                      width: 12, height: 12,
                                      decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2)),
                                    ),
                                  )
                              ],
                            ),
                            title: Text(user['fullName'] ?? "Unknown", style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
                            subtitle: Text(user['jobTitle'] ?? "Member", maxLines: 1, overflow: TextOverflow.ellipsis),
                          );
                        },
                      ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}