import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_client.dart';

class PollCreationSheet extends StatefulWidget {
  final String groupId;

  const PollCreationSheet({super.key, required this.groupId});

  @override
  State<PollCreationSheet> createState() => _PollCreationSheetState();
}

class _PollCreationSheetState extends State<PollCreationSheet> {
  final TextEditingController _questionCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [
    TextEditingController(),
    TextEditingController()
  ]; // Start with 2 options

  int _durationDays = 7;
  bool _isPosting = false;
  final ApiClient _api = ApiClient();

  void _addOption() {
    if (_optionCtrls.length < 5) {
      setState(() {
        _optionCtrls.add(TextEditingController());
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum 5 options allowed."))
      );
    }
  }

  void _removeOption(int index) {
    if (_optionCtrls.length > 2) {
      setState(() {
        _optionCtrls.removeAt(index);
      });
    }
  }

  Future<void> _submitPoll() async {
    // 1. Validate
    if (_questionCtrl.text.trim().isEmpty) {
      _showError("Please enter a question.");
      return;
    }

    // Filter out empty options
    final validOptions = _optionCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (validOptions.length < 2) {
      _showError("Please provide at least 2 options.");
      return;
    }

    // 2. Loading State
    setState(() => _isPosting = true);

    try {
      // 3. API Call
      final expiresAt = DateTime.now().add(Duration(days: _durationDays)).toIso8601String();
      
      final result = await _api.post('/api/polls', {
        'question': _questionCtrl.text.trim(),
        'options': validOptions,
        'groupId': widget.groupId,
        'expiresAt': expiresAt
      });

      if (result['success'] == true) {
        if (mounted) {
          Navigator.pop(context); // Close Sheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Poll Created Successfully! 📊"), backgroundColor: Colors.green)
          );
        }
      } else {
        _showError(result['message'] ?? "Failed to create poll.");
      }
    } catch (e) {
      _showError("Connection error. Please try again.");
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red)
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, 
        right: 20, 
        top: 24
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HEADER
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bar_chart_rounded, color: Colors.orange, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Create Poll", 
                  style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 20),

          // SCROLLABLE FORM
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // QUESTION INPUT
                  Text("Question", style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _questionCtrl,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "Ask something...",
                      filled: true,
                      fillColor: isDark ? Colors.black12 : Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // OPTIONS LIST
                  Text("Options", style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  ...List.generate(_optionCtrls.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _optionCtrls[index],
                              style: TextStyle(color: textColor),
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: "Option ${index + 1}",
                                filled: true,
                                fillColor: isDark ? Colors.black12 : Colors.grey[50],
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                prefixIcon: Icon(Icons.radio_button_unchecked, size: 18, color: Colors.grey[400]),
                              ),
                            ),
                          ),
                          if (_optionCtrls.length > 2)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () => _removeOption(index),
                            )
                        ],
                      ),
                    );
                  }),

                  // ADD OPTION BUTTON
                  if (_optionCtrls.length < 5)
                    TextButton.icon(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text("Add Option"),
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                      ),
                    ),
                  
                  const Divider(height: 30),

                  // SETTINGS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Duration", style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                      DropdownButton<int>(
                        value: _durationDays,
                        dropdownColor: bgColor,
                        underline: const SizedBox(),
                        style: GoogleFonts.lato(color: primaryColor, fontWeight: FontWeight.bold),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text("24 Hours")),
                          DropdownMenuItem(value: 3, child: Text("3 Days")),
                          DropdownMenuItem(value: 7, child: Text("1 Week")),
                        ], 
                        onChanged: (val) {
                          if (val != null) setState(() => _durationDays = val);
                        }
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // CREATE BUTTON
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isPosting ? null : _submitPoll,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isPosting 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Create Poll", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}