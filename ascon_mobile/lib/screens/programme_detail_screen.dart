import 'dart:convert';
import 'package:flutter/gestures.dart'; 
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'programme_registration_screen.dart';
import '../services/data_service.dart';

class ProgrammeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> programme;

  const ProgrammeDetailScreen({super.key, required this.programme});

  @override
  State<ProgrammeDetailScreen> createState() => _ProgrammeDetailScreenState();
}

class _ProgrammeDetailScreenState extends State<ProgrammeDetailScreen> {
  final DataService _dataService = DataService();
  late Map<String, dynamic> _programme;
  String? _localUserId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _programme = widget.programme;
    _getUserId();

    final String? idToFetch = _programme['id'] ?? _programme['_id'];
    if ((_programme['description'] == null || _programme['fee'] == null) && idToFetch != null) {
      _fetchFullProgrammeDetails(idToFetch);
    }
  }

  Future<void> _fetchFullProgrammeDetails(String id) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final fullData = await _dataService.fetchProgrammeById(id);
      if (fullData != null && mounted) {
        setState(() {
          _programme = fullData;
        });
      }
    } catch (e) {
      debugPrint("Error fetching programme details: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return; 
    setState(() {
       _localUserId = prefs.getString('mongo_id');
    });
  }

  // ✅ HELPER: Handles both HTTP URLs and Base64 Strings
  Widget _buildSafeImage(String? imageUrl, {BoxFit fit = BoxFit.cover}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(color: Colors.grey[300]); 
    }

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: fit,
        errorBuilder: (c, e, s) => Container(color: Colors.grey[300]),
      );
    }

    try {
      String cleanBase64 = imageUrl;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      return Image.memory(
        base64Decode(cleanBase64),
        fit: fit,
        errorBuilder: (c, e, s) => Container(color: Colors.grey[300]),
      );
    } catch (e) {
      return Container(color: Colors.grey[300]);
    }
  }
  
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  // ✅ NAVIGATE TO FULL SCREEN IMAGE
  void _openFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final title = _programme['title'] ?? 'Loading...';
    final description = _programme['description'] ?? 'No description available.';
    final duration = _programme['duration'];
    final fee = _programme['fee'];
    final programmeId = _programme['_id'] ?? _programme['id'];
    
    final String? programmeImage = _programme['image'] ?? _programme['imageUrl'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Programme Details"), 
        elevation: 0,
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            _buildHeader(programmeImage, title, primaryColor),
            
            const SizedBox(height: 25),

            if (duration != null || fee != null)
              Row(
                children: [
                  if (duration != null && duration.toString().isNotEmpty) 
                    Expanded(child: _buildInfoTile(Icons.timer_outlined, "Duration", duration)),
                  
                  if (duration != null && fee != null) 
                    const SizedBox(width: 15),
                  
                  if (fee != null && fee.toString().isNotEmpty) 
                    Expanded(child: _buildInfoTile(Icons.monetization_on_outlined, "Fee", fee)),
                ],
              ),
            
            const SizedBox(height: 25),

            Text(
              "About this Programme", 
              style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)
            ),
            const SizedBox(height: 12),
            
            _buildFormattedDescription(description, isDark),
            
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProgrammeRegistrationScreen(
                        programmeId: programmeId,
                        programmeTitle: title,
                        userId: _localUserId,
                        programmeImage: programmeImage,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Register Interest", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedDescription(String text, bool isDark) {
    final baseStyle = GoogleFonts.lato(
      fontSize: 15, 
      height: 1.6, 
      color: isDark ? Colors.grey[400] : Colors.grey[700]
    );

    List<String> paragraphs = text.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((paragraph) {
        if (paragraph.trim().isEmpty) return const SizedBox(height: 10);

        if (paragraph.trim().startsWith('- ') || paragraph.trim().startsWith('* ')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6.0, left: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("• ", style: baseStyle.copyWith(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text.rich(
                    _parseRichText(paragraph.substring(2), baseStyle, isDark),
                    textAlign: TextAlign.justify,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text.rich(
            _parseRichText(paragraph, baseStyle, isDark),
            textAlign: TextAlign.justify,
          ),
        );
      }).toList(),
    );
  }

  TextSpan _parseRichText(String text, TextStyle baseStyle, bool isDark) {
    List<TextSpan> spans = [];
    final regex = RegExp(r'(https?:\/\/[^\s]+)|\*\*(.*?)\*\*|\*(.*?)\*');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }

      if (match.group(1) != null) {
        final String url = match.group(1)!;
        spans.add(TextSpan(
          text: url,
          style: baseStyle.copyWith(
            color: Colors.blue, 
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.bold
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _launchURL(url),
        ));
      } 
      else if (match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(2),
          style: baseStyle.copyWith(
            fontWeight: FontWeight.bold, 
            color: isDark ? Colors.white : Colors.black87
          ), 
        ));
      } 
      else if (match.group(3) != null) {
        spans.add(TextSpan(
          text: match.group(3),
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      }
      
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return TextSpan(style: baseStyle, children: spans);
  }

  Widget _buildHeader(String? image, String title, Color primaryColor) {
    if (image != null && image.isNotEmpty) {
      return GestureDetector(
        // ✅ Make the image tappable
        onTap: () => _openFullScreenImage(image),
        child: Container(
          height: 220, 
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey[200],
            boxShadow: [
               BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
            ]
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildSafeImage(image),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.8)],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        title, 
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lato(
                          fontSize: 28.0, 
                          fontWeight: FontWeight.w900, 
                          color: Colors.white,
                          height: 1.2
                        )
                      ),
                    ],
                  ),
                ),
              ),
              // ✅ "View Photo" Badge at Bottom Right
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3))
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.fullscreen, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text("View Photo", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryColor.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(Icons.school_rounded, size: 50, color: primaryColor),
            const SizedBox(height: 15),
            Text(
              title, 
              textAlign: TextAlign.center, 
              style: GoogleFonts.lato(
                fontSize: 26.0, 
                fontWeight: FontWeight.w900, 
                color: primaryColor
              )
            ),
          ],
        ),
      );
    }
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey[600]), 
              const SizedBox(width: 6), 
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]))
            ]
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ✅ NEW: Full Screen Image Viewer Widget
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: _buildSafeImage(imageUrl),
        ),
      ),
    );
  }

  Widget _buildSafeImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return const Icon(Icons.image_not_supported, color: Colors.white, size: 50);
    }

    if (imageUrl.startsWith('http')) {
      return Image.network(imageUrl, fit: BoxFit.contain);
    }

    try {
      String cleanBase64 = imageUrl;
      if (cleanBase64.contains(',')) cleanBase64 = cleanBase64.split(',').last;
      return Image.memory(base64Decode(cleanBase64), fit: BoxFit.contain);
    } catch (e) {
      return const Icon(Icons.broken_image, color: Colors.white, size: 50);
    }
  }
}