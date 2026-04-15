import 'dart:typed_data'; 

enum MessageStatus { sending, sent, delivered, read, error }

class ChatMessage {
  final String id;
  final String senderId;
  final String? senderName; 
  final String? senderProfilePic; // ✅ Capture Sender Image
  String text; 
  final DateTime createdAt;
  
  final String type; // 'text', 'image', 'audio', 'file', 'poll'
  final String? fileUrl;
  final String? fileName;
  
  // Store file bytes for Web support
  final Uint8List? localBytes; 
  
  // Reply Data
  final String? replyToId;
  final String? replyToText;
  final String? replyToSenderName;
  final String? replyToType;
  
  bool isDeleted;
  bool isEdited;
  bool isRead; 
  MessageStatus status; 

  // ✅ NEW: Store Emoji Reactions
  List<dynamic> reactions;

  ChatMessage({
    required this.id,
    required this.senderId,
    this.senderName, 
    this.senderProfilePic, 
    required this.text,
    required this.createdAt,
    this.type = 'text',
    this.fileUrl,
    this.fileName,
    this.localBytes, 
    this.replyToId,
    this.replyToText,
    this.replyToSenderName,
    this.replyToType,
    this.isDeleted = false,
    this.isEdited = false,
    this.isRead = false,
    this.status = MessageStatus.sent,
    this.reactions = const [], // ✅ Initialize empty reactions by default
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    String? rId;
    String? rText;
    String? rSender;
    String? rType;

    if (json['replyTo'] != null) {
      if (json['replyTo'] is Map) {
        rId = json['replyTo']['_id'];
        rText = json['replyTo']['text'];
        rType = json['replyTo']['type'];
        if (json['replyTo']['sender'] is Map) {
           rSender = json['replyTo']['sender']['fullName'];
        }
      } else {
        rId = json['replyTo'].toString();
      }
    }

    return ChatMessage(
      id: json['_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: (json['sender'] is Map) ? json['sender']['_id'] : json['sender'] ?? '',
      senderName: (json['sender'] is Map) ? json['sender']['fullName'] : null,
      senderProfilePic: (json['sender'] is Map) ? json['sender']['profilePicture'] : null, // ✅ PARSE PIC
      text: json['text'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now(),
      type: json['type'] ?? 'text',
      fileUrl: json['fileUrl'],
      fileName: json['fileName'],
      replyToId: rId,
      replyToText: rText,
      replyToSenderName: rSender,
      replyToType: rType,
      isDeleted: json['isDeleted'] ?? false,
      isEdited: json['isEdited'] ?? false,
      isRead: json['isRead'] ?? false,
      status: _parseStatus(json['status'], json['isRead']), 
      // ✅ Parse reactions array from JSON safely
      reactions: json['reactions'] != null ? List<dynamic>.from(json['reactions']) : [],
    );
  }

  // ✅ Helper to parse status string to enum
  static MessageStatus _parseStatus(String? status, bool? isRead) {
    if (isRead == true || status == 'read') return MessageStatus.read;
    switch (status) {
      case 'delivered': return MessageStatus.delivered;
      case 'sent': return MessageStatus.sent;
      case 'read': return MessageStatus.read;
      default: return MessageStatus.sent;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'sender': senderId, 
      'senderName': senderName, 
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'type': type,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'replyTo': replyToId != null ? {
        '_id': replyToId,
        'text': replyToText,
        'type': replyToType,
        'sender': {'fullName': replyToSenderName}
      } : null,
      'isDeleted': isDeleted,
      'isEdited': isEdited,
      'isRead': isRead,
      'status': status.name,
      'reactions': reactions, // ✅ Convert to JSON
    };
  }
}

class ChatConversation {
  final String id;
  final String otherUserName;
  final String? otherUserImage;
  final String? otherUserId;
  final String lastMessage;
  final DateTime lastMessageTime;
  
  // Group Support
  final bool isGroup;
  final String? groupId; 

  bool isOnline;
  String? lastSeen;

  ChatConversation({
    required this.id,
    required this.otherUserName,
    this.otherUserImage,
    this.otherUserId,
    required this.lastMessage,
    required this.lastMessageTime,
    this.isGroup = false,
    this.groupId,
    this.isOnline = false,
    this.lastSeen,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json, String myUserId) {
    final bool isGroupChat = json['isGroup'] ?? false;
    
    String displayName;
    String? displayImage;
    String? targetId;
    String? grpId;

    if (isGroupChat) {
      displayName = json['groupName'] ?? 'Unknown Group';
      displayImage = json['groupIcon']; 
      grpId = (json['groupId'] is Map) ? json['groupId']['_id'] : json['groupId'];
      targetId = grpId; 
    } else {
      final participants = (json['participants'] as List?) ?? [];
      var otherUser = participants.firstWhere(
        (user) => user != null && user['_id'].toString() != myUserId, 
        orElse: () => null,
      );

      if (otherUser == null && participants.isNotEmpty) {
        otherUser = participants[0];
      }

      displayName = otherUser?['fullName'] ?? 'Alumni Member';
      displayImage = otherUser?['profilePicture'];
      targetId = otherUser?['_id'];
    }

    return ChatConversation(
      id: json['_id'] ?? '',
      otherUserName: displayName,
      otherUserImage: displayImage,
      otherUserId: targetId,
      lastMessage: json['lastMessage'] ?? (isGroupChat ? 'Group created' : 'Start a conversation'),
      lastMessageTime: DateTime.tryParse(json['lastMessageAt']?.toString() ?? '') ?? DateTime.now(),
      isGroup: isGroupChat,
      groupId: grpId,
      isOnline: false, 
      lastSeen: null,
    );
  }
}