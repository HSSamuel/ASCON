import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'highlight_card.dart';

class HighlightsSection extends StatelessWidget {
  final List<dynamic> highlights;
  final bool isSearching;

  const HighlightsSection({super.key, required this.highlights, required this.isSearching});

  @override
  Widget build(BuildContext context) {
    if (highlights.isEmpty || isSearching) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Text("Highlights", style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: highlights.length,
              itemBuilder: (context, index) => HighlightCard(item: highlights[index]),
            ),
          ),
          const Divider(height: 30, thickness: 0.5),
        ],
      ),
    );
  }
}