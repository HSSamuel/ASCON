import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../viewmodels/chat_view_model.dart';
import '../widgets/shimmer_utils.dart';
import '../widgets/chat/call_logs_tab.dart'; 
import 'chat_screen.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Initialize TabController for 2 tabs
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // SAFELY GET OTHER PARTICIPANT (Prevents Map Cast Error)
  Map<String, dynamic> _getOtherParticipant(Map<String, dynamic> conversation, String myId) {
    if (conversation['isGroup'] == true) {
      final groupRaw = conversation['groupId'];
      if (groupRaw is Map) {
        final group = Map<String, dynamic>.from(groupRaw);
        return {
          '_id': group['_id'],
          'fullName': group['name'] ?? "Group",
          'profilePicture': group['icon'],
          'isOnline': false, 
          'isGroup': true
        };
      } else {
         return {'fullName': "Group Chat", 'isGroup': true, 'isOnline': false};
      }
    }

    final participants = conversation['participants'] as List?;
    if (participants == null || participants.isEmpty) {
      return {'fullName': 'Unknown User', 'profilePicture': ''};
    }

    // Safe retrieval
    final otherRaw = participants.firstWhere(
      (p) => p['_id'] != myId,
      orElse: () => participants.isNotEmpty ? participants[0] : {'fullName': 'Unknown User', 'profilePicture': ''},
    );
    
    if (otherRaw is Map) {
      return Map<String, dynamic>.from(otherRaw);
    }
    return {'fullName': 'Unknown User', 'profilePicture': ''};
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // 1. CUSTOM APP BAR WITH TABS
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              decoration: BoxDecoration(
                color: cardColor,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Connect", style: GoogleFonts.lato(fontSize: 28, fontWeight: FontWeight.w900, color: textColor)),
                  const SizedBox(height: 16),
                  
                  // SEARCH BAR
                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      notifier.searchConversations(val);
                    },
                    decoration: InputDecoration(
                      hintText: "Search conversations...",
                      prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                  
                  // TAB BAR
                  TabBar(
                    controller: _tabController,
                    labelColor: primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: primaryColor,
                    indicatorWeight: 3,
                    labelStyle: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16),
                    tabs: const [
                      Tab(text: "Chats"),
                      Tab(text: "Call Logs"), 
                    ],
                  ),
                ],
              ),
            ),

            // 2. TAB CONTENT
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // TAB 1: CHATS
                  chatState.isLoading 
                    ? const ChatListSkeleton() 
                    : RefreshIndicator(
                        onRefresh: () async => notifier.loadConversations(),
                        child: _buildChatListTab(chatState, notifier),
                      ),
                  
                  // TAB 2: CALL LOGS
                  const CallLogsTab(), 
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatListTab(ChatState chatState, ChatNotifier notifier) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // A. ACTIVE NOW RAIL
        if (chatState.onlineUsers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Text("Active Now", style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
          ),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: chatState.onlineUsers.length,
              itemBuilder: (context, index) {
                final rawChat = chatState.onlineUsers[index];
                if (rawChat is Map) {
                  final chat = Map<String, dynamic>.from(rawChat);
                  final user = _getOtherParticipant(chat, chatState.myId);
                  return _buildActiveUserBubble(user);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],

        // B. CHAT LIST
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Text("Recent", style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
        ),
        
        if (chatState.filteredConversations.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40.0),
            child: Center(child: Column(
              children: [
                Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text("No conversations found.", style: TextStyle(color: Colors.grey[500])),
              ],
            )),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: chatState.filteredConversations.length,
            separatorBuilder: (c, i) => Divider(height: 1, indent: 80, color: Colors.grey.withOpacity(0.1)),
            itemBuilder: (context, index) {
              final rawChat = chatState.filteredConversations[index];
              if (rawChat is Map) {
                final chat = Map<String, dynamic>.from(rawChat);
                return _buildChatTile(chat, chatState.myId, chatState.typingStatus, notifier);
              }
              return const SizedBox.shrink();
            },
          ),
          
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildActiveUserBubble(Map<String, dynamic> user) {
    return GestureDetector(
      onTap: () => _openChat(user, null),
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Stack(
              children: [
                // ✅ FIXED: Using CachedNetworkImage with error fallback
                CachedNetworkImage(
                  imageUrl: user['profilePicture'] ?? "",
                  imageBuilder: (context, imageProvider) => CircleAvatar(
                    radius: 28,
                    backgroundImage: imageProvider,
                    backgroundColor: Colors.grey[200],
                  ),
                  placeholder: (context, url) => CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey[200],
                    child: const Icon(Icons.person, color: Colors.grey),
                  ),
                  errorWidget: (context, url, error) => CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey[200],
                    child: const Icon(Icons.person, color: Colors.grey),
                  ),
                ),
                Positioned(
                  right: 2, bottom: 2,
                  child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2.5)
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 60,
              child: Text(
                (user['fullName'] ?? "User").split(" ")[0], 
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chat, String myId, Map<String, bool> typingStatus, ChatNotifier notifier) {
    final other = _getOtherParticipant(chat, myId);
    final String convId = chat['_id'];
    
    dynamic lastMsgObj = chat['lastMessage']; 
    String lastMessageText = "Photo";
    String? senderId;
    bool isRead = true;

    if (lastMsgObj is Map) {
      lastMessageText = lastMsgObj['text'] ?? (lastMsgObj['fileUrl'] != null ? "Attachment" : "Message");
      senderId = lastMsgObj['senderId'];
      isRead = lastMsgObj['isRead'] ?? true;
    } else if (lastMsgObj is String) {
      lastMessageText = lastMsgObj;
    }

    final int unreadCount = chat['unreadCount'] ?? 0;
    final bool isOnline = other['isOnline'] == true;
    final bool isTyping = typingStatus[convId] ?? false;
    final String time = _formatTime(chat['lastMessageAt']);
    final bool isMe = senderId == myId;

    return Dismissible(
      key: Key(convId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Delete Chat?"),
            content: const Text("This conversation will be removed from your list."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
            ],
          ),
        );
      },
      onDismissed: (direction) => notifier.deleteConversation(convId),
      child: InkWell(
        onTap: () {
          _openChat(other, convId);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Stack(
                children: [
                  // ✅ FIXED: Using CachedNetworkImage with error fallback
                  CachedNetworkImage(
                    imageUrl: other['profilePicture'] ?? "",
                    imageBuilder: (context, imageProvider) => CircleAvatar(
                      radius: 28,
                      backgroundImage: imageProvider,
                      backgroundColor: Colors.grey[200],
                    ),
                    placeholder: (context, url) => CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey[200],
                      child: const Icon(Icons.person, color: Colors.grey),
                    ),
                    errorWidget: (context, url, error) => CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey[200],
                      child: const Icon(Icons.person, color: Colors.grey),
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      right: 0, bottom: 0,
                      child: Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2)
                        ),
                      ),
                    )
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            other['fullName'] ?? "Unknown", 
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.lato(
                              fontWeight: unreadCount > 0 ? FontWeight.w900 : FontWeight.bold, 
                              fontSize: 16,
                              color: Theme.of(context).textTheme.bodyLarge?.color
                            )
                          ),
                        ),
                        Text(
                          time, 
                          style: TextStyle(
                            fontSize: 11, 
                            color: unreadCount > 0 ? Theme.of(context).primaryColor : Colors.grey,
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal
                          )
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    Row(
                      children: [
                        Expanded(
                          child: isTyping 
                            ? Text(
                                "Typing...", 
                                style: TextStyle(color: Theme.of(context).primaryColor, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)
                              )
                            : Row(
                                children: [
                                  if (isMe) ...[
                                    Icon(
                                      isRead ? Icons.done_all : Icons.check, 
                                      size: 16, 
                                      color: isRead ? Colors.blue : Colors.grey
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: Text(
                                      lastMessageText, 
                                      maxLines: 1, 
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: unreadCount > 0 ? Theme.of(context).textTheme.bodyLarge?.color : Colors.grey[600],
                                        fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 14
                                      )
                                    ),
                                  ),
                                ],
                              ),
                        ),
                        
                        if (unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle),
                            child: Text(
                              unreadCount > 9 ? "9+" : unreadCount.toString(), 
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                            ),
                          )
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String? dateString) {
    if (dateString == null) return "";
    final date = DateTime.parse(dateString).toLocal();
    final now = DateTime.now();
    
    if (now.difference(date).inDays == 0 && now.day == date.day) {
      return DateFormat('h:mm a').format(date); 
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('E').format(date); 
    } else {
      return DateFormat('dd/MM').format(date); 
    }
  }

  void _openChat(Map<String, dynamic> user, String? conversationId) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          receiverId: user['_id'],
          receiverName: user['fullName'],
          receiverProfilePic: user['profilePicture'],
          isOnline: user['isOnline'] ?? false,
          isGroup: user['isGroup'] ?? false,
          groupId: user['isGroup'] == true ? user['_id'] : null,
          conversationId: conversationId,
        ),
      ),
    ).then((_) => ref.read(chatProvider.notifier).loadConversations()); 
  }
}