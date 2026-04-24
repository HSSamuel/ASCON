import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

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
  final List<String> _filters = ["All", "Mentors", "Classmates", "Near Me"];
  
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

    if (state.activeFilter == "Near Me") {
      if (state.isLoadingNearMe && state.nearbyAlumni.isEmpty) {
        content = const DirectorySkeleton();
      } 
      else if (state.nearbyAlumni.isEmpty && !state.isLoadingNearMe) {
        content = RefreshIndicator(
          onRefresh: () async => await notifier.loadNearMe(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildEmptyState(context, "No alumni found nearby. Try another city.")
            ),
          ),
        );
      } 
      else {
        content = RefreshIndicator(
          onRefresh: () async => await notifier.loadNearMe(),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(), 
            padding: const EdgeInsets.all(16),
            itemCount: state.nearbyAlumni.length,
            itemBuilder: (context, index) {
              final rawUser = state.nearbyAlumni[index];
              final userMap = rawUser is Map ? Map<String, dynamic>.from(rawUser) : <String, dynamic>{};
              return _buildAlumniCard(userMap, context, isDark, primaryColor, showLocation: true);
            },
          ),
        );
      }
    } else {
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
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 40),
            itemCount: flattenedList.length, 
            itemBuilder: (context, index) {
              final item = flattenedList[index];

              if (item['type'] == 'header') {
                return _buildYearHeader(
                  item['year'], 
                  item['count'], 
                  primaryColor, 
                  isDark, 
                  _expandedSections.contains(item['year'])
                );
              } 
              else {
                final userMap = item['data'] is Map ? Map<String, dynamic>.from(item['data']) : <String, dynamic>{};
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _buildAlumniCard(userMap, context, isDark, primaryColor),
                );
              }
            },
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
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
                  
                  // ✅ RESTORED: Near Me City Filter UI
                  if (state.activeFilter == "Near Me") ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.my_location, size: 16, color: primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextField(
                              onSubmitted: (val) {
                                notifier.setNearMeFilter(val);
                                notifier.loadNearMe(city: val);
                              },
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: "Enter your city (e.g. Lagos, Abuja)...",
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(bottom: 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
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

  Widget _buildAlumniCard(Map<String, dynamic> user, BuildContext context, bool isDark, Color primaryColor, {bool showLocation = false}) {
    final String name = user['fullName'] ?? "Alumnus";
    final String job = user['jobTitle'] ?? "";
    final String org = user['organization'] ?? "";
    final String img = user['profilePicture'] ?? "";
    final String city = user['city'] ?? "";
    final String state = user['state'] ?? "";
    final bool isMentor = user['isOpenToMentorship'] == true;
    final String userId = user['userId'] ?? user['_id'] ?? '';
    
    if (userId == _myUserId || userId.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => AlumniDetailScreen(alumniData: user))
        );
      },
      child: Container(
        margin: showLocation ? const EdgeInsets.only(bottom: 12) : null,
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
                if (isMentor)
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.amber[700], shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                      child: const Icon(Icons.star, color: Colors.white, size: 10),
                    ),
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
                  
                  if (showLocation && (city.isNotEmpty || state.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, size: 12, color: primaryColor),
                          const SizedBox(width: 4),
                          Text("$city${(city.isNotEmpty && state.isNotEmpty) ? ', ' : ''}$state", style: TextStyle(fontSize: 11, color: primaryColor)),
                        ],
                      ),
                    )
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
                    isOnline: false, 
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