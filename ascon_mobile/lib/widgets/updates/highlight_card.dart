import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../screens/programme_detail_screen.dart';

class HighlightCard extends StatelessWidget {
  final Map<String, dynamic> item;
  
  const HighlightCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final title = item['title'] ?? "News";
    final image = item['image'] ?? item['imageUrl'];
    
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ProgrammeDetailScreen(programme: item)));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), 
                child: image != null 
                  ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover, width: double.infinity)
                  : Container(color: Colors.grey[300], child: const Icon(Icons.article, color: Colors.grey)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                title, 
                maxLines: 2, 
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.bold)
              ),
            )
          ],
        ),
      ),
    );
  }
}