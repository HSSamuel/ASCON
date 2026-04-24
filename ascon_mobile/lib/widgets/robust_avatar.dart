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
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return _buildPlaceholder();
    }

    final cleanUrl = imageUrl!.toLowerCase().trim();

    // 🛡️ Explicitly block dummy Google URLs before they trigger network decoding errors
    if (cleanUrl.contains('profile/picture') || cleanUrl.contains('default-user')) {
      return _buildPlaceholder();
    }

    // Handle standard network images
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

    // Handle Base64 strings
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
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
      child: Icon(Icons.person, color: isDark ? Colors.grey[500] : Colors.grey, size: radius * 1.2),
    );
  }
}