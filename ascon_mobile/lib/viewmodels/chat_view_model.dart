import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';

class ChatState {
  final List<dynamic> conversations;
  final List<dynamic> filteredConversations;
  final List<dynamic> onlineUsers; 
  final bool isLoading;
  final String myId;
  final Map<String, bool> typingStatus;

  const ChatState({
    this.conversations = const [],
    this.filteredConversations = const [],
    this.onlineUsers = const [], 
    this.isLoading = true,
    this.myId = "",
    this.typingStatus = const {},
  });

  ChatState copyWith({
    List<dynamic>? conversations,
    List<dynamic>? filteredConversations,
    List<dynamic>? onlineUsers,
    bool? isLoading,
    String? myId,
    Map<String, bool>? typingStatus,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      filteredConversations: filteredConversations ?? this.filteredConversations,
      onlineUsers: onlineUsers ?? this.onlineUsers,
      isLoading: isLoading ?? this.isLoading,
      myId: myId ?? this.myId,
      typingStatus: typingStatus ?? this.typingStatus,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ApiClient _api = ApiClient();
  final AuthService _auth = AuthService();
  final SocketService _socket = SocketService();
  
  final Box _cacheBox = Hive.box('ascon_cache');

  ChatNotifier() : super(const ChatState()) {
    init();
  }

  Future<void> init() async {
    final id = await _auth.currentUserId ?? "";
    if (mounted) state = state.copyWith(myId: id);
    await loadConversations();
    _setupSocket();
  }

  void clearState() {
    if (mounted) {
      state = const ChatState();
    }
  }

  @override
  void dispose() {
    final socket = _socket.socket;
    if (socket != null && socket.connected) {
      socket.off('new_message');
      socket.off('messages_read');
      socket.off('typing_start');
      socket.off('typing_stop');
    }
    super.dispose();
  }

  Future<void> loadConversations() async {
    const String cacheKey = 'chat_list_cache';

    final String? cachedDataString = _cacheBox.get(cacheKey);
    if (cachedDataString != null) {
      try {
        final List<dynamic> cachedList = jsonDecode(cachedDataString);
        _updateStateWithData(cachedList, isFromCache: true);
      } catch (e) {
        debugPrint("Chat Cache read error: $e");
      }
    } else if (state.conversations.isEmpty) {
      state = state.copyWith(isLoading: true);
    }

    final connectivityResult = await (Connectivity().checkConnectivity());
    bool isOffline = connectivityResult.contains(ConnectivityResult.none);
    
    if (isOffline) {
      debugPrint("🚫 Offline. Relying entirely on chat cache.");
      if (mounted && state.isLoading) state = state.copyWith(isLoading: false);
      return; 
    }

    try {
      final res = await _api.get('/api/chat');
      
      if (res['success'] == true) {
        final body = res['data'];
        List<dynamic> data = [];

        if (body is Map && body.containsKey('data')) {
           data = body['data'] is List ? body['data'] : [];
        } else if (body is List) {
           data = body;
        }

        await _cacheBox.put(cacheKey, jsonEncode(data));
        _updateStateWithData(data, isFromCache: false);
        
      } else {
        if (mounted && state.isLoading) state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      debugPrint("⚠️ Chat Load Error: $e");
      if (mounted && state.isLoading) state = state.copyWith(isLoading: false);
    }
  }

  void _updateStateWithData(List<dynamic> data, {required bool isFromCache}) {
    if (!mounted) return;

    final online = data.where((c) {
        try {
          if (c == null || c is! Map) return false; // ✅ Null safety check
          final mapC = Map<String, dynamic>.from(c);
          final other = _getOtherParticipant(mapC, state.myId);
          return other['isOnline'] == true;
        } catch (e) {
          debugPrint("❌ Parser Error: $e");
          return false;
        }
    }).take(10).toList();

    state = state.copyWith(
      conversations: data,
      filteredConversations: data,
      onlineUsers: online,
      isLoading: false
    );
    
    if (isFromCache) {
       debugPrint("⚡ Loaded ${data.length} chats instantly from cache.");
    } else {
       debugPrint("✅ Background sync complete: ${data.length} chats.");
    }
  }

  void searchConversations(String query) {
    if (query.isEmpty) {
      state = state.copyWith(filteredConversations: state.conversations);
    } else {
      final filtered = state.conversations.where((c) {
        try {
          if (c == null || c is! Map) return false;
          final mapC = Map<String, dynamic>.from(c);
          final other = _getOtherParticipant(mapC, state.myId);
          final name = (other['fullName'] ?? other['name'] ?? "").toString().toLowerCase();
          
          String lastMsgText = "";
          if (mapC['lastMessage'] is Map) {
            lastMsgText = mapC['lastMessage']['text'] ?? "";
          } else {
            lastMsgText = mapC['lastMessage'].toString();
          }
          
          return name.contains(query.toLowerCase()) || lastMsgText.toLowerCase().contains(query.toLowerCase());
        } catch (e) {
          return false;
        }
      }).toList();
      state = state.copyWith(filteredConversations: filtered);
    }
  }

  Future<void> deleteConversation(String id) async {
    try {
      final newConvs = state.conversations.where((c) => c != null && c is Map && c['_id'] != id).toList();
      state = state.copyWith(conversations: newConvs, filteredConversations: newConvs);
      
      await _cacheBox.put('chat_list_cache', jsonEncode(newConvs));
      await _api.delete('/api/chat/conversation/$id');
    } catch (_) {}
  }

  Future<bool> isFileDownloaded(String? fileName) async {
    if (fileName == null) return false;
    try {
      final dir = await getTemporaryDirectory();
      final safeFileName = fileName.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
      final file = File("${dir.path}/$safeFileName");
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  Future<void> downloadFile(String url, String fileName) async {
    debugPrint("📥 Downloading $fileName from $url");
  }

  void _setupSocket() {
    final socket = _socket.socket;
    if (socket == null) return;

    socket.on('new_message', (data) {
      if (!mounted) return;
      _handleIncomingMessage(data);
    });

    socket.on('messages_read', (data) {
      if (!mounted) return;
      final convId = data['conversationId'];
      final updated = List<dynamic>.from(state.conversations);
      final index = updated.indexWhere((c) => c != null && c is Map && c['_id'] == convId);
      if (index != -1) {
        updated[index] = Map.from(updated[index])..['unreadCount'] = 0;
        state = state.copyWith(conversations: updated, filteredConversations: updated);
        _cacheBox.put('chat_list_cache', jsonEncode(updated));
      }
    });

    socket.on('typing_start', (data) {
      if (mounted) {
        final newStatus = Map<String, bool>.from(state.typingStatus);
        newStatus[data['conversationId']] = true;
        state = state.copyWith(typingStatus: newStatus);
      }
    });

    socket.on('typing_stop', (data) {
      if (mounted) {
        final newStatus = Map<String, bool>.from(state.typingStatus);
        newStatus[data['conversationId']] = false;
        state = state.copyWith(typingStatus: newStatus);
      }
    });
  }

  void _handleIncomingMessage(dynamic data) {
    final convId = data['conversationId'];
    final updated = List<dynamic>.from(state.conversations);
    final index = updated.indexWhere((c) => c != null && c is Map && c['_id'] == convId);

    if (index != -1) {
      var chat = Map<String, dynamic>.from(updated.removeAt(index));
      chat['lastMessage'] = data['message']['text'] ?? "Media";
      chat['lastMessageAt'] = data['message']['createdAt'];
      
      if (data['message']['senderId'] != state.myId) {
        chat['unreadCount'] = (chat['unreadCount'] ?? 0) + 1;
      }

      updated.insert(0, chat);
      state = state.copyWith(conversations: updated, filteredConversations: updated);
      _cacheBox.put('chat_list_cache', jsonEncode(updated));
    } else {
      loadConversations();
    }
  }

  // ✅ UPDATED: Bulletproof null-safety for identifying participants
  Map<String, dynamic> _getOtherParticipant(Map<String, dynamic> conversation, String myId) {
    if (conversation['isGroup'] == true) {
      final group = conversation['groupId'];
      if (group is Map) {
        return {
          '_id': group['_id'] ?? '',
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
      return {'fullName': 'Unknown User', 'profilePicture': '', 'isOnline': false};
    }

    final other = participants.firstWhere(
      (p) {
        if (p == null) return false;
        if (p is Map) return p['_id'] != myId;
        return p.toString() != myId;
      },
      orElse: () => null,
    );
    
    if (other == null || other is! Map) {
      return {'fullName': 'Deleted User', 'profilePicture': '', 'isOnline': false};
    }
    
    return Map<String, dynamic>.from(other);
  }
}

final chatProvider = StateNotifierProvider.autoDispose<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});