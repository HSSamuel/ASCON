import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../viewmodels/updates_view_model.dart';
import '../../../viewmodels/profile_view_model.dart';
import '../../../screens/alumni_detail_screen.dart';

class CommentsSheet extends ConsumerStatefulWidget {
  final String postId;

  const CommentsSheet({super.key, required this.postId});

  static void show(BuildContext context, String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => CommentsSheet(postId: postId),
    );
  }

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  List<dynamic> _localComments = [];
  bool _hasFetched = false;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    final data = await ref.read(updatesProvider.notifier).fetchComments(widget.postId);
    if (mounted) {
      setState(() {
        _localComments = data;
        _hasFetched = true;
      });
    }
  }

  void _viewProfile(Map<String, dynamic> user) {
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

  void _postComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final currentUser = ref.read(profileProvider).userProfile;
    final optimisticComment = {
      'text': text,
      'createdAt': DateTime.now().toIso8601String(),
      'author': {
        'fullName': currentUser?['fullName'] ?? 'Me',
        'profilePicture': currentUser?['profilePicture'],
        'isOnline': true,
      }
    };

    setState(() {
      _localComments.insert(0, optimisticComment);
    });
    _commentController.clear();
    
    if (!kIsWeb) Vibration.hasVibrator().then((hasVib) { if (hasVib ?? false) Vibration.vibrate(duration: 15); });
    ref.read(updatesProvider.notifier).postComment(widget.postId, text);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bubbleColor = isDark ? Colors.grey[800] : Colors.grey[100];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Text("Comments", style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
            const Divider(),
            
            Expanded(
              child: !_hasFetched 
                  ? const Center(child: CircularProgressIndicator())
                  : _localComments.isEmpty 
                      ? Center(child: Text("No comments yet. Be the first!", style: GoogleFonts.lato(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: _localComments.length,
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (context, index) {
                            final c = _localComments[index];
                            final author = c['author'] ?? {};
                            final authorImg = author['profilePicture'];
                            final time = timeago.format(DateTime.tryParse(c['createdAt'] ?? "") ?? DateTime.now());
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () => _viewProfile(author),
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.grey[200],
                                      backgroundImage: (authorImg != null && authorImg.toString().startsWith('http') && !authorImg.toString().contains('profile/picture/')) ? CachedNetworkImageProvider(authorImg) : null,
                                      child: (authorImg == null || authorImg.toString().contains('profile/picture/')) ? const Icon(Icons.person, size: 16, color: Colors.grey) : null,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.circular(12)),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              GestureDetector(
                                                onTap: () => _viewProfile(author),
                                                child: Text(author['fullName'] ?? "User", style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 13, color: textColor))
                                              ),
                                              Text(time, style: GoogleFonts.lato(fontSize: 10, color: Colors.grey)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Linkify(
                                            onOpen: (link) async {
                                              if (await canLaunchUrl(Uri.parse(link.url))) {
                                                await launchUrl(Uri.parse(link.url));
                                              }
                                            },
                                            text: c['text'] ?? "",
                                            style: GoogleFonts.lato(fontSize: 14, color: textColor),
                                            linkStyle: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2)))),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: TextStyle(color: textColor),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: "Add a comment...",
                        hintStyle: GoogleFonts.lato(fontSize: 14, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        filled: true,
                        fillColor: bubbleColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFFD4AF37),
                    radius: 22,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, size: 20, color: Colors.white), 
                      onPressed: _postComment,
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}