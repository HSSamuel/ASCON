import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart'; 

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

  BoxDecoration _getUnifiedCardDecoration(BuildContext context, bool isDark) {
    return BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.2), 
        width: 1
      ),
      boxShadow: [
        if (!isDark) 
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            blurRadius: 8, 
            offset: const Offset(0, 3)
          )
      ],
    );
  }

  void _showMutualConnectionsSheet(BuildContext context, List<dynamic> mutuals) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.5,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3), 
                  borderRadius: BorderRadius.circular(2)
                ),
              ),
              const SizedBox(height: 16),
              Text("Mutual Connections", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Divider(color: Colors.grey.withOpacity(0.1)),
              
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: mutuals.length,
                  itemBuilder: (context, index) {
                    final mutual = mutuals[index] is Map ? Map<String, dynamic>.from(mutuals[index]) : <String, dynamic>{};
                    
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (_) => AlumniDetailScreen(alumniData: mutual)
                          )
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            RobustAvatar(imageUrl: mutual['profilePicture'] ?? '', radius: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                mutual['fullName'] ?? 'Alumni', 
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)
                              )
                            ),
                            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  // ✅ NEW: Extract just the scrollable filters
  Widget _buildScrollableFilters(DirectoryState state, DirectoryNotifier notifier, Color primaryColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SingleChildScrollView(
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
                backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!, width: 0.5),
                labelStyle: GoogleFonts.inter(
                  color: isSelected ? primaryColor : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
    );
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
            child: Column(
              children: [
                _buildScrollableFilters(state, notifier, primaryColor, isDark),
                Expanded(child: _buildEmptyState(context, "No alumni found.")),
              ],
            )
          ),
        ),
      );
    } 
    else {
      List<Map<String, dynamic>> flattenedList = [];
      
      // ✅ Inject Filters as the first scrollable item
      flattenedList.add({'type': 'filters'});

      final bool showHighlights = state.smartMatches.isNotEmpty && _searchController.text.isEmpty && state.activeFilter == "All";
      if (showHighlights) {
        final matches = state.smartMatches.where((u) {
            final uid = u['userId'] ?? u['_id'] ?? '';
            return uid != _myUserId && uid.isNotEmpty;
        }).toList();

        if (matches.isNotEmpty) {
          flattenedList.add({
            'type': 'highlights',
            'data': matches
          });
        }
      }

      for (String year in sortedKeys) {
        final users = (state.groupedAlumni[year] ?? []).where((u) {
            final uid = u['userId'] ?? u['_id'] ?? '';
            return uid != _myUserId && uid.isNotEmpty;
        }).toList();

        if (users.isEmpty) continue; 

        flattenedList.add({
          'type': 'header', 
          'year': year, 
          'count': users.length
        });
        
        if (_expandedSections.contains(year)) {
          flattenedList.add({
            'type': 'user_grid', 
            'data': users
          });
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

              if (item['type'] == 'filters') {
                listItem = _buildScrollableFilters(state, notifier, primaryColor, isDark);
              }
              else if (item['type'] == 'highlights') {
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
              else if (item['type'] == 'user_grid') {
                final List<dynamic> gridUsers = item['data'];
                listItem = Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, 
                      mainAxisExtent: 280,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: gridUsers.length,
                    itemBuilder: (context, gridIndex) {
                      final userMap = gridUsers[gridIndex] is Map ? Map<String, dynamic>.from(gridUsers[gridIndex]) : <String, dynamic>{};
                      return _buildGridAlumniCard(userMap, context, isDark, primaryColor);
                    },
                  ),
                );
              } else {
                listItem = const SizedBox.shrink();
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
          children: [
            // ✅ PINNED HEADER AND SEARCH BAR
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05), 
                    blurRadius: 10, 
                    offset: const Offset(0, 4)
                  )
                ]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Directory", style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: textColor)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => notifier.onSearchChanged(val),
                    style: GoogleFonts.inter(),
                    decoration: InputDecoration(
                      hintText: "Search name, role...",
                      hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
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
                ],
              ),
            ),
            
            // ✅ SCROLLABLE CONTENT (Filters + Cards)
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightHorizon(List<dynamic> smartMatches, BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Text(
            "Top Connections for You",
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Theme.of(context).primaryColor),
          ),
        ),
        SizedBox(
          height: 280, 
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: smartMatches.length,
            itemBuilder: (context, index) {
              final match = smartMatches[index];
              return Container(
                width: 170, 
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: _buildGridAlumniCard(match, context, isDark, Theme.of(context).primaryColor),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
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
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: isDark ? Colors.white : Colors.black87)
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text("$count", style: GoogleFonts.inter(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGridAlumniCard(Map<String, dynamic> user, BuildContext context, bool isDark, Color primaryColor) {
    final String name = user['fullName'] ?? "Alumnus";
    final String job = user['jobTitle'] ?? "";
    final String org = user['organization'] ?? "";
    final String img = user['profilePicture'] ?? "";
    final String userId = user['userId'] ?? user['_id'] ?? '';
    final bool isOnline = user['isOnline'] == true;

    final List<dynamic> mutuals = user['mutualConnections'] ?? [];
    String mutualText = "Mutual Connection"; 
    String mutualAvatar = "";

    if (mutuals.isNotEmpty) {
      final firstMutual = mutuals[0];
      final String firstName = firstMutual['fullName']?.split(' ')[0] ?? "Alumni";
      mutualAvatar = firstMutual['profilePicture'] ?? "";

      if (mutuals.length == 1) {
        mutualText = "$firstName is a mutual connection";
      } else {
        final int others = mutuals.length - 1;
        mutualText = "$firstName and $others other mutual connection${others > 1 ? 's' : ''}";
      }
    }

    return BouncingCard(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => AlumniDetailScreen(alumniData: user))
        );
      },
      child: Container(
        decoration: _getUnifiedCardDecoration(context, isDark),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 95,
                child: Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 55,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withOpacity(0.4), 
                            primaryColor.withOpacity(0.8)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).cardColor, width: 3),
                        ),
                        child: Stack(
                          children: [
                            RobustAvatar(imageUrl: img, radius: 34),
                            if (isOnline)
                              const Positioned(
                                bottom: 2, right: 2,
                                child: PulsingOnlineDot(), 
                              )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800, 
                          fontSize: 13.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.verified_outlined, size: 14, color: Colors.grey[600]),
                    ), 
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Text(
                  job.isNotEmpty ? "$job${org.isNotEmpty ? ' | $org' : ''}" : "ASCON Alumni Member",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5, 
                    color: isDark ? Colors.grey[300] : Colors.blueGrey[800], 
                    height: 1.3
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              
              const Spacer(),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      if (mutuals.isNotEmpty) {
                        _showMutualConnectionsSheet(context, mutuals);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        children: [
                          RobustAvatar(imageUrl: mutualAvatar, radius: 10), 
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              mutualText,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                                fontSize: 9.5, 
                                color: isDark ? Colors.grey[400] : Colors.grey[800]
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10), 
                child: SizedBox(
                  width: double.infinity,
                  height: 28, 
                  child: OutlinedButton.icon(
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
                    icon: Icon(Icons.person_add_alt_1, size: 14, color: primaryColor), 
                    label: Text("Connect", style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 11, color: primaryColor)), 
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryColor, width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 2), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8), 
            ],
          ),
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
          Text(message, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

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
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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