import 'package:intl/intl.dart';

class PresenceFormatter {
  static String format(String? dateString, {bool isOnline = false}) {
    if (isOnline) return "Online";
    if (dateString == null || dateString.isEmpty) return "Offline";

    try {
      final lastSeen = DateTime.parse(dateString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(lastSeen);

      // Seconds
      if (diff.inSeconds < 60) {
        return "Active just now";
      }
      // Minutes
      if (diff.inMinutes < 60) {
        return "${diff.inMinutes}m ago";
      }
      // Hours
      if (diff.inHours < 24) {
        return "${diff.inHours}h ago";
      }
      // Days
      if (diff.inDays < 30) {
        return "${diff.inDays}d ago";
      }
      // Months
      if (diff.inDays < 365) {
        final months = (diff.inDays / 30).floor();
        return "${months}mo ago";
      }
      
      // Years
      final years = (diff.inDays / 365).floor();
      return "${years}y ago";
      
    } catch (e) {
      return "Offline";
    }
  }
}