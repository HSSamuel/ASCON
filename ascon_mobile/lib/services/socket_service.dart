import 'dart:async';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config.dart';
import '../config/storage_config.dart';

class SocketService with WidgetsBindingObserver {
  IO.Socket? socket;
  final _storage = StorageConfig.storage;
  String? _currentUserId;
  String? _connectedUserId; 

  final _userStatusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get userStatusStream => _userStatusController.stream;

  final _callEventsController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get callEvents => _callEventsController.stream;

  final _messageStatusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStatusStream => _messageStatusController.stream;

  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  SocketService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (socket != null && socket!.connected) return;

      _storage.read(key: "auth_token").then((token) {
        if (token != null && (socket == null || !socket!.connected)) {
          initSocket();
        }
      });
    }
  }

  IO.Socket? getSocket() {
    return socket;
  }

  Future<void> initSocket({String? userIdOverride}) async {
    String? token = await _storage.read(key: "auth_token");
    if (userIdOverride != null) {
      _currentUserId = userIdOverride;
    } else {
      _currentUserId = await _storage.read(key: "userId");
    }

    if (token == null || _currentUserId == null) return;

    String socketUrl = AppConfig.baseUrl;
    if (socketUrl.endsWith('/')) socketUrl = socketUrl.substring(0, socketUrl.length - 1);
    if (socketUrl.endsWith('/api')) socketUrl = socketUrl.replaceAll('/api', '');

    if (socket == null || _connectedUserId != _currentUserId) {
      if (socket != null) {
        socket!.disconnect();
        socket!.dispose();
      }

      debugPrint("🔌 Socket Connecting to: $socketUrl as User: $_currentUserId");

      socket = IO.io(socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'timeout': AppConfig.socketTimeoutMs,
        'reconnection': true,
        'reconnectionDelay': AppConfig.socketReconnectionDelayMs,
        'auth': {'token': token},
        'query': {'userId': _currentUserId},
      });

      _setupListeners();
      socket!.connect();
      _connectedUserId = _currentUserId;
    } else if (!socket!.connected) {
      socket!.connect();
    }
  }

  void _setupListeners() {
    if (socket == null) return;

    socket!.onConnect((_) {
      debugPrint('✅ Socket Connected');
      if (_currentUserId != null) {
        socket!.emit("user_connected", _currentUserId);
      }
    });

    socket!.onReconnect((_) {
      debugPrint('🔄 Socket Reconnected');
      if (_currentUserId != null) {
        socket!.emit("user_connected", _currentUserId);
      }
    });

    socket!.on('user_status_update', (data) {
      if (data != null) _userStatusController.add(Map<String, dynamic>.from(data));
    });

    socket!.on('user_status_result', (data) {
      if (data != null) _userStatusController.add(Map<String, dynamic>.from(data));
    });

    socket!.on('new_message', (data) {
      if (data != null && data['message'] != null && data['conversationId'] != null) {
        final msgId = data['message']['_id'] ?? data['message']['id'];
        final senderId = data['message']['sender'] is Map 
            ? data['message']['sender']['_id'] 
            : data['message']['sender'];

        if (senderId != _currentUserId) {
          markMessageAsDelivered(msgId, data['conversationId']);
        }
      }
    });

    socket!.on('messages_read_update', (data) {
       _messageStatusController.add({'type': 'read', 'data': data});
    });

    socket!.on('message_status_update', (data) {
       _messageStatusController.add({'type': 'status_update', 'data': data});
    });

    // --- NEW CALL LISTENERS ---
    socket!.on('incoming_call', (data) {
       _callEventsController.add({'type': 'incoming', 'data': data});
    });

    socket!.on('call_answered', (data) {
       _callEventsController.add({'type': 'answered', 'data': data});
    });

    socket!.on('call_ended', (data) {
       _callEventsController.add({'type': 'ended', 'data': data});
    });

    socket!.onDisconnect((_) => debugPrint('❌ Socket Disconnected'));
    socket!.onError((data) => debugPrint('⚠️ Socket Error: $data'));
  }

  void markMessagesAsRead(String chatId, List<String> messageIds, String userId) {
    if (socket != null && socket!.connected) {
      socket!.emit('mark_messages_read', {
        'chatId': chatId,
        'messageIds': messageIds,
        'userId': userId,
      });
    }
  }

  void markMessageAsDelivered(String messageId, String chatId) {
    if (socket != null && socket!.connected) {
      socket!.emit('message_delivered', {
        'messageId': messageId,
        'chatId': chatId,
      });
    }
  }

  // --- NEW CALL METHODS ---
  void initiateCall(String targetUserId, String channelName, Map<String, dynamic> callerData) {
    if (socket != null && socket!.connected) {
      socket!.emit('initiate_call', {
        'targetUserId': targetUserId,
        'channelName': channelName,
        'callerData': callerData
      });
    }
  }

  void answerCall(String targetUserId, String channelName) {
    if (socket != null && socket!.connected) {
      socket!.emit('answer_call', {'targetUserId': targetUserId, 'channelName': channelName});
    }
  }

  void endCall(String targetUserId, String channelName) {
    if (socket != null && socket!.connected) {
      socket!.emit('end_call', {'targetUserId': targetUserId, 'channelName': channelName});
    }
  }

  void checkUserStatus(String targetUserId) {
    if (socket != null && socket!.connected) {
      socket!.emit("check_user_status", {'userId': targetUserId});
    }
  }

  void connectUser(String userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      initSocket(userIdOverride: userId);
    }
  }

  void logoutUser() {
    if (socket != null && _currentUserId != null) {
      socket!.emit('user_logout', _currentUserId);
      Future.delayed(const Duration(milliseconds: 100), () {
        disconnect();
        _currentUserId = null;
      });
    } else {
      disconnect();
      _currentUserId = null;
    }
  }

  void disconnect() {
    if (socket != null) {
      socket!.disconnect();
      socket = null;
      _connectedUserId = null;
    }
  }
}