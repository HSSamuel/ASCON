import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../viewmodels/directory_view_model.dart';
import 'alumni_card.dart';

class SmartMatchTab extends StatelessWidget {
  final DirectoryViewModel viewModel;

  const SmartMatchTab({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return RefreshIndicator(
      onRefresh: viewModel.loadSmartMatches,
      color: primaryColor,
      child: viewModel.isLoadingMatches
          ? const Center(child: CircularProgressIndicator())
          : viewModel.smartMatches.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: viewModel.smartMatches.length,
                  itemBuilder: (context, index) {
                    final user = viewModel.smartMatches[index];
                    final score = user['matchScore'] ?? 0;
                    return AlumniCard(user: user, badgeText: "$score% Match");
                  },
                ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 50, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            "No matches found.\nUpdate your Industry & Skills in Profile.",
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}