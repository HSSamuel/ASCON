import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

class PostImageGallery extends StatelessWidget {
  final List<String> images;
  final bool isDark;

  const PostImageGallery({super.key, required this.images, required this.isDark});

  Widget _buildImage(BuildContext context, int index, {BoxFit fit = BoxFit.cover}) {
    return GestureDetector(
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => FullScreenGallery(images: images, initialIndex: index)),
      ),
      child: CachedNetworkImage(
        imageUrl: images[index],
        fit: fit,
        placeholder: (context, url) => Container(color: isDark ? Colors.grey[900] : Colors.grey[200]),
        errorWidget: (context, url, error) => Container(
          color: isDark ? Colors.grey[900] : Colors.grey[200], 
          child: const Icon(Icons.broken_image, color: Colors.grey)
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    const double spacing = 2.0;

    // 1 Image: Full width
    if (images.length == 1) {
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 350), // Allows tall images to look good
        child: _buildImage(context, 0, fit: BoxFit.cover),
      );
    }

    // 2 Images: Split 50/50 horizontally
    if (images.length == 2) {
      return SizedBox(
        height: 250,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildImage(context, 0)),
            const SizedBox(width: spacing),
            Expanded(child: _buildImage(context, 1)),
          ],
        ),
      );
    }

    // 3 or more Images: 1 large on left, 2 stacked on right
    return SizedBox(
      height: 320,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: _buildImage(context, 0),
          ),
          const SizedBox(width: spacing),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildImage(context, 1)),
                const SizedBox(height: spacing),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImage(context, 2),
                      // Overlay for more than 3 images
                      if (images.length > 3)
                        GestureDetector(
                          onTap: () => Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(builder: (_) => FullScreenGallery(images: images, initialIndex: 2)),
                          ),
                          child: Container(
                            color: Colors.black.withOpacity(0.5),
                            alignment: Alignment.center,
                            child: Text(
                              '+${images.length - 3}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Full Screen Swipeable Gallery
class FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenGallery({super.key, required this.images, required this.initialIndex});

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
        title: widget.images.length > 1 
          ? Text("${_currentIndex + 1} / ${widget.images.length}", style: const TextStyle(color: Colors.white, fontSize: 16))
          : null,
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.images.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return _ZoomableGalleryImage(imageUrl: widget.images[index]);
        },
      ),
    );
  }
}

class _ZoomableGalleryImage extends StatefulWidget {
  final String imageUrl;
  const _ZoomableGalleryImage({required this.imageUrl});

  @override
  State<_ZoomableGalleryImage> createState() => _ZoomableGalleryImageState();
}

class _ZoomableGalleryImageState extends State<_ZoomableGalleryImage> with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 250))
      ..addListener(() => _transformationController.value = _animation!.value);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) => _doubleTapDetails = details;

  void _handleDoubleTap() {
    if (_animationController.isAnimating) return;
    final position = _doubleTapDetails?.localPosition;
    if (position == null) return;

    if (_transformationController.value != Matrix4.identity()) {
      _animation = Matrix4Tween(
        begin: _transformationController.value,
        end: Matrix4.identity(),
      ).animate(CurveTween(curve: Curves.easeInOut).animate(_animationController));
      _animationController.forward(from: 0);
    } else {
      const double scale = 2.5;
      final x = -position.dx * (scale - 1);
      final y = -position.dy * (scale - 1);
      final zoomedMatrix = Matrix4.identity()
        ..translate(x, y)
        ..scale(scale);
      _animation = Matrix4Tween(
        begin: _transformationController.value,
        end: zoomedMatrix,
      ).animate(CurveTween(curve: Curves.easeInOut).animate(_animationController));
      _animationController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        panEnabled: true,
        minScale: 1.0,
        maxScale: 6.0,
        child: CachedNetworkImage(
          imageUrl: widget.imageUrl,
          fit: BoxFit.contain,
          placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
          errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, color: Colors.white38, size: 60)),
        ),
      ),
    );
  }
}