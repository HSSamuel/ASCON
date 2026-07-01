import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vibration/vibration.dart';
import '../../../viewmodels/updates_view_model.dart';

class CreatePostSheet extends ConsumerStatefulWidget {
  const CreatePostSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // ✅ Removed border radius to make it truly flat/full screen
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      // ✅ Forces the bottom sheet to take 100% of the available height
      builder: (_) => const FractionallySizedBox(
        heightFactor: 1.0, 
        child: CreatePostSheet(),
      ),
    );
  }

  @override
  ConsumerState<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<CreatePostSheet> {
  final TextEditingController _textController = TextEditingController();
  List<XFile> _selectedImages = []; 
  bool _isPostingLocal = false; 

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _insertMarkdown(String prefix, String suffix) {
    final text = _textController.text;
    final selection = _textController.selection;
    
    if (selection.start == -1) {
      _textController.text = text + prefix + suffix;
      _textController.selection = TextSelection.collapsed(offset: _textController.text.length - suffix.length);
      return;
    }
    
    final selectedText = selection.textInside(text);
    final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
    
    _textController.text = newText;
    _textController.selection = TextSelection(
      baseOffset: selection.start + prefix.length,
      extentOffset: selection.start + prefix.length + selectedText.length,
    );
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 70);
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(pickedFiles);
        if (_selectedImages.length > 5) {
          _selectedImages = _selectedImages.sublist(0, 5); 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Max 5 images allowed.")));
        }
      });
    }
  }

  Future<void> _submitPost() async {
    if (_textController.text.trim().isEmpty && _selectedImages.isEmpty) return;
    if (_isPostingLocal) return; 

    setState(() => _isPostingLocal = true); 

    final error = await ref.read(updatesProvider.notifier).createPost(_textController.text.trim(), _selectedImages);
    
    if (error == null) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Update posted! 🚀"), backgroundColor: Colors.green));
        if (!kIsWeb) Vibration.hasVibrator().then((v) { if (v ?? false) Vibration.vibrate(duration: 30); });
      }
    } else {
      if (mounted) {
        setState(() => _isPostingLocal = false); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.max, // ✅ Allows Column to expand fully inside the FractionallySizedBox
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // ✅ Added an explicit Close/Cancel button for the full screen sheet
                  IconButton(
                    icon: const Icon(Icons.close),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Text("New Update", style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              _isPostingLocal 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(
                    onPressed: _submitPost,
                    style: TextButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    child: const Text("Post", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
            ],
          ),
          const SizedBox(height: 16),
          
          Container(
            margin: const EdgeInsets.only(bottom: 30),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.format_bold, size: 20), tooltip: 'Bold', visualDensity: VisualDensity.compact, onPressed: () => _insertMarkdown('**', '**')),
                IconButton(icon: const Icon(Icons.format_italic, size: 20), tooltip: 'Italic', visualDensity: VisualDensity.compact, onPressed: () => _insertMarkdown('*', '*')),
                IconButton(icon: const Icon(Icons.strikethrough_s, size: 20), tooltip: 'Strikethrough', visualDensity: VisualDensity.compact, onPressed: () => _insertMarkdown('~~', '~~')),
                IconButton(icon: const Icon(Icons.format_list_bulleted, size: 20), tooltip: 'Bullet List', visualDensity: VisualDensity.compact, onPressed: () => _insertMarkdown('- ', '')),
                IconButton(icon: const Icon(Icons.link, size: 20), tooltip: 'Link', visualDensity: VisualDensity.compact, onPressed: () => _insertMarkdown('[', '](url)')),
              ],
            ),
          ),

          // ✅ Wrapped TextField in Expanded so it pushes everything up and feels like a massive canvas
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: null, // ✅ Allow infinite lines
              expands: true,  // ✅ Expand vertically to fill the remaining screen real estate
              autofocus: true,
              textAlignVertical: TextAlignVertical.top, // ✅ Keep text at the top
              style: GoogleFonts.lato(fontSize: 14), 
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: "What's happening? Use the toolbar for bold, italics, etc.", 
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          
          if (_selectedImages.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb 
                              ? Image.network(_selectedImages[index].path, height: 120, width: 100, fit: BoxFit.cover)
                              : Image.file(File(_selectedImages[index].path), height: 120, width: 100, fit: BoxFit.cover),
                        ),
                      ),
                      IconButton(
                        icon: const CircleAvatar(backgroundColor: Colors.black54, radius: 12, child: Icon(Icons.close, size: 14, color: Colors.white)),
                        onPressed: () => setState(() => _selectedImages.removeAt(index)),
                      ),
                    ],
                  );
                },
              ),
            ),

          const Divider(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.image_rounded, color: Colors.green)),
            title: const Text("Add Photos (Max 5)"),
            onTap: _pickImages,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}