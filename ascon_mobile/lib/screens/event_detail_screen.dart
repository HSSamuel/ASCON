import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'event_registration_screen.dart';
import '../services/data_service.dart';

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> eventData;

  const EventDetailScreen({super.key, required this.eventData});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Map<String, dynamic> _event;
  bool _isLoading = false;
  final DataService _dataService = DataService();
  int _currentImageIndex = 0; // ✅ For the image carousel indicator

  @override
  void initState() {
    super.initState();
    _event = widget.eventData;

    final String? idToFetch = _event['id'] ?? _event['_id'];
    if ((_event['date'] == null || _event['description'] == null) && idToFetch != null) {
      _fetchFullEventDetails(idToFetch);
    }
  }

  Future<void> _fetchFullEventDetails(String id) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final fullData = await _dataService.fetchEventById(id);
      if (fullData != null && mounted) {
        setState(() {
          _event = fullData;
        });
      }
    } catch (e) {
      debugPrint("Error fetching event details: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSafeImage(String? imageUrl, {BoxFit fit = BoxFit.cover}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(color: Colors.grey[800]);
    }

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: fit,
        errorBuilder: (c, e, s) => Container(color: Colors.grey[800]),
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
        errorBuilder: (c, e, s) => Container(color: Colors.grey[800]),
      );
    } catch (e) {
      return Container(color: Colors.grey[800]);
    }
  }

  void _openFullScreenImage(String imageUrl) {
    if (imageUrl.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final dividerColor = Theme.of(context).dividerColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ Process Multiple Images safely
    List<String> images = [];
    if (_event['images'] != null && _event['images'] is List && _event['images'].isNotEmpty) {
      images = List<String>.from(_event['images']);
    } else if (_event['image'] != null && _event['image'].toString().isNotEmpty) {
      images = [_event['image'].toString()];
    } else if (_event['imageUrl'] != null && _event['imageUrl'].toString().isNotEmpty) {
      images = [_event['imageUrl'].toString()];
    }

    final String title = _event['title'] ?? 'Event Details';
    
    final String location = (_event['location'] != null && _event['location'].toString().isNotEmpty)
        ? _event['location']
        : 'ASCON Complex, Topo-Badagry';

    final String description = _event['description'] != null && _event['description']!.isNotEmpty
        ? _event['description']!
        : "No detailed description available.";

    final String eventType = _event['type'] ?? 'News';
    final bool isRegistrable = eventType != 'News';

    final String eventId = (_event['_id'] ?? 
                            _event['id'] ?? 
                            widget.eventData['_id'] ?? 
                            widget.eventData['id'] ?? 
                            '').toString();

    // DATE FORMATTING
    String formattedDate = 'Date to be announced';
    String rawDateString = _event['rawDate'] ?? _event['date'] ?? '';
    DateTime? eventDateObject;

    if (rawDateString.isNotEmpty) {
      try {
        eventDateObject = DateTime.parse(rawDateString);
        formattedDate = DateFormat("EEEE, d MMM y").format(eventDateObject);
      } catch (e) {
        if (_event['date'] != null && _event['date'].toString().length > 5) {
           formattedDate = _event['date'];
        }
      }
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280.0,
            pinned: true,
            backgroundColor: primaryColor,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                  child: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
                ),
                onPressed: () {
                  final String shareText = 
                    "🏛️ *ASCON ALUMNI UPDATE* 🏛️\n\n"
                    "🔔 *${title.toUpperCase()}*\n\n"
                    "📅 *Date:* $formattedDate\n"
                    "📍 *Location:* $location\n\n"
                    "${description.length > 200 ? "${description.substring(0, 200)}..." : description}\n\n"
                    "📲 _Get the full details and register on the ASCON Alumni App._";
                  
                  Share.share(shareText, subject: "ASCON Alumni: $title");
                },
              ),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // ✅ MULTIPLE IMAGES CAROUSEL
                  if (images.isNotEmpty)
                    PageView.builder(
                      itemCount: images.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => _openFullScreenImage(images[index]),
                          child: _buildSafeImage(images[index]),
                        );
                      },
                    )
                  else
                    Container(color: Colors.grey[800]), // Fallback if no images
                    
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),

                  // ✅ PAGE INDICATOR FOR MULTIPLE IMAGES
                  if (images.length > 1)
                    Positioned(
                      bottom: 30,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(images.length, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentImageIndex == index ? 12 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _currentImageIndex == index ? Colors.white : Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ),

                  // "VIEW PHOTO" BADGE
                  if (images.isNotEmpty)
                    Positioned(
                      bottom: 40,
                      right: 16,
                      child: GestureDetector(
                        onTap: () => _openFullScreenImage(images[_currentImageIndex]),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.fullscreen, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                "View Photo",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 2. CONTENT BODY
          SliverToBoxAdapter(
            child: Container(
              transform: Matrix4.translationValues(0, -20, 0),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: dividerColor.withOpacity(0.1), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      eventType.toUpperCase(),
                      style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold, color: primaryColor, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Text(
                    title,
                    style: GoogleFonts.lato(fontSize: 24, fontWeight: FontWeight.w800, color: textColor, height: 1.2),
                  ),
                  const SizedBox(height: 24),
                  
                  _buildInfoRow(context, Icons.calendar_today_outlined, "Date", formattedDate),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(color: dividerColor.withOpacity(0.5), height: 1),
                  ),
                  
                  _buildInfoRow(context, Icons.location_on_outlined, "Location", location),
                  
                  const SizedBox(height: 30),
                  
                  Text("About Event", style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 12),
                  
                  _buildFormattedDescription(description, isDark, primaryColor),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isRegistrable 
        ? Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SafeArea(
              child: SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventRegistrationScreen(
                          eventId: eventId, 
                          eventTitle: title,
                          eventType: eventType,
                          eventImage: images.isNotEmpty ? images.first : '',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Register Now", style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          )
        : null,
    );
  }

  Widget _buildFormattedDescription(String text, bool isDark, Color linkColor) {
    final baseStyle = GoogleFonts.lato(
      fontSize: 15, 
      height: 1.6, 
      color: isDark ? Colors.grey[300] : Colors.grey[700]
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
                    _parseRichText(paragraph.substring(2), baseStyle, linkColor, isDark),
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
            _parseRichText(paragraph, baseStyle, linkColor, isDark),
            textAlign: TextAlign.justify,
          ),
        );
      }).toList(),
    );
  }

  TextSpan _parseRichText(String text, TextStyle baseStyle, Color linkColor, bool isDark) {
    List<TextSpan> spans = [];
    
    final regex = RegExp(
      r'\*\*(.*?)\*\*|\*(.*?)\*|((https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([-a-zA-Z0-9@:%_\+.~#?&//=]*))',
      caseSensitive: false,
    );

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
      } else if (match.group(3) != null) {
        String url = match.group(3)!;
        if (url.endsWith(')') || url.endsWith('.')) {
           url = url.substring(0, url.length - 1);
        }

        spans.add(TextSpan(
          text: url,
          style: baseStyle.copyWith(
            color: linkColor, 
            decoration: TextDecoration.underline,
            decorationColor: linkColor.withOpacity(0.5),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final Uri uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
              try {
                if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                   debugPrint("Could not launch $uri");
                }
              } catch (e) {
                debugPrint("Error launching URL: $e");
              }
            },
        ));
      }
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return TextSpan(style: baseStyle, children: spans);
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final primaryColor = Theme.of(context).primaryColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: primaryColor.withOpacity(0.05), shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: primaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.bold, color: subTextColor?.withOpacity(0.7), letterSpacing: 1.0),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w600, color: textColor, height: 1.3),
              ),
            ],
          ),
        ),
      ],
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