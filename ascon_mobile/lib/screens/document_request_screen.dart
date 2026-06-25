import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';

class DocumentRequestScreen extends StatefulWidget {
  const DocumentRequestScreen({super.key});

  @override
  State<DocumentRequestScreen> createState() => _DocumentRequestScreenState();
}

class _DocumentRequestScreenState extends State<DocumentRequestScreen> {
  final ApiClient _api = ApiClient();
  bool _isLoading = true;
  List<dynamic> _requests = [];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    try {
      final result = await _api.get('/api/documents/my');
      
      if (result is Map && result['success'] == true && result['data'] is List) {
         if (mounted) {
          setState(() {
            _requests = result['data'];
            _isLoading = false;
          });
        }
      } else if (result is List) {
        if (mounted) {
          setState(() {
            _requests = result;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching docs: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ DELETE FUNCTION
  Future<void> _deleteRequest(String id) async {
    // 1. Confirm Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Request?"),
        content: const Text("Are you sure you want to remove this request? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 2. Call API
    try {
      setState(() => _isLoading = true);
      // Ensure your ApiClient has a generic delete method, or use http directly if not.
      // Assuming ApiClient has: Future<dynamic> delete(String endpoint)
      await _api.delete('/api/documents/$id');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Request deleted successfully"),
          backgroundColor: Colors.red,
        ));
        _fetchRequests(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete failed: $e")));
      }
    }
  }

  void _showCreateDialog() {
    String selectedType = "Transcript";
    final TextEditingController detailsCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("New Request", style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                items: ["Transcript", "Certificate", "Reference Letter", "Statement of Result"]
                    .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setDialogState(() => selectedType = v!),
                decoration: const InputDecoration(labelText: "Document Type"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: detailsCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Details (e.g. Delivery Address)",
                  border: OutlineInputBorder(),
                  hintText: "Enter delivery address or specific instructions...",
                  hintStyle: TextStyle(fontSize: 12)
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                if (detailsCtrl.text.isEmpty) return;
                
                setDialogState(() => isSubmitting = true);
                try {
                  await _api.post('/api/documents', {
                    'type': selectedType,
                    'details': detailsCtrl.text,
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    _fetchRequests(); // Refresh list
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request submitted successfully")));
                  }
                } catch (e) {
                  setDialogState(() => isSubmitting = false);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to submit request")));
                }
              },
              child: isSubmitting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending': return Colors.orange;
      case 'Processing': return Colors.blue;
      case 'Ready': return Colors.purple;
      case 'Delivered': return Colors.green;
      case 'Rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    
    return Scaffold(
      appBar: AppBar(
        title: Text("Document Requests", style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text("New Request"),
        backgroundColor: primaryColor,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty 
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.description_outlined, size: 60, color: Colors.grey[300]),
                    const SizedBox(height: 10),
                    Text("No document requests yet", style: GoogleFonts.lato(color: Colors.grey)),
                  ],
                ))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _requests.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final req = _requests[index];
                    final String id = req['_id'] ?? req['id']; // Handle ID robustly

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: _getStatusColor(req['status']).withOpacity(0.1),
                                      child: Icon(Icons.description, size: 18, color: _getStatusColor(req['status'])),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(req['type'], style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(req['status']).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    req['status'],
                                    style: TextStyle(color: _getStatusColor(req['status']), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            Text("Details:", style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                            Text(req['details'], style: const TextStyle(fontSize: 14)),
                            
                            if (req['adminComment'] != null && req['adminComment'].toString().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.red.withOpacity(0.2))
                                ),
                                child: Text("Admin Note: ${req['adminComment']}", style: TextStyle(color: Colors.red[800], fontSize: 13)),
                              ),
                            ],
                            
                            const SizedBox(height: 10),
                            
                            // ✅ FOOTER ROW: Date on Left, Delete on Right
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('MMM d, yyyy • h:mm a').format(DateTime.parse(req['createdAt']).toLocal()), 
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500])
                                ),
                                
                                // ✅ DELETE BUTTON
                                InkWell(
                                  onTap: () => _deleteRequest(id),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}