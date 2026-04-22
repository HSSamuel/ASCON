import 'dart:convert';
import 'package:flutter/gestures.dart'; 
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart'; 
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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _programme = widget.programme;

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

  void _openFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(imageUrl: imageUrl),
      ),
    );
  }

  // ✅ NEW: Builds the rich link card (like Updates Screen)
  Widget _buildLinkCard(String url, bool isDark) {
    IconData icon = Icons.link;
    String title = "External Link";
    String domain = Uri.tryParse(url)?.host ?? "website";

    if (url.contains('drive.google.com')) {
      icon = Icons.add_to_drive;
      title = "Google Drive Document";
    } else if (url.contains('youtube.com') || url.contains('youtu.be')) {
      icon = Icons.play_circle_fill;
      title = "YouTube Video";
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () async {
          final Uri uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            debugPrint('Could not launch $url');
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.blue.withOpacity(0.05),
            border: Border.all(color: isDark ? Colors.grey[700]! : Colors.blue.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.white, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(domain, style: GoogleFonts.lato(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, color: Colors.grey, size: 16),
            ],
          ),
        ),
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
    final urlRegex = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((paragraph) {
        if (paragraph.trim().isEmpty) return const SizedBox(height: 10);

        List<String> extractedUrls = [];
        String cleanText = paragraph;

        // ✅ Extract URLs and remove them from the raw text
        for (final match in urlRegex.allMatches(paragraph)) {
          String url = match.group(0)!;
          if (url.endsWith(')') || url.endsWith('.') || url.endsWith(',')) {
            url = url.substring(0, url.length - 1);
          }
          extractedUrls.add(url);
          cleanText = cleanText.replaceAll(url, '').trim(); 
        }

        Widget textContent;
        if (cleanText.isEmpty) {
          textContent = const SizedBox.shrink();
        } else if (cleanText.trim().startsWith('- ') || cleanText.trim().startsWith('* ')) {
          textContent = Padding(
            padding: const EdgeInsets.only(bottom: 6.0, left: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("• ", style: baseStyle.copyWith(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text.rich(
                    _parseRichText(cleanText.substring(2).trimLeft(), baseStyle, isDark),
                    textAlign: TextAlign.justify,
                  ),
                ),
              ],
            ),
          );
        } else {
          textContent = Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text.rich(
              _parseRichText(cleanText, baseStyle, isDark),
              textAlign: TextAlign.justify,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            textContent,
            // ✅ Render beautiful link cards at the bottom of the paragraph
            ...extractedUrls.map((url) => _buildLinkCard(url, isDark)),
          ],
        );
      }).toList(),
    );
  }

  TextSpan _parseRichText(String text, TextStyle baseStyle, bool isDark) {
    List<TextSpan> spans = [];
    final regex = RegExp(r'\*\*(.*?)\*\*|\*(.*?)\*'); // Removed raw URL regex since cards handle them now
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }

      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(1),
          style: baseStyle.copyWith(
            fontWeight: FontWeight.bold, 
            color: isDark ? Colors.white : Colors.black87
          ), 
        ));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(2),
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