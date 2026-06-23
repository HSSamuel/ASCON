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

class _FullScreenImageState extends State<FullScreenImage> with SingleTickerProviderStateMixin {
  bool _showUI = true;

  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        _transformationController.value = _animation!.value;
      });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

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

  Future<void> _shareImage(BuildContext context) async {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) return;

    try {
      Uint8List? bytes;
      String fileName = "shared_image.png";

      if (widget.imageUrl!.startsWith('http')) {
        final response = await http.get(Uri.parse(widget.imageUrl!));
        bytes = response.bodyBytes;
      } else {
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
        onTap: () {
          setState(() {
            _showUI = !_showUI;
            if (_showUI) {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
            } else {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
            }
          });
        },
        onDoubleTapDown: _handleDoubleTapDown,
        onDoubleTap: _handleDoubleTap,
        child: SizedBox.expand(
          child: InteractiveViewer(
            transformationController: _transformationController,
            panEnabled: true,
            boundaryMargin: EdgeInsets.zero, 
            clipBehavior: Clip.none, 
            minScale: 1.0, 
            maxScale: 6.0, 
            child: Hero(
              tag: widget.heroTag,
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

    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      try {
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