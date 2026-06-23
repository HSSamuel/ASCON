import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class FullScreenImage extends StatefulWidget {
  final String? imageUrl;
  final String heroTag;

  const FullScreenImage({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  State<FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> {
  bool _showUI = true;

  @override
  void dispose() {
    // Ensure the system status bar comes back when the user leaves this screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ✅ PRO FEATURE: Intelligent Share Logic
  Future<void> _shareImage(BuildContext context) async {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) return;

    try {
      Uint8List? bytes;
      String fileName = "shared_image.png";

      // Case A: It's a Network URL -> Download it
      if (widget.imageUrl!.startsWith('http')) {
        final response = await http.get(Uri.parse(widget.imageUrl!));
        bytes = response.bodyBytes;
      } 
      // Case B: It's Base64 -> Decode it
      else {
        String cleanBase64 = widget.imageUrl!;
        if (cleanBase64.contains(',')) {
          cleanBase64 = cleanBase64.split(',').last;
        }
        bytes = base64Decode(cleanBase64);
      }

      if (bytes != null) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);

        // Share the file using native share sheet
        await Share.shareXFiles([XFile(file.path)], text: 'Check out this image!');
      }
    } catch (e) {
      debugPrint("Share Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not share image"), 
            backgroundColor: Colors.red
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true, 
      
      // ✅ Smoothly fade the AppBar in and out
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedOpacity(
          opacity: _showUI ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: AppBar(
            backgroundColor: Colors.black.withOpacity(0.4),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _shareImage(context),
                tooltip: "Share Image",
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
      
      body: GestureDetector(
        // ✅ Tap anywhere to hide the UI and expand the image to the ultimate borders
        onTap: () {
          setState(() {
            _showUI = !_showUI;
            // Also hide the phone's battery/time status bar for true full screen
            if (_showUI) {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
            } else {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
            }
          });
        },
        // Note: Removed the custom onDoubleTap -> pop. 
        // This allows the InteractiveViewer to natively handle Double-Tap to Zoom!
        child: SizedBox.expand(
          child: InteractiveViewer(
            panEnabled: true,
            // ✅ FIX: Zero boundary margin keeps the image from flying off into the black abyss when panned
            boundaryMargin: EdgeInsets.zero, 
            clipBehavior: Clip.none, 
            minScale: 1.0, // ✅ FIX: Prevents shrinking the image smaller than the screen
            maxScale: 6.0, 
            child: Hero(
              tag: widget.heroTag,
              // ✅ FIX: SizedBox.expand forces the image gesture detector to stretch to all 4 corners of the screen
              child: SizedBox.expand(
                child: _buildSafeImage(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSafeImage() {
    // 1. If Image is a URL (Network) -> Use CachedNetworkImage (Pro Performance)
    if (widget.imageUrl != null && widget.imageUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: widget.imageUrl!,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        errorWidget: (context, url, error) => _buildFallbackIcon(),
      );
    }

    // 2. If Image is Base64 (Database string)
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      try {
        // Remove header if present (e.g., "data:image/png;base64,")
        String cleanBase64 = widget.imageUrl!;
        if (cleanBase64.contains(',')) {
          cleanBase64 = cleanBase64.split(',').last;
        }
        return Image.memory(
          base64Decode(cleanBase64),
          fit: BoxFit.contain,
          errorBuilder: (c, e, s) => _buildFallbackIcon(),
        );
      } catch (e) {
        return _buildFallbackIcon();
      }
    }

    // 3. Fallback if empty
    return _buildFallbackIcon();
  }

  Widget _buildFallbackIcon() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min, 
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.broken_image, size: 60, color: Colors.white38), 
          SizedBox(height: 12),
          Text(
            "Image could not load", 
            style: TextStyle(color: Colors.white38, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}