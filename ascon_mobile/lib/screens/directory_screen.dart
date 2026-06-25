import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart'; // ✅ ADDED

import '../viewmodels/directory_view_model.dart'; 
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../widgets/shimmer_utils.dart'; 
import '../widgets/robust_avatar.dart'; 
import 'alumni_detail_screen.dart';
import 'chat_screen.dart';

class DirectoryScreen extends ConsumerStatefulWidget {
  const DirectoryScreen({super.key});

  @override
  ConsumerState<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends ConsumerState<DirectoryScreen> {
  final AuthService _authService = AuthService();
  final ApiClient _api = ApiClient(); 
  
  final TextEditingController _searchController = TextEditingController();
  
  String? _myUserId;
  final List<String> _filters = ["All", "Classmates"];
  
  final Set<String> _expandedSections = {}; 

  @override
  void initState() {
    super.initState();
    _getMyId();
  }

  Future<void> _getMyId() async {
    _myUserId = await _authService.currentUserId;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSection(String year) {
    setState(() {
      if (_expandedSections.contains(year)) {
        _expandedSections.remove(year);
      } else {
        _expandedSections.add(year);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(directoryProvider);
    final notifier = ref.read(directoryProvider.notifier);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    if (_searchController.text.isNotEmpty && !_expandedSections.contains("search_active")) {
       _expandedSections.addAll(state.groupedAlumni.keys);
       _expandedSections.add("search_active"); 
    } else if (_searchController.text.isEmpty && _expandedSections.contains("search_active")) {
       _expandedSections.clear(); 
    }

    final sortedKeys = state.groupedAlumni.keys.toList();

    Widget content;

    if (state.isLoadingDirectory && sortedKeys.isEmpty) {
      content = const DirectorySkeleton();
    } 
    else if (sortedKeys.isEmpty && !state.isLoadingDirectory) {
      content = RefreshIndicator(
        onRefresh: () async => await notifier.loadDirectory(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: _buildEmptyState(context, "No alumni found.")
          ),
        ),
      );
    } 
    else {
      List<Map<String, dynamic>> flattenedList = [];
      
      // ✅ MOVED: Insert the Top Connections as the FIRST scrollable item in the list
      final bool showHighlights = state.smartMatches.isNotEmpty && _searchController.text.isEmpty && state.activeFilter == "All";
      if (showHighlights) {
        flattenedList.add({
          'type': 'highlights',
          'data': state.smartMatches
        });
      }

      for (String year in sortedKeys) {
        flattenedList.add({
          'type': 'header', 
          'year': year, 
          'count': state.groupedAlumni[year]?.length ?? 0
        });
        
        if (_expandedSections.contains(year)) {
          final users = state.groupedAlumni[year] ?? [];
          for (var user in users) {
            flattenedList.add({
              'type': 'user', 
              'data': user
            });
          }
        }
      }

      content = RefreshIndicator(
        onRefresh: () async => await notifier.loadDirectory(),
        child: AnimationLimiter(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 40),
            itemCount: flattenedList.length, 
            itemBuilder: (context, index) {
              final item = flattenedList[index];
              Widget listItem;

              // ✅ NEW: Handle rendering the Highlights item
              if (item['type'] == 'highlights') {
                listItem = _buildHighlightHorizon(item['data'], context, isDark);
              }
              else if (item['type'] == 'header') {
                listItem = _buildYearHeader(
                  item['year'], 
                  item['count'], 
                  primaryColor, 
                  isDark, 
                  _expandedSections.contains(item['year'])
                );
              } 
              else {
                final userMap = item['data'] is Map ? Map<String, dynamic>.from(item['data']) : <String, dynamic>{};
                listItem = Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _buildAlumniCard(userMap, context, isDark, primaryColor),
                );
              }

              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: listItem,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Directory", style: GoogleFonts.lato(fontSize: 28, fontWeight: FontWeight.w900, color: textColor)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => notifier.onSearchChanged(val),
                    decoration: InputDecoration(
                      hintText: "Search name, role...",
                      prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              notifier.onSearchChanged("");
                            },
                          )
                        : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((filter) {
                        final bool isSelected = state.activeFilter == filter;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: isSelected,
                            selectedColor: primaryColor.withOpacity(0.15),
                            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
                            side: BorderSide.none,
                            labelStyle: TextStyle(
                              color: isSelected ? primaryColor : Colors.grey[600],
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              fontSize: 13
                            ),
                            onSelected: (val) {
                              if (val) notifier.setFilter(filter);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            
            // ✅ REMOVED the static Highlight Horizon call from here!
            // It now lives inside the Expanded list view below.
            
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  // ✅ HIGHLIGHT HORIZON WIDGET
  Widget _buildHighlightHorizon(List<dynamic> smartMatches, BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Text(
            "Top Connections for You",
            style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
          ),
        ),
        SizedBox(
          height: 145,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: smartMatches.length,
            itemBuilder: (context, index) {
              final match = smartMatches[index];
              return BouncingCard(
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => AlumniDetailScreen(alumniData: match))
                  );
                },
                child: Container(
                  width: 115,
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.15)),
                    boxShadow: [
                      if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 3))
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          RobustAvatar(imageUrl: match['profilePicture'] ?? '', radius: 28),
                          if (match['isOnline'] == true)
                            const Positioned(
                              bottom: 0, right: 0,
                              child: PulsingOnlineDot(), // ✅ Pulse dot deployed here
                            )
                        ],
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          match['fullName'] ?? 'Alumni',
                          style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          match['industry'] ?? match['jobTitle'] ?? 'Member',
                          style: GoogleFonts.lato(color: Colors.grey[500], fontSize: 10),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.1)),
      ],
    );
  }

  Widget _buildYearHeader(String year, int count, Color color, bool isDark, bool isExpanded) {
    return InkWell(
      onTap: () => _toggleSection(year),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), 
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        color: isDark ? Colors.grey[900] : Colors.grey[100], 
        child: Row(
          children: [
            AnimatedRotation(
              turns: isExpanded ? 0.25 : 0.0, 
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Icon(isExpanded ? Icons.folder_open_rounded : Icons.folder_rounded, color: color, size: 22),
            const SizedBox(width: 12),
            Text(
              (year == 'General' || year == 'Others') ? "General Alumni" : "Class of $year", 
              style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text("$count", style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAlumniCard(Map<String, dynamic> user, BuildContext context, bool isDark, Color primaryColor) {
    final String name = user['fullName'] ?? "Alumnus";
    final String job = user['jobTitle'] ?? "";
    final String org = user['organization'] ?? "";
    final String img = user['profilePicture'] ?? "";
    final String userId = user['userId'] ?? user['_id'] ?? '';
    final bool isOnline = user['isOnline'] == true;
    
    if (userId == _myUserId || userId.isEmpty) return const SizedBox.shrink();

    // ✅ FLUID MICRO-INTERACTIONS: Bouncing Tap Wrapper
    return BouncingCard(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => AlumniDetailScreen(alumniData: user))
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: [
                RobustAvatar(imageUrl: img, radius: 30),
                if (isOnline)
                  const Positioned(
                    bottom: 0, right: 0,
                    child: PulsingOnlineDot(), // ✅ Pulse dot deployed here
                  )
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  if (job.isNotEmpty || org.isNotEmpty)
                    Text(
                      "$job${(job.isNotEmpty && org.isNotEmpty) ? ' at ' : ''}$org",
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lato(fontSize: 13, color: Colors.grey[600]),
                    )
                  else 
                    Text("Alumni Member", style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[400], fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.chat_bubble_outline_rounded, color: primaryColor),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (_) => ChatScreen(
                    receiverId: userId,
                    receiverName: name,
                    receiverProfilePic: img,
                    isOnline: isOnline, 
                  ))
                );
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

// =======================================================================
// ✅ NEW WIDGETS FOR FLUID INTERACTIONS AND PULSING DOT
// =======================================================================

class BouncingCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const BouncingCard({Key? key, required this.child, required this.onTap}) : super(key: key);

  @override
  State<BouncingCard> createState() => _BouncingCardState();
}

class _BouncingCardState extends State<BouncingCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override 
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override 
  void dispose() { 
    _controller.dispose(); 
    super.dispose(); 
  }

  @override 
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) { _controller.reverse(); widget.onTap(); },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

class PulsingOnlineDot extends StatefulWidget {
  const PulsingOnlineDot({super.key});

  @override
  State<PulsingOnlineDot> createState() => _PulsingOnlineDotState();
}

class _PulsingOnlineDotState extends State<PulsingOnlineDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override 
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: false);
  }

  @override 
  void dispose() { 
    _controller.dispose(); 
    super.dispose(); 
  }

  @override 
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 1.0 - _controller.value,
              child: Transform.scale(
                scale: 1.0 + (_controller.value * 2.0),
                child: Container(
                  width: 12, height: 12, 
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.greenAccent.withOpacity(0.6))
                ),
              ),
            ),
            Container(
              width: 12, height: 12, 
              decoration: BoxDecoration(
                shape: BoxShape.circle, 
                color: const Color(0xFF00C853), 
                border: Border.all(color: Theme.of(context).cardColor, width: 2)
              )
            ),
          ],
        );
      },
    );
  }
}