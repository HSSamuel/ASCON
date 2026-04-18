import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/chat_objects.dart';

class ChatInputArea extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final Color primaryColor;
  final bool isRecording;
  final int recordDuration;
  
  // Reply/Edit Context
  final ChatMessage? replyingTo;
  final ChatMessage? editingMessage;
  final String myUserId;

  // Callbacks
  final VoidCallback onCancelReply;
  final VoidCallback onCancelEdit;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onCancelRecording;
  final VoidCallback onSendMessage;
  final VoidCallback onAttachmentMenu;
  final Function(String) onTyping;

  const ChatInputArea({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.primaryColor,
    required this.isRecording,
    required this.recordDuration,
    this.replyingTo,
    this.editingMessage,
    required this.myUserId,
    required this.onCancelReply,
    required this.onCancelEdit,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelRecording,
    required this.onSendMessage,
    required this.onAttachmentMenu,
    required this.onTyping,
  });

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> {
  // ✅ ADDED: State to track and prevent double-taps
  bool _isSending = false;

  void _handleSend() {
    if (_isSending || widget.controller.text.trim().isEmpty) return;

    setState(() {
      _isSending = true;
    });

    widget.onSendMessage();

    // Re-enable the button after a short delay to prevent double submissions 
    // while giving the parent UI time to process the message.
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        final bool hasText = value.text.trim().isNotEmpty;
        // On Web, always show Send. On Mobile, show Send if text exists, otherwise Mic.
        final bool showSend = hasText || widget.isRecording || kIsWeb;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Reply/Edit Preview
            if (widget.replyingTo != null || widget.editingMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: widget.isDark ? Colors.grey[850] : Colors.grey[100],
                child: Row(
                  children: [
                    Icon(widget.editingMessage != null ? Icons.edit : Icons.reply, color: widget.primaryColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.editingMessage != null 
                                ? "Editing Message" 
                                : "Replying to ${widget.replyingTo!.senderId == widget.myUserId ? 'Yourself' : (widget.replyingTo!.senderName ?? 'User')}",
                            style: TextStyle(fontWeight: FontWeight.bold, color: widget.primaryColor),
                          ),
                          Text(
                            widget.editingMessage != null 
                                ? widget.editingMessage!.text 
                                : (widget.replyingTo!.type == 'text' ? widget.replyingTo!.text : "Media"),
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20), 
                      onPressed: widget.editingMessage != null ? widget.onCancelEdit : widget.onCancelReply
                    )
                  ],
                ),
              ),

            // 2. Main Input Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: SafeArea(
                child: Row(
                  children: [
                    // Attach Button
                    if (!widget.isRecording) 
                      IconButton(
                        icon: Icon(Icons.add_circle_outline, color: widget.primaryColor, size: 28), 
                        onPressed: widget.onAttachmentMenu,
                        tooltip: "Attach",
                      ),
                    const SizedBox(width: 4),

                    // Text Field or Recording Indicator
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 100),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: widget.isDark ? Colors.grey[900] : const Color(0xFFF2F4F5), 
                          borderRadius: BorderRadius.circular(24)
                        ),
                        child: widget.isRecording 
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                              children: [
                                const Icon(Icons.mic, color: Colors.red, size: 20), 
                                Text("Recording... ${widget.recordDuration ~/ 60}:${(widget.recordDuration % 60).toString().padLeft(2, '0')}", style: const TextStyle(fontWeight: FontWeight.bold)), 
                                TextButton(onPressed: widget.onCancelRecording, child: const Text("Cancel", style: TextStyle(color: Colors.red)))
                              ]
                            )
                          : TextField(
                              controller: widget.controller, 
                              focusNode: widget.focusNode,
                              maxLines: null, // Allow multiline growth
                              minLines: 1,
                              onChanged: widget.onTyping,
                              cursorColor: widget.isDark ? const Color(0xFFD4AF37) : widget.primaryColor,
                              style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: "Message...", 
                                border: InputBorder.none,
                                hintStyle: TextStyle(color: widget.isDark ? Colors.white54 : Colors.grey),
                                contentPadding: const EdgeInsets.symmetric(vertical: 14) // Better centering
                              ),
                              textCapitalization: TextCapitalization.sentences,
                              keyboardType: TextInputType.multiline,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Send/Mic Button
                    Container(
                      decoration: BoxDecoration(
                        color: _isSending ? Colors.grey : widget.primaryColor, // Visual feedback
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        // Show a loading spinner if actively sending
                        icon: _isSending 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(showSend ? Icons.send : Icons.mic, color: Colors.white, size: 22),
                        onPressed: _isSending ? null : () {
                          if (widget.isRecording) {
                            widget.onStopRecording();
                          } else if (hasText) {
                            _handleSend(); // ✅ Use the debouncer
                          } else if (!kIsWeb) {
                            widget.onStartRecording();
                          }
                        },
                        tooltip: showSend ? "Send" : "Record",
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}