import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/event_detail_screen.dart';
import '../widgets/skeleton_loader.dart';

class EventCard extends StatelessWidget {
  final dynamic event;
  final bool isAdmin;
  final Function(String) onDelete;

  const EventCard({
    super.key, 
    required this.event, 
    this.isAdmin = false, 
    required this.onDelete
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    String formattedDate = 'TBA';
    String rawDate = event['date']?.toString() ?? '';
    try {
      if (rawDate.isNotEmpty) {
        formattedDate = DateFormat("d MMM").format(DateTime.parse(rawDate));
      }
    } catch (e) {
      formattedDate = 'TBA';
    }

    final String title = event['title']?.toString() ?? 'No Title';
    final String type = event['type'] ?? 'News';
    
    // ✅ Safely extract from multiple sources
    String imageUrl = event['image'] ?? event['imageUrl'] ?? '';
    if (imageUrl.isEmpty && event['images'] != null && event['images'] is List && event['images'].isNotEmpty) {
      imageUrl = event['images'][0].toString();
    }

    final String eventId = (event['_id'] ?? event['id'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.15),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildSafeImage(imageUrl),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.95)
                  ],
                  stops: const [0.4, 0.6, 0.85, 1.0],
                ),
              ),
            ),
            
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    final Map<String, dynamic> safeEventData = {
                      ...event,
                      '_id': eventId,
                      'date': formattedDate,
                      'rawDate': rawDate
                    };
                    Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                            builder: (context) =>
                                EventDetailScreen(eventData: safeEventData)));
                  },
                ),
              ),
            ),

            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: _getTypeColor(type),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2))
                    ]),
                child: Text(type.toUpperCase(),
                    style: GoogleFonts.lato(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5)),
              ),
            ),
            
            if (isAdmin)
              Positioned(
                top: 5,
                left: 5,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  radius: 16,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.delete,
                        color: Colors.redAccent, size: 18),
                    onPressed: () => onDelete(eventId),
                  ),
                ),
              ),
              
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today,
                            size: 10, color: Colors.white.withOpacity(0.8)),
                        const SizedBox(width: 4),
                        Text(formattedDate.toUpperCase(),
                            style: GoogleFonts.lato(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.9),
                                letterSpacing: 0.5)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(_toTitleCase(title),
                        maxLines: 3,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lato(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafeImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
          color: Colors.grey[900],
          child: const Center(
              child: Icon(Icons.image_not_supported_outlined,
                  color: Colors.white24, size: 40)));
    }
    if (imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => const SkeletonImage(),
        errorWidget: (context, url, error) => Container(
            color: Colors.grey[900],
            child: const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: Colors.white24, size: 40))),
      );
    }
    try {
      String cleanBase64 =
          imageUrl.contains(',') ? imageUrl.split(',').last : imageUrl;
      return Image.memory(base64Decode(cleanBase64),
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(
              color: Colors.grey[900],
              child: const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: Colors.white24, size: 40))));
    } catch (e) {
      return Container(
          color: Colors.grey[900],
          child: const Center(
              child: Icon(Icons.error_outline,
                  color: Colors.white24, size: 40)));
    }
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    String titleCased = text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
    return titleCased.replaceAllMapped(RegExp(r'\bascon\b', caseSensitive: false),
        (match) => 'ASCON');
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Reunion': return const Color(0xFF1B5E3A);
      case 'Webinar': return const Color(0xFF1565C0);
      case 'Seminar': return const Color(0xFF6A1B9A);
      case 'News': return const Color(0xFFE65100);
      case 'Conference': return const Color(0xFF0D47A1);
      case 'Workshop': return const Color(0xFF00695C);
      case 'Symposium': return const Color(0xFFC2185B);
      case 'AGM': return const Color(0xFFF57F17);
      case 'Induction': return const Color(0xFF2E7D32);
      case 'Event': return const Color(0xFF283593);
      default: return Colors.grey[800]!;
    }
  }
}