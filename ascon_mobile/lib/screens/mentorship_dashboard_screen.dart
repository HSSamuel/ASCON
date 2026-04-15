import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/data_service.dart';
import 'chat_screen.dart'; // To open chats

class MentorshipDashboardScreen extends StatefulWidget {
  const MentorshipDashboardScreen({super.key});

  @override
  State<MentorshipDashboardScreen> createState() => _MentorshipDashboardScreenState();
}

class _MentorshipDashboardScreenState extends State<MentorshipDashboardScreen> with SingleTickerProviderStateMixin {
  final DataService _dataService = DataService();
  late TabController _tabController;
  bool _isLoading = true;
  
  Map<String, dynamic> _data = {
    'received': [], // Requests I need to accept/reject
    'sent': [],     // Requests I sent
    'activeMentors': [],
    'activeMentees': []
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final res = await _dataService.getMentorshipDashboard();
    if (mounted) {
      setState(() {
        if (res != null) _data = res;
        _isLoading = false;
      });
    }
  }

  Future<void> _respond(String requestId, String status) async {
    // Optimistic Update
    setState(() {
      _isLoading = true;
    });

    final success = await _dataService.respondToMentorshipRequest(requestId, status);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == "Accepted" ? "Request Accepted!" : "Request Declined"),
        backgroundColor: status == "Accepted" ? Colors.green : Colors.grey,
      ));
      _loadDashboard(); // Refresh
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Action failed.")));
    }
  }

  // ✅ HELPER: End Mentorship Logic
  Future<void> _endMentorship(String requestId, String userName) async {
    final confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("End Mentorship?"),
        content: Text("Are you sure you want to end your mentorship with $userName?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("End", style: TextStyle(color: Colors.red))),
        ],
      )
    );
    
    if (confirm == true) {
      setState(() => _isLoading = true);
      await _dataService.deleteMentorshipInteraction(requestId, 'end');
      _loadDashboard(); // Refresh list
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text("Mentorship Program", style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Requests"),
            Tab(text: "My Network"),
          ],
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRequestsTab(),
                _buildNetworkTab(),
              ],
            ),
    );
  }

  Widget _buildRequestsTab() {
    final received = _data['received'] as List;
    final sent = _data['sent'] as List;

    if (received.isEmpty && sent.isEmpty) {
      return _buildEmptyState("No pending requests.");
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (received.isNotEmpty) ...[
          Text("Requests Received", style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[700])),
          const SizedBox(height: 10),
          ...received.map((req) => _buildRequestCard(req, isReceived: true)),
          const SizedBox(height: 20),
        ],

        if (sent.isNotEmpty) ...[
          Text("Requests Sent", style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[700])),
          const SizedBox(height: 10),
          ...sent.map((req) => _buildRequestCard(req, isReceived: false)),
        ],
      ],
    );
  }

  Widget _buildRequestCard(dynamic req, {required bool isReceived}) {
    final user = isReceived ? req['mentee'] : req['mentor'];
    final String name = user['fullName'] ?? 'Unknown';
    final String job = user['jobTitle'] ?? '';
    final String img = user['profilePicture'] ?? '';
    final String pitch = req['pitch'] ?? 'No message provided.';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: (img.isNotEmpty) ? CachedNetworkImageProvider(img) : null,
                  child: img.isEmpty ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      if (job.isNotEmpty) Text(job, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                if (!isReceived)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(4)),
                    child: const Text("Pending", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                  )
              ],
            ),
            const Divider(height: 20),
            Text("Pitch:", style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)),
            Text(pitch, style: const TextStyle(fontSize: 14)),
            
            if (isReceived) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _respond(req['_id'], "Rejected"),
                    child: const Text("Decline", style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => _respond(req['_id'], "Accepted"),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E3A), foregroundColor: Colors.white),
                    child: const Text("Accept"),
                  ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkTab() {
    final mentors = _data['activeMentors'] as List;
    final mentees = _data['activeMentees'] as List;

    if (mentors.isEmpty && mentees.isEmpty) {
      return _buildEmptyState("You don't have any active mentorships yet.");
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (mentors.isNotEmpty) ...[
          Text("My Mentors", style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[700])),
          const SizedBox(height: 10),
          // ✅ PASS REQUEST ID to build card
          ...mentors.map((m) => _buildConnectionCard(m['mentor'], "Mentor", m['_id'])),
          const SizedBox(height: 20),
        ],

        if (mentees.isNotEmpty) ...[
          Text("My Mentees", style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[700])),
          const SizedBox(height: 10),
          // ✅ PASS REQUEST ID to build card
          ...mentees.map((m) => _buildConnectionCard(m['mentee'], "Mentee", m['_id'])),
        ],
      ],
    );
  }

  // ✅ UPDATED: Now accepts `requestId` to allow End Mentorship
  Widget _buildConnectionCard(dynamic user, String role, String requestId) {
    return ListTile(
      contentPadding: const EdgeInsets.all(0),
      leading: CircleAvatar(
        backgroundImage: (user['profilePicture'] != null && user['profilePicture'].isNotEmpty) 
            ? CachedNetworkImageProvider(user['profilePicture']) 
            : null,
        child: (user['profilePicture'] == null || user['profilePicture'].isEmpty) 
            ? const Icon(Icons.person) 
            : null,
      ),
      title: Text(user['fullName'] ?? 'Unknown'),
      subtitle: Text(role, style: const TextStyle(color: Colors.grey)),
      
      // ✅ UPDATED TRAILING: Popup Menu for Chat/End
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'chat') {
             Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                receiverId: user['_id'],
                receiverName: user['fullName'],
                receiverProfilePic: user['profilePicture'],
             )));
          } else if (value == 'end') {
             _endMentorship(requestId, user['fullName'] ?? 'User');
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'chat', child: Row(children: [Icon(Icons.chat, size: 18), SizedBox(width: 8), Text("Chat")])),
          const PopupMenuItem(value: 'end', child: Row(children: [Icon(Icons.block, size: 18, color: Colors.red), SizedBox(width: 8), Text("End Mentorship", style: TextStyle(color: Colors.red))])),
        ],
        icon: const Icon(Icons.more_vert, color: Colors.grey),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(msg, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}