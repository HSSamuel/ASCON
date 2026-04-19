import 'package:flutter/material.dart';

class PresenceFormatter {
  // Centralized standard colors for presence
  static const Color onlineColor = Color(0xFF4CAF50); // Material Green
  static const Color offlineColor = Colors.grey;

  /// Returns the standardized color based on presence.
  static Color getStatusColor(bool isOnline) {
    return isOnline ? onlineColor : offlineColor;
  }

  /// Returns a standardized string for the user's presence.
  static String getStatusText({
    required bool isOnline,
    String? lastSeen,
    bool isTyping = false,
    bool isGroup = false,
    String groupParticipants = "",
  }) {
    if (isGroup) return groupParticipants;
    if (isTyping) return "Typing...";
    if (isOnline) return "Online";
    
    if (lastSeen == null || lastSeen.isEmpty) return "Offline";

    try {
      final lastSeenDate = DateTime.parse(lastSeen).toLocal();
      final now = DateTime.now();
      final diff = now.difference(lastSeenDate);

      // Seconds
      if (diff.inSeconds < 60) return "Active just now";
      
      // Minutes
      if (diff.inMinutes < 60) {
        final m = diff.inMinutes;
        return "Last seen $m ${m == 1 ? 'min' : 'mins'} ago";
      }
      
      // Hours
      if (diff.inHours < 24) {
        final h = diff.inHours;
        return "Last seen $h ${h == 1 ? 'hr' : 'hrs'} ago";
      }
      
      // Days
      if (diff.inDays < 30) {
        final d = diff.inDays;
        return "Last seen $d ${d == 1 ? 'day' : 'days'} ago";
      }
      
      // Months
      if (diff.inDays < 365) {
        final months = (diff.inDays / 30).floor();
        return "Last seen $months ${months == 1 ? 'mo' : 'mos'} ago";
      }
      
      // Years
      final years = (diff.inDays / 365).floor();
      return "Last seen $years ${years == 1 ? 'yr' : 'yrs'} ago";
      
    } catch (e) {
      return "Offline";
    }
  }
}