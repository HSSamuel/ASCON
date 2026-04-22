import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../viewmodels/updates_view_model.dart';
import '../../screens/alumni_detail_screen.dart';
import 'post_image_gallery.dart';
import 'sheets/comments_sheet.dart';
import 'sheets/likes_sheet.dart';

class PostCard extends ConsumerWidget {
  final Map<String, dynamic> post;
  final bool isAdmin;
  final String? myId;

  const PostCard({super.key, required this.post, required this.isAdmin, this.myId});

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

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref, String postId, String currentText) async {
    final editCtrl = TextEditingController(text: currentText);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Update"),
        content: TextField(controller: editCtrl, maxLines: 5, minLines: 1, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, editCtrl.text.trim()), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white), child: const Text("Save")),
        ],
      ),
    );

    if (newText != null && newText.isNotEmpty && newText != currentText) {
      ref.read(updatesProvider.notifier).editPost(postId, newText);
    }
  }

  Widget _buildLinkCard(String url, bool isDark) {
    IconData icon = Icons.link;
    String title = "External Link";
    String domain = Uri.tryParse(url)?.host ?? "website";

    if (url.contains('drive.google.com')) {
      icon = Icons.add_to_drive;
      title = "Google Drive Document";
    } else if (url.contains('youtube.com') || url.contains('youtu.be')) {
      icon = Icons.play_circle_fill;
      title = "YouTube Video";
    }

    return InkWell(
      onTap: () async {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.blue.withOpacity(0.05),
          border: Border.all(color: isDark ? Colors.grey[700]! : Colors.blue.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: Colors.blue, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(domain, style: GoogleFonts.lato(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(updatesProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    final author = post['author'] ?? {};
    final String timeAgo = timeago.format(DateTime.tryParse(post['createdAt'] ?? "") ?? DateTime.now());
    final bool isMyPost = (myId != null && (post['authorId'] ?? '').toString() == myId);
    final bool canDelete = isAdmin || isMyPost;

    List<String> images = [];
    if (post['mediaUrls'] != null && post['mediaUrls'] is List && post['mediaUrls'].isNotEmpty) {
      images = List<String>.from(post['mediaUrls']);
    } else if (post['mediaUrl'] != null && post['mediaUrl'].toString().startsWith('http')) {
      images = [post['mediaUrl']];
    }

    return Container(
      color: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _viewProfile(context, author),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: (author['profilePicture'] != null && author['profilePicture'].toString().startsWith('http') && !author['profilePicture'].toString().contains('profile/picture/'))
                        ? CachedNetworkImageProvider(author['profilePicture'])
                        : null,
                    child: (author['profilePicture'] == null || author['profilePicture'].toString().contains('profile/picture/')) ? Icon(Icons.person, size: 16, color: Colors.grey[400]) : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: GestureDetector(
                              onTap: () => _viewProfile(context, author),
                              child: Text(author['fullName'] ?? 'Alumni Member', style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 13, color: textColor), overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text("• $timeAgo", style: GoogleFonts.lato(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      if (author['jobTitle'] != null)
                        Text(author['jobTitle'], style: GoogleFonts.lato(color: subTextColor, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (canDelete || isMyPost)
                  SizedBox(
                    width: 24, height: 24,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.more_horiz, color: subTextColor, size: 18),
                      onSelected: (val) {
                        if (val == 'edit') _showEditDialog(context, ref, post['_id'], post['text'] ?? "");
                        if (val == 'delete') notifier.deletePost(post['_id']);
                      },
                      itemBuilder: (c) => [
                        if (isMyPost) const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text("Edit", style: TextStyle(fontSize: 13))])),
                        if (canDelete) const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 16), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red, fontSize: 13))]))
                      ],
                    ),
                  )
              ],
            ),
          ),

          if (post['text'] != null && post['text'].toString().isNotEmpty) ...[
            Builder(
              builder: (context) {
                String fullText = post['text'];
                final match = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false).firstMatch(fullText);
                String? extractedUrl = match?.group(0);
                String cleanText = extractedUrl != null ? fullText.replaceAll(extractedUrl, '').trim() : fullText;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (cleanText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                        child: MarkdownBody(
                          data: cleanText,
                          styleSheet: MarkdownStyleSheet(
                            p: GoogleFonts.lato(fontSize: 13, color: textColor, height: 1.3),
                            listBullet: TextStyle(color: textColor, fontSize: 13),
                            a: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                          ),
                          onTapLink: (text, href, title) async {
                            if (href != null && await canLaunchUrl(Uri.parse(href))) {
                              await launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      ),
                    if (extractedUrl != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: _buildLinkCard(extractedUrl, isDark),
                      ),
                  ],
                );
              }
            ),
          ],

          if (images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
              child: ClipRRect(borderRadius: BorderRadius.circular(8), child: PostImageGallery(images: images, isDark: isDark)),
            ),

          if ((post['likes']?.length ?? 0) > 0 || (post['comments']?.length ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  if ((post['likes']?.length ?? 0) > 0)
                    GestureDetector(
                      onTap: () => LikesSheet.show(context, post['_id']),
                      child: Row(
                        children: [
                          Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle), child: const Icon(Icons.thumb_up, size: 8, color: Colors.white)),
                          const SizedBox(width: 4),
                          Text("${post['likes']?.length}", style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  const Spacer(),
                  if ((post['comments']?.length ?? 0) > 0)
                    GestureDetector(
                      onTap: () => CommentsSheet.show(context, post['_id']),
                      child: Text("${post['comments']?.length} comments", style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),

          const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Divider(height: 1, thickness: 0.5)),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 0),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: Icon(post['isLikedByMe'] == true ? Icons.thumb_up : Icons.thumb_up_outlined, size: 16, color: post['isLikedByMe'] == true ? Colors.blue : subTextColor),
                    label: Text("Like", style: TextStyle(color: post['isLikedByMe'] == true ? Colors.blue : subTextColor, fontSize: 11)),
                    onPressed: () {
                      if (!kIsWeb) Vibration.hasVibrator().then((v) { if (v ?? false) Vibration.vibrate(duration: 10); });
                      notifier.toggleLike(post['_id']);
                    },
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    icon: Icon(Icons.mode_comment_outlined, size: 16, color: subTextColor),
                    label: Text("Comment", style: TextStyle(color: subTextColor, fontSize: 11)),
                    onPressed: () => CommentsSheet.show(context, post['_id']),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    icon: Icon(Icons.share_outlined, size: 16, color: subTextColor),
                    label: Text("Share", style: TextStyle(color: subTextColor, fontSize: 11)),
                    onPressed: () => Share.share("${author['fullName']}: ${post['text'] ?? ''}"),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 5, color: isDark ? Colors.black : Colors.grey[200]),
        ],
      ),
    );
  }
}