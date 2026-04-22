import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../viewmodels/updates_view_model.dart';

class UpdatesSliverAppBar extends ConsumerStatefulWidget {
  const UpdatesSliverAppBar({super.key});

  @override
  ConsumerState<UpdatesSliverAppBar> createState() => _UpdatesSliverAppBarState();
}

class _UpdatesSliverAppBarState extends ConsumerState<UpdatesSliverAppBar> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(updatesProvider);
    final notifier = ref.read(updatesProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverAppBar(
      backgroundColor: Theme.of(context).cardColor, 
      shadowColor: Colors.black.withOpacity(0.1),
      elevation: 2.0, 
      foregroundColor: isDark ? Colors.white : Colors.black,
      floating: true,
      snap: true,
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Search updates...",
                border: InputBorder.none,
                hintStyle: GoogleFonts.lato(fontSize: 18),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[100], 
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
              style: GoogleFonts.lato(fontSize: 18, color: isDark ? Colors.white : Colors.black),
              onChanged: notifier.searchPosts,
            )
          : Text("Updates", style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 24, color: isDark ? Colors.white : Colors.black)),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search),
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchController.clear();
                notifier.searchPosts(""); 
              }
            });
          },
        ),
        PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'refresh') notifier.loadData();
            if (val == 'filter') notifier.toggleMediaFilter();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'refresh', child: Row(children: [Icon(Icons.refresh, size: 20), SizedBox(width: 10), Text("Refresh")])),
            PopupMenuItem(value: 'filter', child: Row(children: [Icon(updateState.showMediaOnly ? Icons.check_box : Icons.check_box_outline_blank, size: 20), SizedBox(width: 10), const Text("Media Only")])),
          ],
        ),
      ],
    );
  }
}