import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../viewmodels/updates_view_model.dart';
import 'programme_detail_screen.dart';
import 'alumni_detail_screen.dart'; 

class UpdatesScreen extends ConsumerStatefulWidget {
  const UpdatesScreen({super.key});

  @override
  ConsumerState<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends ConsumerState<UpdatesScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _viewProfile(Map<String, dynamic> user) {
    final userId = user['_id'] ?? user['userId'] ?? user['id'];
    
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot view profile: User ID missing"))
      );
      return;
    }
    
    final alumniData = {
      ...user,
      'userId': userId,
      '_id': userId,
      'fullName': user['fullName'] ?? "User",
      'profilePicture': user['profilePicture'],
    };

    Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => AlumniDetailScreen(alumniData: alumniData))
    );
  }

  List<TextSpan> _parseFormattedText(String text, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    final RegExp exp = RegExp(r'([*_~])(.*?)\1'); 
    
    text.splitMapJoin(exp, onMatch: (Match m) {
        final String marker = m.group(1)!; 
        final String content = m.group(2)!;
        
        TextStyle newStyle = baseStyle;
        if (marker == '*') newStyle = newStyle.copyWith(fontWeight: FontWeight.bold);
        if (marker == '_') newStyle = newStyle.copyWith(fontStyle: FontStyle.italic);
        if (marker == '~') newStyle = newStyle.copyWith(decoration: TextDecoration.underline);
        
        spans.add(TextSpan(text: content, style: newStyle));
        return '';
      }, 
      onNonMatch: (String s) { 
        spans.add(TextSpan(text: s, style: baseStyle)); 
        return ''; 
      },
    );
    return spans;
  }

  Future<void> _showEditDialog(String postId, String currentText) async {
    final editCtrl = TextEditingController(text: currentText);
    
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Update"),
        content: TextField(
          controller: editCtrl,
          maxLines: 5,
          minLines: 1,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, editCtrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (newText != null && newText.isNotEmpty && newText != currentText) {
      final success = await ref.read(updatesProvider.notifier).editPost(postId, newText);
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post updated.")));
      }
    }
  }

  void _showLikesSheet(String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
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
                                onTap: () => _viewProfile(user),
                                leading: Stack(
                                  children: [
                                    CircleAvatar(
                                      backgroundImage: (user['profilePicture'] != null && user['profilePicture'].toString().startsWith('http')) 
                                          ? CachedNetworkImageProvider(user['profilePicture']) 
                                          : null,
                                      child: user['profilePicture'] == null ? const Icon(Icons.person) : null,
                                    ),
                                    if (isOnline)
                                      Positioned(
                                        right: 0, bottom: 0,
                                        child: Container(
                                          width: 12, height: 12,
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2)
                                          ),
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
    );
  }

  void _showCommentsSheet(String postId) {
    final commentController = TextEditingController();
    bool isPosting = false; 

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final textColor = isDark ? Colors.white : Colors.black87;
            final bubbleColor = isDark ? Colors.grey[800] : Colors.grey[100];

            return FutureBuilder<List<dynamic>>(
              future: ref.read(updatesProvider.notifier).fetchComments(postId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                
                final comments = snapshot.data!;

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
                          child: comments.isEmpty 
                              ? Center(child: Text("No comments yet.", style: GoogleFonts.lato(color: Colors.grey)))
                              : ListView.builder(
                                  itemCount: comments.length,
                                  padding: const EdgeInsets.all(16),
                                  itemBuilder: (context, index) {
                                    final c = comments[index];
                                    final author = c['author'] ?? {};
                                    final authorName = author['fullName'] ?? "User";
                                    final authorImg = author['profilePicture'];
                                    final bool isOnline = author['isOnline'] == true;
                                    final time = timeago.format(DateTime.tryParse(c['createdAt'] ?? "") ?? DateTime.now());
                                    
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          GestureDetector(
                                            onTap: () => _viewProfile(author),
                                            child: Stack(
                                              children: [
                                                CircleAvatar(
                                                  radius: 16,
                                                  backgroundColor: Colors.grey[200],
                                                  backgroundImage: authorImg != null && authorImg.toString().startsWith('http') ? CachedNetworkImageProvider(authorImg) : null,
                                                  child: authorImg == null ? const Icon(Icons.person, size: 16, color: Colors.grey) : null,
                                                ),
                                                if (isOnline)
                                                  Positioned(
                                                    right: 0, bottom: 0,
                                                    child: Container(
                                                      width: 10, height: 10,
                                                      decoration: BoxDecoration(
                                                        color: Colors.green,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5)
                                                      ),
                                                    ),
                                                  )
                                              ],
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
                                                        child: Text(authorName, style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 13, color: textColor))
                                                      ),
                                                      Text(time, style: GoogleFonts.lato(fontSize: 10, color: Colors.grey)),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text.rich(
                                                    TextSpan(children: _parseFormattedText(c['text'] ?? "", GoogleFonts.lato(fontSize: 14, color: textColor))),
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
                                  controller: commentController,
                                  style: TextStyle(color: textColor),
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
                                child: isPosting
                                    ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : IconButton(
                                        icon: const Icon(Icons.send_rounded, size: 20, color: Colors.white), 
                                        onPressed: () async {
                                          if (commentController.text.trim().isEmpty) return;
                                          setSheetState(() => isPosting = true);
                                          await ref.read(updatesProvider.notifier).postComment(postId, commentController.text.trim());
                                          commentController.clear();
                                          if (mounted) setSheetState(() => isPosting = false);
                                        }
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
            );
          },
        );
      },
    );
  }

  void _showCreatePostSheet() {
    final TextEditingController textController = TextEditingController();
    // ✅ CHANGED: Support multiple images
    List<XFile> selectedImages = []; 
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isPosting = ref.watch(updatesProvider).isPosting;

            // ✅ Pick multiple images
            Future<void> pickImages() async {
              final picker = ImagePicker();
              final pickedFiles = await picker.pickMultiImage(imageQuality: 70);
              if (pickedFiles.isNotEmpty) {
                setSheetState(() {
                  selectedImages.addAll(pickedFiles);
                  if (selectedImages.length > 5) {
                    selectedImages = selectedImages.sublist(0, 5); // Max 5 images
                    ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Max 5 images allowed.")));
                  }
                });
              }
            }

            Future<void> submitPost() async {
              if (textController.text.trim().isEmpty && selectedImages.isEmpty) return;
              final error = await ref.read(updatesProvider.notifier).createPost(textController.text.trim(), selectedImages);
              
              if (error == null) {
                Navigator.pop(sheetContext);
                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Update posted! 🚀"), backgroundColor: Colors.green));
              } else {
                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("New Update", style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
                      isPosting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : TextButton(
                            onPressed: submitPost,
                            style: TextButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                            child: const Text("Post", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    maxLines: 5,
                    minLines: 2,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: "Share news, achievements...", border: InputBorder.none),
                  ),
                  
                  // ✅ MULTIPLE IMAGE PREVIEW
                  if (selectedImages.isNotEmpty)
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: kIsWeb 
                                      ? Image.network(selectedImages[index].path, height: 120, width: 100, fit: BoxFit.cover)
                                      : Image.file(File(selectedImages[index].path), height: 120, width: 100, fit: BoxFit.cover),
                                ),
                              ),
                              IconButton(
                                icon: const CircleAvatar(backgroundColor: Colors.black54, radius: 12, child: Icon(Icons.close, size: 14, color: Colors.white)),
                                onPressed: () => setSheetState(() => selectedImages.removeAt(index)),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                  const Divider(height: 30),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.image_rounded, color: Colors.green)),
                    title: const Text("Add Photos (Max 5)"),
                    onTap: pickImages,
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(updatesProvider);
    final notifier = ref.read(updatesProvider.notifier);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: cardColor, 
              shadowColor: Colors.black.withOpacity(0.1),
              elevation: 2.0, 
              foregroundColor: isDark ? Colors.white : Colors.black,
              floating: true,
              snap: true,
              title: _isSearching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Search updates...",
                        border: InputBorder.none,
                        hintStyle: GoogleFonts.lato(fontSize: 18),
                        filled: true,
                        fillColor: isDark ? Colors.grey[800] : Colors.grey[100], 
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      ),
                      style: GoogleFonts.lato(fontSize: 18, color: isDark ? Colors.white : Colors.black),
                      onChanged: (val) => notifier.searchPosts(val),
                    )
                  : Text("Updates", style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 24, color: isDark ? Colors.white : Colors.black)),
              actions: [
                IconButton(
                  icon: Icon(_isSearching ? Icons.close : Icons.search),
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _searchController.clear();
                        notifier.searchPosts(""); 
                      }
                    });
                  },
                ),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'refresh') notifier.loadData();
                    if (val == 'filter') notifier.toggleMediaFilter();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'refresh', child: Row(children: [Icon(Icons.refresh, size: 20), SizedBox(width: 10), Text("Refresh")])),
                    PopupMenuItem(value: 'filter', child: Row(children: [Icon(updateState.showMediaOnly ? Icons.check_box : Icons.check_box_outline_blank, size: 20), const SizedBox(width: 10), const Text("Media Only")])),
                  ],
                ),
              ],
            ),
          ];
        },
        body: RefreshIndicator(
          onRefresh: () async => await notifier.loadData(),
          color: const Color(0xFFD4AF37),
          child: CustomScrollView(
            slivers: [
              if (updateState.highlights.isNotEmpty && !_isSearching) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Highlights", style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: updateState.highlights.length,
                      itemBuilder: (context, index) => _buildStatusCard(updateState.highlights[index]),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: Divider(height: 30, thickness: 0.5)),
              ],

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (updateState.showMediaOnly)
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text("Media Only", style: TextStyle(fontSize: 12, color: primaryColor))),
                    ],
                  ),
                ),
              ),

              if (updateState.isLoading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (updateState.filteredPosts.isEmpty)
                SliverFillRemaining(child: Center(child: Text("No updates.", style: GoogleFonts.lato(color: Colors.grey))))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildPostCard(updateState.filteredPosts[index], updateState.isAdmin, updateState.currentUserId, notifier),
                    childCount: updateState.filteredPosts.length,
                  ),
                ),
                
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          ),
        ),
      ),
      
      floatingActionButton: FloatingActionButton(
        heroTag: 'updates_fab_tag',
        onPressed: _showCreatePostSheet,
        backgroundColor: const Color(0xFFD4AF37),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> item) {
    final title = item['title'] ?? "News";
    final image = item['image'] ?? item['imageUrl'];
    
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ProgrammeDetailScreen(programme: item)));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), 
                child: image != null 
                  ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover, width: double.infinity)
                  : Container(color: Colors.grey[300], child: const Icon(Icons.article, color: Colors.grey)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                title, 
                maxLines: 2, 
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.bold)
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, bool isAdmin, String? myId, UpdatesNotifier notifier) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    final author = post['author'] ?? {};
    final String timeAgo = timeago.format(DateTime.tryParse(post['createdAt'] ?? "") ?? DateTime.now());
    final String postAuthorId = (post['authorId'] ?? '').toString();
    final bool isMyPost = (myId != null && postAuthorId == myId);
    final bool canDelete = isAdmin || isMyPost;
    final bool canEdit = isMyPost;

    // ✅ MULTIPLE IMAGE PARSING
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
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _viewProfile(author),
                  child: CircleAvatar(
                    radius: 20, 
                    backgroundColor: Colors.grey[200],
                    backgroundImage: author['profilePicture'] != null && author['profilePicture'].toString().startsWith('http')
                        ? CachedNetworkImageProvider(author['profilePicture'])
                        : null,
                    child: author['profilePicture'] == null ? Icon(Icons.person, size: 20, color: Colors.grey[400]) : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: GestureDetector(
                              onTap: () => _viewProfile(author),
                              child: Text(
                                author['fullName'] ?? 'Alumni Member', 
                                style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "• $timeAgo", 
                            style: GoogleFonts.lato(fontSize: 11, color: Colors.grey)
                          ),
                        ],
                      ),
                      if (author['jobTitle'] != null)
                        Text(
                          author['jobTitle'], 
                          style: GoogleFonts.lato(color: subTextColor, fontSize: 11),
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis
                        ),
                    ],
                  ),
                ),
                
                if (canDelete || canEdit)
                  SizedBox(
                    width: 24, height: 24,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.more_horiz, color: subTextColor, size: 20),
                      onSelected: (val) {
                        if (val == 'edit') _showEditDialog(post['_id'], post['text'] ?? "");
                        if (val == 'delete') notifier.deletePost(post['_id']);
                      },
                      itemBuilder: (c) => [
                        if (canEdit)
                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Edit")])),
                        if (canDelete)
                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))]))
                      ],
                    ),
                  )
              ],
            ),
          ),

          if (post['text'] != null && post['text'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SelectableText.rich( 
                TextSpan(
                  children: _parseFormattedText(
                    post['text'], 
                    GoogleFonts.lato(fontSize: 14, color: textColor, height: 1.4)
                  )
                ),
              ),
            ),

          // ✅ RENDER MULTIPLE IMAGES
          if (images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), 
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PostImageGallery(images: images, isDark: isDark),
              ),
            ),

          if ((post['likes']?.length ?? 0) > 0 || (post['comments']?.length ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if ((post['likes']?.length ?? 0) > 0) ...[
                    GestureDetector(
                      onTap: () => _showLikesSheet(post['_id']),
                      child: Row(
                        children: [
                          Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle), child: const Icon(Icons.thumb_up, size: 8, color: Colors.white)),
                          const SizedBox(width: 6),
                          Text("${post['likes']?.length}", style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  if ((post['comments']?.length ?? 0) > 0)
                    GestureDetector(
                      onTap: () => _showCommentsSheet(post['_id']),
                      child: Text("${post['comments']?.length} comments", style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),

          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 1)),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: Icon(post['isLikedByMe'] == true ? Icons.thumb_up : Icons.thumb_up_outlined, 
                      size: 18, color: post['isLikedByMe'] == true ? Colors.blue : subTextColor),
                    label: Text("Like", style: TextStyle(color: post['isLikedByMe'] == true ? Colors.blue : subTextColor, fontSize: 12)),
                    onPressed: () => notifier.toggleLike(post['_id']),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    icon: Icon(Icons.mode_comment_outlined, size: 18, color: subTextColor),
                    label: Text("Comment", style: TextStyle(color: subTextColor, fontSize: 12)),
                    onPressed: () => _showCommentsSheet(post['_id']),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    icon: Icon(Icons.share_outlined, size: 18, color: subTextColor),
                    label: Text("Share", style: TextStyle(color: subTextColor, fontSize: 12)),
                    onPressed: () => Share.share("${author['fullName']}: ${post['text'] ?? ''}"),
                  ),
                ),
              ],
            ),
          ),
          
          Container(height: 6, color: isDark ? Colors.black : Colors.grey[200]),
        ],
      ),
    );
  }
}

// ✅ NEW WIDGET: Swipable Image Gallery for Posts
class PostImageGallery extends StatefulWidget {
  final List<String> images;
  final bool isDark;

  const PostImageGallery({super.key, required this.images, required this.isDark});

  @override
  State<PostImageGallery> createState() => _PostImageGalleryState();
}

class _PostImageGalleryState extends State<PostImageGallery> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 320),
      color: widget.isDark ? Colors.black : Colors.grey[100],
      child: Stack(
        children: [
          PageView.builder(
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (context) => FullScreenImage(imageUrl: widget.images[index])),
                  );
                },
                child: CachedNetworkImage(
                  imageUrl: widget.images[index],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(height: 200, color: Colors.grey[200]),
                  errorWidget: (context, url, error) => const SizedBox(height: 50),
                ),
              );
            },
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentIndex == index ? 8 : 5,
                    height: _currentIndex == index ? 8 : 5,
                    decoration: BoxDecoration(
                      color: _currentIndex == index ? Colors.white : Colors.white.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  const FullScreenImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}