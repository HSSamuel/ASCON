import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart'; // ✅ NEW: Socket Import

class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key});

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  final DataService _dataService = DataService();
  List<dynamic> _polls = [];
  bool _isLoading = true;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupSocketListeners(); // ✅ Initialize Socket
  }

  // ✅ NEW: Listen for real-time votes
  void _setupSocketListeners() {
    final socket = SocketService().getSocket();
    
    // ✅ FIX: Check if socket is null before using it
    if (socket == null) return;
    
    socket.on('poll_updated', (data) {
      if (!mounted) return;
      
      setState(() {
        final updatedPoll = data['updatedPoll'];
        // Find the poll in our list and replace it
        final index = _polls.indexWhere((p) => p['_id'] == updatedPoll['_id']);
        if (index != -1) {
          _polls[index] = updatedPoll;
        } else {
          // If it's a new poll entirely, add it to the top
          _polls.insert(0, updatedPoll);
        }
      });
    });
  }

  Future<void> _loadData() async {
    final userId = await AuthService().currentUserId;
    final polls = await _dataService.fetchPolls();
    if (mounted) {
      setState(() {
        _myUserId = userId;
        _polls = polls;
        _isLoading = false;
      });
    }
  }

  Future<void> _vote(String pollId, String optionId) async {
    // Optimistic Update
    setState(() {
      final pollIndex = _polls.indexWhere((p) => p['_id'] == pollId);
      if (pollIndex != -1) {
        final optIndex = _polls[pollIndex]['options'].indexWhere((o) => o['_id'] == optionId);
        if (optIndex != -1) {
           // Increment count locally (will be overwritten by socket update shortly)
           int currentCount = _polls[pollIndex]['options'][optIndex]['voteCount'] ?? 0;
           _polls[pollIndex]['options'][optIndex]['voteCount'] = currentCount + 1;
           
           // Also add to votedUsers locally to disable button immediately
           List votedUsers = _polls[pollIndex]['votedUsers'] ?? [];
           if (_myUserId != null) votedUsers.add(_myUserId);
           _polls[pollIndex]['votedUsers'] = votedUsers;
        }
      }
    });

    await _dataService.votePoll(pollId, optionId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Polls & Voting", style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _polls.isEmpty
              ? const Center(child: Text("No active polls."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _polls.length,
                  itemBuilder: (context, index) => _buildPollCard(_polls[index]),
                ),
    );
  }

  Widget _buildPollCard(Map<String, dynamic> poll) {
    final List options = poll['options'];
    
    // Calculate Total Votes using the new 'voteCount' field
    final int totalVotes = options.fold(0, (sum, item) => sum + (item['voteCount'] ?? 0) as int);

    // Check participation via 'votedUsers' array
    final List votedUsers = poll['votedUsers'] ?? [];
    final bool hasUserVoted = votedUsers.contains(_myUserId);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(poll['question'], style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("$totalVotes Votes", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const Divider(),
            ...options.map((opt) {
              final int votes = opt['voteCount'] ?? 0;
              final double percent = totalVotes == 0 ? 0 : votes / totalVotes;
              
              return InkWell(
                onTap: hasUserVoted ? null : () => _vote(poll['_id'], opt['_id']),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.transparent),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(opt['text'], style: const TextStyle(fontWeight: FontWeight.normal)),
                          if (hasUserVoted)
                            const SizedBox.shrink(), 
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Only show results if user has voted
                      if (hasUserVoted) ...[
                        LinearProgressIndicator(value: percent, backgroundColor: Colors.grey[300], color: Theme.of(context).primaryColor),
                        const SizedBox(height: 4),
                        Text("${(percent * 100).toStringAsFixed(1)}% ($votes votes)", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ]
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}