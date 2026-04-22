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
  /// Accepts dynamic lastSeen to handle both ints (epoch) and Strings (ISO).
  static String getStatusText({
    required bool isOnline,
    dynamic lastSeen, 
    bool isTyping = false,
    bool isGroup = false,
    String groupParticipants = "",
  }) {
    if (isGroup) return groupParticipants;
    if (isTyping) return "Typing...";
    if (isOnline) return "Online";
    
    // Prevent literal "null" strings or empty values from breaking the parser
    if (lastSeen == null || lastSeen.toString().isEmpty || lastSeen.toString() == "null") {
      return "Offline";
    }

    try {
      DateTime lastSeenDate;

      // Handle if backend sends milliseconds since epoch (int)
      if (lastSeen is int) {
        lastSeenDate = DateTime.fromMillisecondsSinceEpoch(lastSeen).toLocal();
      } else {
        // Handle standard ISO string
        lastSeenDate = DateTime.parse(lastSeen.toString()).toLocal();
      }

      final now = DateTime.now();
      final diff = now.difference(lastSeenDate);

      // Handle negative diffs (caused by slight server-client clock desync)
      if (diff.isNegative || diff.inSeconds < 60) {
        return "Active just now";
      }
      
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
      // ✅ Now you will see exactly what broke it in your terminal
      debugPrint("⚠️ PresenceFormatter failed to parse lastSeen: '$lastSeen'. Error: $e");
      return "Offline"; 
    }
  }
}