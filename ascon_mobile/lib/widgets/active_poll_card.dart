import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart'; 

class ActivePollCard extends StatefulWidget {
  final String? groupId; 

  const ActivePollCard({super.key, this.groupId});

  @override
  State<ActivePollCard> createState() => _ActivePollCardState();
}

class _ActivePollCardState extends State<ActivePollCard> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _poll;
  bool _isLoading = true;
  String? _myUserId;
  bool _hasVoted = false;
  
  // ✅ NEW: Collapsible State
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadPoll();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    final socket = SocketService().socket;
    if (socket == null) return;

    socket.on('poll_created', (data) {
      if (!mounted) return;
      final newPoll = data['poll'];
      if (widget.groupId != null && newPoll['group'] == widget.groupId) {
        setState(() {
          _poll = newPoll;
          _hasVoted = false;
          _isExpanded = true; // Auto-expand new polls
        });
      }
    });

    socket.on('poll_updated', (data) {
      if (!mounted) return;
      if (_poll != null && data['pollId'] == _poll!['_id']) {
        setState(() {
          _poll = data['updatedPoll'];
          if (_poll != null && _myUserId != null) {
            final List votedUsers = _poll!['votedUsers'] ?? [];
            _hasVoted = votedUsers.contains(_myUserId);
          }
        });
      }
    });

    socket.on('poll_deleted', (data) {
      if (!mounted) return;
      if (_poll != null && data['pollId'] == _poll!['_id']) {
        setState(() => _poll = null);
        _loadPoll(); 
      }
    });
  }

  Future<void> _loadPoll() async {
    final userId = await AuthService().currentUserId;
    
    List<dynamic> polls;
    if (widget.groupId != null) {
      polls = await DataService().fetchGroupPolls(widget.groupId!);
    } else {
      polls = await DataService().fetchPolls();
    }
    
    if (mounted) {
      setState(() {
        _myUserId = userId;
        _poll = (polls.isNotEmpty) ? polls.first : null;
        _isLoading = false;
        
        if (_poll != null && _myUserId != null) {
          final List votedUsers = _poll!['votedUsers'] ?? [];
          if (votedUsers.contains(_myUserId)) {
            _hasVoted = true;
            _isExpanded = false; // ✅ Auto-collapse if already voted
          }
        }
      });
    }
  }

  Future<void> _vote(String optionId) async {
    if (_poll == null) return;
    
    setState(() {
      _hasVoted = true;
      final options = _poll!['options'] as List;
      final optIndex = options.indexWhere((o) => o['_id'] == optionId);
      if (optIndex != -1) {
        int currentCount = options[optIndex]['voteCount'] ?? 0;
        options[optIndex]['voteCount'] = currentCount + 1;
      }
    });
    
    await DataService().votePoll(_poll!['_id'], optionId);

    // ✅ UX IMPROVEMENT: Auto-collapse after voting to clear space
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _isExpanded = false);
      }
    });
  }

  Future<void> _deletePoll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Poll"),
        content: const Text("Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("Delete")),
        ],
      )
    );

    if (confirm == true && _poll != null) {
      setState(() => _isLoading = true);
      await DataService().deletePoll(_poll!['_id']);
      if (mounted) _loadPoll(); 
    }
  }

  Future<void> _editPoll() async {
    final ctrl = TextEditingController(text: _poll!['question']);
    final newQuestion = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Question"),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Question"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text("Save"),
          ),
        ],
      )
    );

    if (newQuestion != null && newQuestion.isNotEmpty && newQuestion != _poll!['question']) {
      setState(() => _isLoading = true);
      await DataService().updatePollQuestion(_poll!['_id'], newQuestion);
      if (mounted) _loadPoll();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _poll == null) return const SizedBox.shrink();

    final question = _poll!['question'];
    final List options = _poll!['options'];
    final int totalVotes = options.fold(0, (sum, item) => sum + (item['voteCount'] ?? 0) as int);
    final bool isCreator = _poll!['createdBy'] == _myUserId;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. PINNED HEADER (Always Visible)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Row(
              children: [
                const Icon(Icons.bar_chart_rounded, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isExpanded ? "Active Poll" : question, // Show question in header if collapsed
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lato(
                      fontSize: 14, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.blue[800]
                    )
                  ),
                ),
                
                if (isCreator)
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'edit') _editPoll();
                      if (val == 'delete') _deletePoll();
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Edit")])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
                    ],
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.more_horiz, color: Colors.grey, size: 20),
                  )
                else
                  Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey),
              ],
            ),
          ),

          // 2. EXPANDABLE CONTENT
          if (_isExpanded) ...[
            const SizedBox(height: 12),
            Text(question, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            
            ...options.map((opt) {
              final int votes = opt['voteCount'] ?? 0;
              final double percent = totalVotes == 0 ? 0 : votes / totalVotes;
              
              if (_hasVoted) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(opt['text'], style: const TextStyle(fontSize: 13)),
                          Text("${(percent * 100).toStringAsFixed(0)}%", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 6,
                          backgroundColor: Colors.grey[100],
                          color: Colors.blueAccent,
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: InkWell(
                    onTap: () => _vote(opt['_id']),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.radio_button_unchecked, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(child: Text(opt['text'], style: const TextStyle(fontSize: 14))),
                        ],
                      ),
                    ),
                  ),
                );
              }
            }),
            
            if (_hasVoted)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text("$totalVotes votes", style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
          ]
        ],
      ),
    );
  }
}