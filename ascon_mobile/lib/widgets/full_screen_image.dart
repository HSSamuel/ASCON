import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class FullScreenImage extends StatelessWidget {
  final String? imageUrl;
  final String heroTag;

  const FullScreenImage({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  // ✅ PRO FEATURE: Intelligent Share Logic
  Future<void> _shareImage(BuildContext context) async {
    if (imageUrl == null || imageUrl!.isEmpty) return;

    try {
      Uint8List? bytes;
      String fileName = "shared_image.png";

      // Case A: It's a Network URL -> Download it
      if (imageUrl!.startsWith('http')) {
        final response = await http.get(Uri.parse(imageUrl!));
        bytes = response.bodyBytes;
      } 
      // Case B: It's Base64 -> Decode it
      else {
        String cleanBase64 = imageUrl!;
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
      
      appBar: AppBar(
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
      
      // ✅ Wrap InteractiveViewer in a GestureDetector to easily dismiss on double tap
      body: GestureDetector(
        onDoubleTap: () => Navigator.pop(context),
        child: Center(
          child: Hero(
            tag: heroTag,
            child: InteractiveViewer(
              panEnabled: true,
              // ✅ FIX: Allow infinite panning beyond the image borders
              boundaryMargin: const EdgeInsets.all(double.infinity), 
              clipBehavior: Clip.none, // ✅ FIX: Don't cut off the image when zooming
              minScale: 0.5,
              maxScale: 6.0, // ✅ Increased max zoom level for better inspection
              child: _buildSafeImage(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSafeImage() {
    // 1. If Image is a URL (Network) -> Use CachedNetworkImage (Pro Performance)
    if (imageUrl != null && imageUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        errorWidget: (context, url, error) => _buildFallbackIcon(),
      );
    }

    // 2. If Image is Base64 (Database string)
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      try {
        // Remove header if present (e.g., "data:image/png;base64,")
        String cleanBase64 = imageUrl!;
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
        mainAxisSize: MainAxisSize.min, // ✅ FIX: Prevents the column from expanding infinitely and crashing
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.broken_image, size: 60, color: Colors.white38), // Slightly smaller icon
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