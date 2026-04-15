import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:http/http.dart' as http; 
import 'package:url_launcher/url_launcher.dart'; 

// ✅ IMPORT RIVERPOD & PROFILE VIEW MODEL
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/profile_view_model.dart';

import '../config.dart'; 
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart'; 
import '../services/socket_service.dart'; 
import 'alumni_detail_screen.dart';
import 'call_screen.dart'; // ✅ RESTORED: Import Call Screen
import 'polls_screen.dart'; 
import '../widgets/full_screen_image.dart'; 

// ✅ CHANGED TO ConsumerStatefulWidget
class GroupInfoScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;

  const GroupInfoScreen({super.key, required this.groupId, required this.groupName});

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  final DataService _dataService = DataService();
  final ApiClient _api = ApiClient();
  final ImagePicker _picker = ImagePicker();
  
  Map<String, dynamic>? _groupData;
  List<dynamic> _allMembers = [];
  List<dynamic> _filteredMembers = [];
  List<dynamic> _admins = [];
  
  bool _isLoading = true;
  bool _isCurrentUserAdmin = false;
  String? _myUserId;
  
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadGroupInfo();
    _setupSocketListener();
  }

  @override
  void dispose() {
    final socket = SocketService().socket;
    socket?.off('removed_from_group');
    super.dispose();
  }

  void _setupSocketListener() {
    final socket = SocketService().socket;
    if (socket == null) return;

    socket.on('removed_from_group', (data) {
      if (!mounted) return;
      if (data['groupId'] == widget.groupId) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            title: const Text("Access Revoked"),
            content: const Text("You have been removed from this group."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(c); 
                  Navigator.of(context).popUntil((route) => route.isFirst); 
                },
                child: const Text("OK"),
              )
            ],
          ),
        );
      }
    });
  }

 Future<void> _loadGroupInfo() async {
    _myUserId = await AuthService().currentUserId;
    final result = await _dataService.fetchGroupInfo(widget.groupId);
    
    if (mounted) {
      List<dynamic> members = List.from(result?['members'] ?? []);

      members.sort((a, b) {
        final bool isAdminA = a['isAdmin'] ?? false;
        final bool isAdminB = b['isAdmin'] ?? false;

        if (isAdminA && !isAdminB) return -1;
        if (!isAdminA && isAdminB) return 1;
        return (a['fullName'] ?? "").toString().compareTo(b['fullName'] ?? "");
      });

      setState(() {
        _groupData = result;
        _allMembers = members;
        _filteredMembers = members; 
        _admins = result?['admins'] ?? [];
        _isCurrentUserAdmin = result?['isCurrentUserAdmin'] ?? false;
        _isLoading = false;
      });
    }
  }

  void _filterMembers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = _allMembers;
      } else {
        _filteredMembers = _allMembers.where((m) {
          final name = (m['fullName'] ?? "").toString().toLowerCase();
          final job = (m['jobTitle'] ?? "").toString().toLowerCase();
          return name.contains(query.toLowerCase()) || job.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _handleGroupIconOptions() async {
    showModalBottomSheet(
      context: context, 
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text("Choose from Gallery"),
            onTap: () { Navigator.pop(ctx); _pickAndUploadIcon(); }
          ),
          if (_groupData?['icon'] != null && _groupData!['icon'] != "")
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Remove Icon (Revert to Default)", style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(ctx); _revertIcon(); }
            ),
        ],
      )
    );
  }

  Future<void> _pickAndUploadIcon() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() => _isLoading = true);
      final success = await _dataService.updateGroupIcon(widget.groupId, image);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Group Icon Updated!")));
        _loadGroupInfo();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update icon.")));
      }
    }
  }

  Future<void> _revertIcon() async {
    setState(() => _isLoading = true);
    final success = await _dataService.removeGroupIcon(widget.groupId);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Icon removed.")));
      _loadGroupInfo();
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to remove icon.")));
    }
  }

  // ==========================================
  // 📞 GROUP CALL LOGIC
  // ==========================================
  void _initiateGroupCall() {
    String uniqueChannel = "call_${DateTime.now().millisecondsSinceEpoch}";
    
    final userProfile = ref.read(profileProvider).userProfile;
    final currentUserName = userProfile?['fullName'] ?? "Alumni User";
    final currentUserAvatar = userProfile?['profilePicture'];

    // Extract member IDs, excluding self
    List<String> targets = _allMembers
        .map((m) => m['_id'].toString())
        .where((id) => id != _myUserId)
        .toList();

    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No other members in group to call."))
      );
      return;
    }

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => CallScreen(
          isGroupCall: true, 
          targetIds: targets, // ✅ Pass group members
          remoteName: widget.groupName, // Display Group Name
          remoteId: null, 
          channelName: uniqueChannel,
          remoteAvatar: _groupData?['icon'], // Pass Group Icon
          isIncoming: false, 
          currentUserName: currentUserName,      
          currentUserAvatar: currentUserAvatar,  
        ),
      ),
    );
  }

  // ==========================================
  // 📊 POLLS LOGIC
  // ==========================================
  void _openPolls() {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => const PollsScreen() 
      )
    );
  }

  // ==========================================
  // 📄 DOCS LOGIC (Web Compatible)
  // ==========================================
  void _openDocsSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("📂 Group Documents", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  IconButton(onPressed: _uploadFile, icon: const Icon(Icons.upload_file, color: Colors.blue)),
                ],
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder(
                  future: _api.get('/api/groups/${widget.groupId}/documents'),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (snapshot.hasError) return const Center(child: Text("Error loading files"));

                    List files = [];
                    try {
                      if (snapshot.data is Map) {
                        final apiResponse = snapshot.data; 
                        if (apiResponse['data'] is Map) {
                          final body = apiResponse['data']; 
                          if (body['data'] is List) {
                            files = body['data'];
                          }
                        } else if (apiResponse['data'] is List) {
                          files = apiResponse['data']; 
                        }
                      }
                    } catch (e) {
                      debugPrint("Docs Parse Error: $e");
                    }

                    if (files.isEmpty) {
                      return Center(child: Text("No documents yet.", style: theme.textTheme.bodyMedium));
                    }

                    return ListView.builder(
                      controller: scrollCtrl,
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        final file = files[index];
                        final String fileName = file['fileName'] ?? "Unknown File";
                        final String date = file['createdAt'] != null 
                            ? DateFormat('MMM d').format(DateTime.parse(file['createdAt'])) 
                            : "Unknown Date";
                        final String url = file['fileUrl'] ?? "";
                        final String docId = file['_id'];
                        final String uploaderId = file['uploader'] is Map ? file['uploader']['_id'] : (file['uploader'] ?? "");

                        final bool canDelete = _isCurrentUserAdmin || (uploaderId == _myUserId);

                        return ListTile(
                          leading: const Icon(Icons.insert_drive_file, color: Colors.redAccent),
                          title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text("Uploaded $date"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.download_rounded, size: 20, color: Colors.grey),
                                onPressed: () async {
                                  if (url.isNotEmpty) {
                                    final uri = Uri.parse(url);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  }
                                },
                              ),
                              if (canDelete)
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                  onPressed: () => _deleteDocument(docId),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        withData: true, 
      );
      
      if (result != null && result.files.isNotEmpty) {
        final platformFile = result.files.single;
        
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Uploading file..."), duration: Duration(seconds: 1)),
        );

        var request = http.MultipartRequest(
          'POST', 
          Uri.parse('${AppConfig.baseUrl}/api/groups/${widget.groupId}/documents')
        );
        
        if (kIsWeb) {
          if (platformFile.bytes != null) {
            request.files.add(http.MultipartFile.fromBytes(
              'file', 
              platformFile.bytes!,
              filename: platformFile.name
            ));
          } else {
            throw Exception("File bytes are missing. Cannot upload on Web.");
          }
        } else {
          if (platformFile.path != null) {
            request.files.add(await http.MultipartFile.fromPath('file', platformFile.path!));
          } else {
             throw Exception("File path is missing.");
          }
        }
        
        String? token = await AuthService().getToken();
        if (token != null) {
          request.headers['auth-token'] = token;
        }
        
        var response = await request.send();
        
        if (!mounted) return;

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File uploaded successfully!")));
          _openDocsSheet(); 
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: ${response.statusCode}")));
        }
      }
    } catch (e) {
      debugPrint("Upload Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _deleteDocument(String docId) async {
    Navigator.pop(context); 
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleting file...")));

    final success = await _dataService.deleteGroupDocument(widget.groupId, docId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File deleted.")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete file.")));
      }
      _openDocsSheet(); 
    }
  }

  // ==========================================
  // 📢 NOTICE BOARD LOGIC
  // ==========================================
  void _openNoticeBoard() {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: theme.dividerColor))
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("📢 Notice Board", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    if (_isCurrentUserAdmin)
                      TextButton.icon(
                        onPressed: () => _postOrEditNotice(context, null), 
                        icon: const Icon(Icons.add, size: 18), 
                        label: const Text("Post")
                      )
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder(
                  future: _api.get('/api/groups/${widget.groupId}/notices'),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text("Failed to load notices"));
                    }
                    
                    List<dynamic> notices = [];
                    try {
                      if (snapshot.data is Map) {
                        final apiResponse = snapshot.data; 
                        if (apiResponse['data'] is Map) {
                          final body = apiResponse['data']; 
                          if (body['data'] is List) {
                            notices = body['data'];
                          } else if (body is List) {
                            notices = body; 
                          }
                        } else if (apiResponse['data'] is List) {
                          notices = apiResponse['data']; 
                        }
                      }
                    } catch (e) {
                      debugPrint("Notice Parsing Error: $e");
                    }

                    if (notices.isEmpty) {
                      return Center(child: Text("No notices yet.", style: theme.textTheme.bodyMedium));
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: notices.length,
                      itemBuilder: (context, index) {
                        final notice = notices[index];
                        final bool isPoster = notice['postedBy'] != null && 
                            (notice['postedBy']['_id'] == _myUserId || notice['postedBy'] == _myUserId);
                        final bool canManage = _isCurrentUserAdmin || isPoster;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 0,
                          color: Colors.amber.withOpacity(0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.amber.withOpacity(0.2))),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.push_pin, size: 16, color: Colors.amber),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        notice['title'] ?? "Notice", 
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textTheme.bodyLarge?.color)
                                      )
                                    ),
                                    
                                    if (canManage)
                                      PopupMenuButton<String>(
                                        onSelected: (val) {
                                          if (val == 'edit') _postOrEditNotice(context, notice);
                                          if (val == 'delete') _deleteNotice(notice['_id']);
                                        },
                                        itemBuilder: (c) => [
                                          const PopupMenuItem(value: 'edit', child: Text("Edit")),
                                          const PopupMenuItem(value: 'delete', child: Text("Delete", style: TextStyle(color: Colors.red))),
                                        ],
                                        child: Icon(Icons.more_vert, size: 18, color: theme.iconTheme.color),
                                      )
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  notice['content'] ?? "", 
                                  style: TextStyle(color: theme.textTheme.bodyMedium?.color)
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Posted on ${DateFormat('MMM d, y').format(DateTime.parse(notice['createdAt']))}", 
                                  style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color ?? Colors.grey)
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _postOrEditNotice(BuildContext parentContext, Map<String, dynamic>? existingNotice) {
    final isEditing = existingNotice != null;
    final titleCtrl = TextEditingController(text: isEditing ? existingNotice['title'] : "");
    final bodyCtrl = TextEditingController(text: isEditing ? existingNotice['content'] : "");
    
    showDialog(
      context: parentContext, 
      builder: (c) => AlertDialog(
        title: Text(isEditing ? "Edit Notice" : "Post Announcement"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Title", border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: bodyCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Content", border: OutlineInputBorder()))]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(onPressed: () async {
              if(titleCtrl.text.isEmpty || bodyCtrl.text.isEmpty) return;
              Navigator.pop(c);
              
              if (isEditing) {
                await _dataService.editGroupNotice(widget.groupId, existingNotice['_id'], titleCtrl.text, bodyCtrl.text);
              } else {
                await _api.post('/api/groups/${widget.groupId}/notices', {'title': titleCtrl.text, 'content': bodyCtrl.text});
              }
              
              if (mounted) {
                Navigator.pop(parentContext); 
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEditing ? "Notice Updated" : "Notice Posted")));
                _openNoticeBoard(); 
              }
            }, child: Text(isEditing ? "Save" : "Post")),
        ],
      )
    );
  }

  Future<void> _deleteNotice(String noticeId) async {
    Navigator.pop(context); 
    final success = await _dataService.deleteGroupNotice(widget.groupId, noticeId);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notice deleted.")));
      _openNoticeBoard(); 
    }
  }

  Future<void> _toggleAdmin(String userId, String name) async {
    await _dataService.toggleGroupAdmin(widget.groupId, userId);
    _loadGroupInfo(); 
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Role updated for $name")));
  }

  Future<void> _removeMember(String userId) async {
    await _dataService.removeGroupMember(widget.groupId, userId);
    _loadGroupInfo();
  }

  Future<void> _viewProfile(String userId) async {
    showDialog(context: context, builder: (c) => const Center(child: CircularProgressIndicator()));
    final fullProfile = await _dataService.fetchAlumniById(userId);
    Navigator.pop(context);
    if (fullProfile != null && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => AlumniDetailScreen(alumniData: fullProfile)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? iconUrl = _groupData?['icon'];
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final String heroTag = "group_icon_${widget.groupId}"; 

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 320,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 1. IMAGE LAYER (Bottom)
                          if (iconUrl != null && iconUrl.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FullScreenImage(
                                      imageUrl: iconUrl,
                                      heroTag: heroTag,
                                    ),
                                  ),
                                );
                              },
                              child: Hero(
                                tag: heroTag,
                                child: CachedNetworkImage(imageUrl: iconUrl, fit: BoxFit.cover),
                              ),
                            )
                          else
                            Container(color: Colors.teal.shade100, child: const Icon(Icons.groups, size: 80, color: Colors.teal)),
                          
                          // 2. GRADIENT LAYER (Middle)
                          IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                  colors: [Colors.black.withOpacity(0.4), Colors.transparent, Colors.black.withOpacity(0.8)],
                                ),
                              ),
                            ),
                          ),
                          
                          // 3. TEXT LAYER (Top)
                          Positioned(
                            bottom: 20, left: 20, right: 80,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.groupName, style: GoogleFonts.lato(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                                const SizedBox(height: 4),
                                Text("${_allMembers.length} Members • Group", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                              ],
                            ),
                          ),

                          if (_isCurrentUserAdmin)
                            Positioned(
                              bottom: 20, right: 20,
                              child: GestureDetector(
                                onTap: _handleGroupIconOptions,
                                child: CircleAvatar(backgroundColor: Colors.white, radius: 24, child: Icon(Icons.camera_alt, color: primaryColor)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ✅ UPDATED ACTION BUTTONS: 4 Buttons neatly fitted
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionBtn(Icons.call, "Call", _initiateGroupCall, Colors.green),
                          _buildActionBtn(Icons.poll, "Polls", _openPolls, Colors.purple),
                          _buildActionBtn(Icons.campaign, "Notices", _openNoticeBoard, Colors.orange),
                          _buildActionBtn(Icons.description, "Docs", _openDocsSheet, Colors.blue),
                        ],
                      ),
                    ),
                  ),

                  if (_admins.isEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber)),
                        child: Column(
                          children: [
                            const Text("This group has no admin.", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => _toggleAdmin(_myUserId!, "Yourself"), 
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800], foregroundColor: Colors.white),
                              child: const Text("Claim Admin Rights"),
                            ),
                          ],
                        ),
                      ),
                    ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterMembers,
                        style: theme.textTheme.bodyLarge,
                        decoration: InputDecoration(
                          hintText: "Search members...",
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          filled: true,
                          fillColor: theme.inputDecorationTheme.fillColor ?? Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Text("Participants (${_filteredMembers.length})", style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                    ),
                  ),

                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final m = _filteredMembers[index];
                        final bool isAdmin = m['isAdmin'] ?? false;
                        final bool isMe = m['_id'] == _myUserId;

                        return ListTile(
                          onTap: () => _viewProfile(m['_id']),
                          leading: CircleAvatar(
                            backgroundImage: (m['profilePicture'] != null && m['profilePicture'] != "") ? CachedNetworkImageProvider(m['profilePicture']) : null,
                            child: (m['profilePicture'] == null || m['profilePicture'] == "") ? const Icon(Icons.person) : null,
                          ),
                          title: Text(isMe ? "You" : m['fullName'], style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(m['jobTitle'] ?? "Member"),
                          trailing: isAdmin 
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green)),
                                child: const Text("Admin", style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                              )
                            : null,
                          onLongPress: (_isCurrentUserAdmin && !isMe) ? () {
                             showModalBottomSheet(context: context, builder: (c) => Wrap(children: [
                               ListTile(leading: const Icon(Icons.shield), title: Text(isAdmin ? "Dismiss as Admin" : "Make Group Admin"), onTap: () { Navigator.pop(c); _toggleAdmin(m['_id'], m['fullName']); }),
                               ListTile(leading: const Icon(Icons.person_remove, color: Colors.red), title: const Text("Remove from Group", style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(c); _removeMember(m['_id']); }),
                             ]));
                          } : null,
                        );
                      },
                      childCount: _filteredMembers.length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),

              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
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

  // ✅ UPDATED Action Button to comfortably fit 4 items
  Widget _buildActionBtn(IconData icon, String label, VoidCallback onTap, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08), 
              borderRadius: BorderRadius.circular(16)
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 24), 
                const SizedBox(height: 6), 
                Text(
                  label, 
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)
                )
              ]
            ),
          ),
        ),
      ),
    );
  }
}