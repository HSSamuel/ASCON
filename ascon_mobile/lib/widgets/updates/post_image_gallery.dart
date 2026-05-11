import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PostImageGallery extends StatelessWidget {
  final List<String> images;
  final bool isDark;

  const PostImageGallery({super.key, required this.images, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // Single image handles as normal to fill the space
    if (images.length == 1) {
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 240), 
        color: isDark ? Colors.black : Colors.grey[100],
        child: GestureDetector(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (context) => FullScreenImage(imageUrl: images[0])),
            );
          },
          child: CachedNetworkImage(
            imageUrl: images[0],
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(height: 200, color: Colors.grey[200]),
            errorWidget: (context, url, error) => const SizedBox(height: 50),
          ),
        ),
      );
    }

    // Multiple images displayed as a horizontally scrollable list
    return Container(
      width: double.infinity,
      height: 240, 
      color: isDark ? Colors.black : Colors.grey[100],
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: images.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (context) => FullScreenImage(imageUrl: images[index])),
              );
            },
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85, // Shows a peek of the next image
              margin: EdgeInsets.only(right: index == images.length - 1 ? 0 : 4), // 4px gap between images
              child: CachedNetworkImage(
                imageUrl: images[index],
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey[200]),
                errorWidget: (context, url, error) => const SizedBox(height: 50),
              ),
            ),
          );
        },
      ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  const FullScreenImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}