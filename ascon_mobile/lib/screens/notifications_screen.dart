import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/api_client.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiClient _api = ApiClient();
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  // ✅ GET: Fetch notifications from backend
  Future<void> _fetchNotifications() async {
    try {
      final res = await _api.get('/api/notifications');
      if (mounted) {
        setState(() {
          if (res['success'] == true && res['data'] is List) {
            _notifications = res['data'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ DELETE SINGLE: Swipe to remove
  Future<void> _deleteNotification(String id, int index) async {
    // Optimistic Update
    final removed = _notifications[index];
    setState(() {
      _notifications.removeAt(index);
    });

    try {
      await _api.delete('/api/notifications/$id');
    } catch (e) {
      // Revert if failed
      if (mounted) {
        setState(() {
          _notifications.insert(index, removed);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete notification")),
        );
      }
    }
  }

  // ✅ CLEAR ALL: Button in AppBar
  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear All?"),
        content: const Text("This will permanently remove all your notifications."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Clear", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _api.delete('/api/notifications/clear/all');
        setState(() {
          _notifications.clear();
          _isLoading = false;
        });
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to clear notifications")),
          );
        }
      }
    }
  }

  // ✅ MARK READ: When tapped
  Future<void> _markAsRead(String id, int index) async {
    if (_notifications[index]['isRead'] == true) return;

    setState(() {
      _notifications[index]['isRead'] = true;
    });

    try {
      await _api.put('/api/notifications/read/$id', {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Notifications", style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).cardColor,
        foregroundColor: textColor,
        elevation: 0.5,
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text("Clear All", style: TextStyle(color: Colors.red)),
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text("No notifications yet", style: GoogleFonts.lato(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _notifications.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _notifications[index];
                      final bool isRead = item['isRead'] == true;
                      final date = DateTime.tryParse(item['createdAt'].toString()) ?? DateTime.now();

                      return Dismissible(
                        key: Key(item['_id']),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) => _deleteNotification(item['_id'], index),
                        child: InkWell(
                          onTap: () => _markAsRead(item['_id'], index),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isRead 
                                  ? (isDark ? Colors.grey[900] : Colors.white) 
                                  : (isDark ? Colors.grey[800] : Colors.blue.withOpacity(0.05)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isRead ? Colors.transparent : Colors.blue.withOpacity(0.2),
                              ),
                              boxShadow: isRead ? [] : [
                                BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))
                              ]
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isRead ? Colors.grey.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.notifications, 
                                    size: 20, 
                                    color: isRead ? Colors.grey : Colors.blue
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['title'] ?? "Notification",
                                        style: GoogleFonts.lato(
                                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                          fontSize: 15,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item['message'] ?? "",
                                        style: GoogleFonts.lato(
                                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        timeago.format(date),
                                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    margin: const EdgeInsets.only(top: 8, left: 8),
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}