import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/chat_objects.dart';

class ChatInputArea extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // ✅ FIX: Use ValueListenableBuilder to react to text changes instantly
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final bool hasText = value.text.trim().isNotEmpty;
        // On Web, always show Send. On Mobile, show Send if text exists, otherwise Mic.
        final bool showSend = hasText || isRecording || kIsWeb;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Reply/Edit Preview
            if (replyingTo != null || editingMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isDark ? Colors.grey[850] : Colors.grey[100],
                child: Row(
                  children: [
                    Icon(editingMessage != null ? Icons.edit : Icons.reply, color: primaryColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            editingMessage != null 
                                ? "Editing Message" 
                                : "Replying to ${replyingTo!.senderId == myUserId ? 'Yourself' : (replyingTo!.senderName ?? 'User')}",
                            style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                          Text(
                            editingMessage != null 
                                ? editingMessage!.text 
                                : (replyingTo!.type == 'text' ? replyingTo!.text : "Media"),
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20), 
                      onPressed: editingMessage != null ? onCancelEdit : onCancelReply
                    )
                  ],
                ),
              ),

            // 2. Main Input Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: SafeArea(
                child: Row(
                  children: [
                    // Attach Button
                    if (!isRecording) 
                      IconButton(
                        icon: Icon(Icons.add_circle_outline, color: primaryColor, size: 28), 
                        onPressed: onAttachmentMenu,
                        tooltip: "Attach",
                      ),
                    const SizedBox(width: 4),

                    // Text Field or Recording Indicator
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 100),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : const Color(0xFFF2F4F5), 
                          borderRadius: BorderRadius.circular(24)
                        ),
                        child: isRecording 
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                              children: [
                                const Icon(Icons.mic, color: Colors.red, size: 20), 
                                Text("Recording... ${recordDuration ~/ 60}:${(recordDuration % 60).toString().padLeft(2, '0')}", style: const TextStyle(fontWeight: FontWeight.bold)), 
                                TextButton(onPressed: onCancelRecording, child: const Text("Cancel", style: TextStyle(color: Colors.red)))
                              ]
                            )
                          : TextField(
                              controller: controller, 
                              focusNode: focusNode,
                              maxLines: null, // Allow multiline growth
                              minLines: 1,
                              onChanged: onTyping,
                              cursorColor: isDark ? const Color(0xFFD4AF37) : primaryColor,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: "Message...", 
                                border: InputBorder.none,
                                hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
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
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(showSend ? Icons.send : Icons.mic, color: Colors.white, size: 22),
                        onPressed: () {
                          if (isRecording) {
                            onStopRecording();
                          } else if (hasText) {
                            // ✅ Now this will be TRUE because we are listening to the controller
                            onSendMessage();
                          } else if (!kIsWeb) {
                            onStartRecording();
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