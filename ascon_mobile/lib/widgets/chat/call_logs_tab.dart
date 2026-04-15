import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 

import '../../viewmodels/profile_view_model.dart'; 
import '../../services/api_client.dart';
import '../../services/socket_service.dart';
import '../../screens/call_screen.dart';
import '../../screens/call_log_detail_screen.dart';

class CallLogsTab extends ConsumerStatefulWidget {
  const CallLogsTab({super.key});

  @override
  ConsumerState<CallLogsTab> createState() => _CallLogsTabState();
}

class _CallLogsTabState extends ConsumerState<CallLogsTab> {
  final ApiClient _api = ApiClient();
  final SocketService _socketService = SocketService();
  
  bool _isLoading = true;
  List<dynamic> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _setupSocketListeners(); 
  }

  void _setupSocketListeners() {
    _socketService.callEvents.listen((event) {
      if (!mounted) return;
      if (event['type'] == 'call_ended_remote' || 
          event['type'] == 'call_failed' || 
          event['type'] == 'call_log_generated') {
        Future.delayed(const Duration(seconds: 1), _fetchLogs);
      }
    });
  }

  Future<void> _fetchLogs() async {
    if (!mounted) return;
    if (_logs.isEmpty) setState(() => _isLoading = true);

    try {
      final res = await _api.get('/api/calls');
      
      if (res['success'] == true) {
        final serverResponse = res['data']; 

        if (serverResponse is Map && serverResponse['data'] is List) {
          if (mounted) {
            setState(() {
              _logs = serverResponse['data'];
              _isLoading = false;
            });
          }
        } else if (serverResponse is List) {
          if (mounted) {
            setState(() {
              _logs = serverResponse;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteLog(String id) async {
    try {
      setState(() {
        _logs.removeWhere((l) => l['_id'] == id);
      });
      await _api.delete('/api/calls/$id');
    } catch (e) {
      _fetchLogs(); 
    }
  }

  List<Map<String, dynamic>> _groupConsecutiveLogs(List<dynamic> logs) {
    if (logs.isEmpty) return [];

    List<Map<String, dynamic>> grouped = [];
    List<dynamic> currentGroup = [logs[0]];

    for (int i = 1; i < logs.length; i++) {
      final current = logs[i];
      final previous = logs[i - 1];

      final currentRemote = current['remoteId'];
      final previousRemote = previous['remoteId'];

      if (currentRemote != null && currentRemote == previousRemote) {
        currentGroup.add(current);
      } else {
        grouped.add({
          'primary': currentGroup.first, 
          'count': currentGroup.length,
          'logs': List.from(currentGroup),
        });
        currentGroup = [current];
      }
    }
    
    grouped.add({
      'primary': currentGroup.first,
      'count': currentGroup.length,
      'logs': List.from(currentGroup),
    });

    return grouped;
  }

  void _openLogDetails(Map<String, dynamic> log) {
    final userLogs = _logs.where((l) => l['remoteId'] == log['remoteId']).toList();
    final strictLogs = userLogs.map((e) => Map<String, dynamic>.from(e)).toList();

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CallLogDetailScreen(
        name: log['remoteName'] ?? "Unknown",
        avatar: log['remotePic'],
        callerId: log['remoteId'], 
        logs: strictLogs,
      )
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text("No call history", style: GoogleFonts.lato(color: Colors.grey)),
          ],
        ),
      );
    }

    final groupedLogs = _groupConsecutiveLogs(_logs);

    return RefreshIndicator(
      onRefresh: _fetchLogs,
      child: ListView.separated(
        itemCount: groupedLogs.length,
        separatorBuilder: (c, i) => Divider(height: 1, indent: 70, color: Colors.grey.withOpacity(0.1)),
        itemBuilder: (context, index) {
          final group = groupedLogs[index];
          final log = group['primary']; 
          final int count = group['count'];
          
          final String type = log['type'] ?? 'dialed'; 
          // ✅ Read callType from DB
          final String callType = log['callType'] ?? 'voice'; 
          
          return Dismissible(
            key: Key(log['_id']), 
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) => _deleteLog(log['_id']),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onTap: () => _openLogDetails(log),
              leading: _buildAvatar(log['remotePic'], log['remoteName']),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      log['remoteName'] ?? "Unknown",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lato(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: type == 'missed' ? Colors.red : Theme.of(context).textTheme.bodyLarge?.color
                      ),
                    ),
                  ),
                  if (count > 1) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "($count)",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Row(
                children: [
                  // ✅ Dynamic Icon based on Voice/Video
                  Icon(_getIcon(type, callType), color: _getIconColor(type), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(log['createdAt']), 
                    style: const TextStyle(fontSize: 12, color: Colors.grey)
                  ),
                  if (log['duration'] != null && log['duration'] > 0)
                    Text(
                      " • ${_formatDuration(log['duration'])}", 
                      style: const TextStyle(fontSize: 12, color: Colors.grey)
                    ),
                ],
              ),
              trailing: IconButton(
                // ✅ Dynamic Trailing Icon (Phone vs Video)
                icon: Icon(callType == 'video' ? Icons.videocam : Icons.call, color: Colors.green),
                onPressed: () {
                  final userProfile = ref.read(profileProvider).userProfile;
                  final currentUserName = userProfile?['fullName'] ?? "Alumni User";
                  final currentUserAvatar = userProfile?['profilePicture'];

                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CallScreen(
                      remoteName: log['remoteName'] ?? "Unknown",
                      remoteId: log['remoteId'],                  
                      remoteAvatar: log['remotePic'],
                      channelName: "call_${DateTime.now().millisecondsSinceEpoch}",
                      isIncoming: false,
                      // ✅ Set to true if redialing a video call
                      isVideoCall: callType == 'video', 
                      currentUserName: currentUserName,           
                      currentUserAvatar: currentUserAvatar,       
                    )
                  ));
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar(String? url, String? name) {
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: 24,
          backgroundImage: imageProvider,
          backgroundColor: Colors.grey[200],
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[200],
          child: const Icon(Icons.person, color: Colors.grey),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[200],
          child: Text(
            (name ?? "?").substring(0, 1).toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey[200],
      child: Text(
        (name ?? "?").substring(0, 1).toUpperCase(),
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600]),
      ),
    );
  }

  // ✅ Updated Icon Logic to handle Video
  IconData _getIcon(String type, String callType) {
    if (callType == 'video') {
      switch (type) {
        case 'missed': return Icons.missed_video_call;
        case 'dialed': return Icons.videocam_outlined;
        case 'received': return Icons.videocam;
        default: return Icons.videocam;
      }
    } else {
      switch (type) {
        case 'missed': return Icons.call_missed;
        case 'dialed': return Icons.call_made;
        case 'received': return Icons.call_received;
        default: return Icons.call;
      }
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'missed': return Colors.red;
      case 'dialed': return Colors.blue;
      case 'received': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return "";
    try {
      final date = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      
      if (now.difference(date).inDays == 0 && now.day == date.day) {
        return DateFormat('h:mm a').format(date);
      } else if (now.difference(date).inDays == 1) {
        return "Yesterday";
      }
      return DateFormat('MMM d').format(date);
    } catch (e) {
      return "";
    }
  }

  String _formatDuration(dynamic duration) {
    int seconds = 0;
    if (duration is int) seconds = duration;
    if (duration is double) seconds = duration.toInt();

    final d = Duration(seconds: seconds);
    if (d.inMinutes > 0) {
      return "${d.inMinutes}m ${d.inSeconds % 60}s";
    }
    return "${d.inSeconds}s";
  }
}