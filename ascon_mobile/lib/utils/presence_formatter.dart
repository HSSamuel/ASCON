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
        final m = diff.inMinutes;
        return "$m ${m == 1 ? 'min' : 'mins'} ago";
      }
      
      // Hours
      if (diff.inHours < 24) {
        final h = diff.inHours;
        return "$h ${h == 1 ? 'hr' : 'hrs'} ago";
      }
      
      // Days
      if (diff.inDays < 30) {
        final d = diff.inDays;
        return "$d ${d == 1 ? 'day' : 'days'} ago";
      }
      
      // Months
      if (diff.inDays < 365) {
        final months = (diff.inDays / 30).floor();
        return "$months ${months == 1 ? 'mo' : 'mos'} ago";
      }
      
      // Years
      final years = (diff.inDays / 365).floor();
      return "$years ${years == 1 ? 'yr' : 'yrs'} ago";
      
    } catch (e) {
      return "Offline";
    }
  }
}