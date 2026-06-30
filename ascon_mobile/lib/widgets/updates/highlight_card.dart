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
      width: 120, // ✅ Slightly wider to accommodate the full-bleed aesthetic
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15), 
            blurRadius: 6, 
            offset: const Offset(0, 3)
          )
        ]
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ProgrammeDetailScreen(programme: item)));
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ✅ Full-Bleed Background Image
              image != null 
                  ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
                  : Container(color: Colors.grey[800], child: const Icon(Icons.article, color: Colors.grey)),
                  
              // ✅ Gradient Overlay for Text Readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.85),
                    ],
                    stops: const [0.4, 0.7, 1.0],
                  ),
                ),
              ),

              // ✅ Text safely anchored at the bottom over the dark gradient
              Positioned(
                bottom: 10,
                left: 8,
                right: 8,
                child: Text(
                  title, 
                  maxLines: 2, 
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center, 
                  style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}