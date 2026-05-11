import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RobustAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final bool isDark;

  const RobustAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 28.0,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Handle Null or Empty Strings
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return _buildPlaceholder();
    }

    final cleanUrl = imageUrl!.toLowerCase().trim();

    // 2. 🛡️ Explicitly block dummy Google URLs before they trigger network decoding errors
    if (cleanUrl.contains('googleusercontent.com/profile/picture') || 
        cleanUrl.contains('default-user')) {
      return _buildPlaceholder();
    }

    // 3. Handle standard network images with Graceful Fallbacks
    if (imageUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: radius,
          backgroundImage: imageProvider,
          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
        ),
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }

    // 4. Handle Base64 strings (If your backend sometimes sends raw image strings)
    try {
      String cleanBase64 = imageUrl!;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(base64Decode(cleanBase64)),
        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
      );
    } catch (e) {
      // If Base64 decoding fails, don't crash, just show the icon
      return _buildPlaceholder();
    }
  }

  // Unified fallback UI
  Widget _buildPlaceholder() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
      child: Icon(
        Icons.person, 
        color: isDark ? Colors.grey[500] : Colors.grey, 
        size: radius * 1.2
      ),
    );
  }
}