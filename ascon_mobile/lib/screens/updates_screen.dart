import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';

import '../viewmodels/updates_view_model.dart';
import '../widgets/updates/post_card.dart';
import '../widgets/updates/sheets/create_post_sheet.dart';
import '../widgets/updates/updates_sliver_app_bar.dart';
import '../widgets/updates/highlights_section.dart';

class UpdatesScreen extends ConsumerWidget {
  const UpdatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updatesProvider);
    final notifier = ref.read(updatesProvider.notifier);
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          const UpdatesSliverAppBar(), 
        ],
        body: RefreshIndicator(
          onRefresh: () async {
            if (!kIsWeb) Vibration.hasVibrator().then((v) { if (v ?? false) Vibration.vibrate(duration: 15); });
            await notifier.loadData();
          },
          color: const Color(0xFFD4AF37),
          child: CustomScrollView(
            slivers: [
              HighlightsSection(highlights: updateState.highlights, isSearching: false),

              if (updateState.showMediaOnly)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                        decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), 
                        child: Text("Media Only", style: TextStyle(fontSize: 12, color: primaryColor))
                      ),
                    ),
                  ),
                ),

              if (updateState.isLoading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (updateState.filteredPosts.isEmpty)
                SliverFillRemaining(child: Center(child: Text("No updates.", style: GoogleFonts.lato(color: Colors.grey))))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => PostCard(
                      post: updateState.filteredPosts[index], 
                      isAdmin: updateState.isAdmin, 
                      myId: updateState.currentUserId
                    ),
                    childCount: updateState.filteredPosts.length,
                  ),
                ),
                
              // ✅ FIX: Increased padding to 120 so the final post clears both the bottom nav AND the raised FAB
              const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
            ],
          ),
        ),
      ),
      
      // ✅ FIX: Force the location and add padding to clear the Bottom Navigation Bar
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 40.0), 
        child: FloatingActionButton(
          heroTag: 'updates_fab_tag',
          onPressed: () => CreatePostSheet.show(context),
          backgroundColor: const Color(0xFFD4AF37),
          elevation: 4, // Added subtle elevation for better depth
          child: const Icon(Icons.edit, color: Colors.white),
        ),
      ),
    );
  }
}