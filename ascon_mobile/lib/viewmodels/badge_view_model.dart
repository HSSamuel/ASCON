import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../services/call_history_service.dart';
import '../services/socket_service.dart';
import '../services/auth_service.dart';

class BadgeState {
  final bool hasUnreadMessages;
  final int missedCallsCount;

  BadgeState({this.hasUnreadMessages = false, this.missedCallsCount = 0});

  BadgeState copyWith({bool? hasUnreadMessages, int? missedCallsCount}) {
    return BadgeState(
      hasUnreadMessages: hasUnreadMessages ?? this.hasUnreadMessages,
      missedCallsCount: missedCallsCount ?? this.missedCallsCount,
    );
  }
}

class BadgeViewModel extends StateNotifier<BadgeState> {
  final ApiClient _api = ApiClient();
  final CallHistoryService _callService = CallHistoryService();
  String? _currentUserId;

  BadgeViewModel() : super(BadgeState()) {
    _init();
  }

  Future<void> _init() async {
    _currentUserId = await AuthService().currentUserId;
    await refreshBadges();
    _listenToSockets();
  }

  Future<void> refreshBadges() async {
    try {
      // 1. Fetch unread messages
      final msgResult = await _api.get('/api/chat/unread-status');
      bool hasUnread = false;
      if (msgResult['success'] == true) {
        hasUnread = msgResult['data']?['hasUnread'].toString().toLowerCase() == 'true';
      }

      // 2. Fetch missed calls
      final missedCalls = await _callService.getUnreadMissedCallsCount();

      state = state.copyWith(
        hasUnreadMessages: hasUnread,
        missedCallsCount: missedCalls,
      );
    } catch (e) {
      debugPrint("Badge refresh error: $e");
    }
  }

  void _listenToSockets() {
    final socket = SocketService().socket;
    if (socket == null) return;

    socket.on('new_message', (data) {
      if (data != null && data['message'] != null) {
        final senderId = data['message']['sender'] is Map 
            ? data['message']['sender']['_id'] 
            : data['message']['sender'];
        if (senderId == _currentUserId) return; 
      }
      state = state.copyWith(hasUnreadMessages: true);
    });

    socket.on('messages_read', (_) => refreshBadges());
    socket.on('connect', (_) => refreshBadges());
  }

  void clearMessageBadge() {
    state = state.copyWith(hasUnreadMessages: false);
  }
}

final badgeProvider = StateNotifierProvider<BadgeViewModel, BadgeState>((ref) {
  return BadgeViewModel();
});