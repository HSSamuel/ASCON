import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter/rendering.dart'; 
import 'package:google_fonts/google_fonts.dart'; 
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';
import '../router.dart'; 
import 'event_detail_screen.dart';
import 'programme_detail_screen.dart';
import 'alumni_detail_screen.dart';
import 'about_screen.dart';
import 'admin/add_content_screen.dart'; 
import 'welcome_dialog.dart'; 

import '../widgets/celebration_card.dart'; 
import '../widgets/chapter_card.dart';     
import '../widgets/digital_id_card.dart';
import '../widgets/shimmer_utils.dart';

import '../viewmodels/dashboard_view_model.dart';
import '../viewmodels/events_view_model.dart'; 
import '../viewmodels/badge_view_model.dart'; 
import '../services/notification_service.dart';
import '../services/auth_service.dart'; 

class HomeScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  
  const HomeScreen({super.key, required this.navigationShell});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  DateTime? _lastPressedAt;
  bool _isBottomNavVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstTimeWelcome());

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) NotificationService().requestPermission();
    });
  }

  Future<void> _checkFirstTimeWelcome() async {
    final userMap = await AuthService().getCachedUser();
    if (userMap == null) return;

    final bool hasSeenWelcome = userMap['hasSeenWelcome'] ?? false;

    if (!hasSeenWelcome && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WelcomeDialog(
          userName: userMap['fullName'] ?? "Alumni",
          onGetStarted: () async {
            try {
              await AuthService().markWelcomeSeen(); 
            } catch (e) {
              debugPrint("Welcome status update error: $e");
            }
            if (mounted) Navigator.pop(context);
          }, 
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(badgeProvider.notifier).refreshBadges(); 
    }
  }

  void _goBranch(int index) {
    if (index == widget.navigationShell.currentIndex) {
      if (index == 0) {
        ref.read(dashboardProvider.notifier).loadData(isRefresh: true);
      }
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Future<void> _handleBackPress() async {
    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      return;
    }

    final int currentIndex = widget.navigationShell.currentIndex;
    GlobalKey<NavigatorState>? currentNavigatorKey;
    switch (currentIndex) {
      case 0: currentNavigatorKey = homeNavKey; break;
      case 1: currentNavigatorKey = eventsNavKey; break;
      case 2: currentNavigatorKey = updatesNavKey; break;
      case 3: currentNavigatorKey = directoryNavKey; break;
      case 4: currentNavigatorKey = profileNavKey; break;
    }

    if (currentNavigatorKey != null && 
        currentNavigatorKey.currentState != null && 
        currentNavigatorKey.currentState!.canPop()) {
      currentNavigatorKey.currentState!.pop();
      return; 
    }

    if (currentIndex != 0) {
      _goBranch(0);
      return; 
    }

    final now = DateTime.now();
    if (_lastPressedAt == null || now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
      _lastPressedAt = now;
      ScaffoldMessenger.of(context).clearSnackBars(); 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Press back again to exit"),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return; 
    }
    SystemNavigator.pop();
  }

  // ✅ FIXED: Removed the debounce timer so it fires immediately again
  void _onScroll(UserScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
      if (notification.direction == ScrollDirection.forward) {
        if (!_isBottomNavVisible) setState(() => _isBottomNavVisible = true);
      } else if (notification.direction == ScrollDirection.reverse) {
        if (_isBottomNavVisible) setState(() => _isBottomNavVisible = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final navBarColor = Theme.of(context).cardColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final uiIndex = widget.navigationShell.currentIndex;
    final showAppBar = uiIndex == 0;
    
    final badgeState = ref.watch(badgeProvider);

    return PopScope(
      canPop: false, 
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackPress();
      },
      child: Scaffold(
        extendBody: true, 
        appBar: showAppBar 
          ? AppBar(
              title: Text("Dashboard", style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : primaryColor)),
              backgroundColor: Theme.of(context).cardColor,
              elevation: 0,
              automaticallyImplyLeading: false,
              actions: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chat_bubble_outline_rounded, color: isDark ? Colors.white : primaryColor, size: 22),
                      onPressed: () {
                        ref.read(badgeProvider.notifier).clearMessageBadge(); 
                        context.push('/chat').then((_) => ref.read(badgeProvider.notifier).refreshBadges());
                      },
                    ),
                    if (badgeState.hasUnreadMessages || badgeState.missedCallsCount > 0)
                      Positioned(
                        right: 8, top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red, 
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).cardColor, width: 1.5)
                          ),
                          constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                          child: badgeState.missedCallsCount > 0 
                            ? Center(
                                child: Text(
                                  '${badgeState.missedCallsCount}',
                                  style: const TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : null, 
                        ),
                      )
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.info_outline, color: isDark ? Colors.white : primaryColor, size: 22),
                  onPressed: () => context.push('/about'),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: IconButton(
                    tooltip: 'Switch Theme',
                    icon: ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeNotifier,
                      builder: (context, currentMode, _) {
                        bool isCurrentlyDark = currentMode == ThemeMode.dark || (currentMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
                        return Icon(isCurrentlyDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: isDark ? Colors.white : primaryColor, size: 22);
                      },
                    ),
                    onPressed: () => themeNotifier.value = themeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
                  ),
                ),
              ],
            )
          : null, 

        body: NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            _onScroll(notification);
            return false; 
          },
          child: widget.navigationShell,
        ),

        floatingActionButton: isKeyboardOpen 
          ? null 
          : AnimatedSlide(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              offset: _isBottomNavVisible ? Offset.zero : const Offset(0, 2.5),
              child: SizedBox(
                width: 42, height: 42, 
                child: FloatingActionButton(
                  heroTag: "main_dashboard_fab",
                  onPressed: () => _goBranch(2), 
                  backgroundColor: uiIndex == 2 ? primaryColor : Colors.grey,
                  elevation: 3.0, 
                  shape: const CircleBorder(),
                  child: const Icon(Icons.dynamic_feed, color: Colors.white, size: 20),
                ),
              ),
            ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        
        bottomNavigationBar: isKeyboardOpen 
          ? null 
          : AnimatedSlide(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              offset: _isBottomNavVisible ? Offset.zero : const Offset(0, 1.5),
              child: SizedBox(
                height: 56, 
                child: BottomAppBar(
                  shape: const CircularNotchedRectangle(),
                  notchMargin: 5.0, 
                  color: navBarColor,
                  elevation: 8, 
                  shadowColor: Colors.black.withOpacity(0.1),
                  clipBehavior: Clip.antiAlias,
                  padding: EdgeInsets.zero,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      _buildNavItem(label: "Home", icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, index: 0, color: primaryColor, currentIndex: uiIndex),
                      _buildNavItem(label: "Events", icon: Icons.event_outlined, activeIcon: Icons.event, index: 1, color: primaryColor, currentIndex: uiIndex),
                      const SizedBox(width: 42), 
                      _buildNavItem(label: "Directory", icon: Icons.list_alt, activeIcon: Icons.list, index: 3, color: primaryColor, currentIndex: uiIndex),
                      _buildNavItem(label: "Profile", icon: Icons.person_outline, activeIcon: Icons.person, index: 4, color: primaryColor, currentIndex: uiIndex),
                    ],
                  ),
                ),
              ),
            ),
      ),
    );
  }
  
  Widget _buildNavItem({required String label, required IconData icon, required IconData activeIcon, required int index, required Color color, required int currentIndex}) {
    final isSelected = currentIndex == index;
    return InkWell(
      onTap: () => _goBranch(index),
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? activeIcon : icon, color: isSelected ? color : Colors.grey[400], size: 20),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.lato(fontSize: 9, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? color : Colors.grey[400])),
          ],
        ),
      ),
    );
  }
}

class DashboardView extends ConsumerStatefulWidget {
  final String? userName; 
  const DashboardView({super.key, this.userName});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  String _displayName = "Alumni";
  bool _isAdmin = false; 
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(dashboardProvider.notifier).loadData());
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('user_name');
    final isAdmin = await AuthService().isAdmin; 
    final userId = await AuthService().currentUserId; 
    
    if (mounted) {
      setState(() {
        if (saved != null) _displayName = saved;
        _isAdmin = isAdmin;
        _currentUserId = userId; 
      });
    }
  }

  Future<void> _deleteProgramme(String id) async {
    final confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Programme?"),
        content: const Text("Are you sure? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref.read(eventsProvider.notifier).deleteProgramme(id);
      if (success) {
        ref.read(dashboardProvider.notifier).loadData(isRefresh: true);
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Programme deleted")));
      }
    }
  }

  Widget _buildSafeImage(String? imageUrl, {IconData fallbackIcon = Icons.image, BoxFit fit = BoxFit.cover}) {
    if (imageUrl == null || imageUrl.isEmpty) return _buildPlaceholder(fallbackIcon);
    if (imageUrl.contains('profile/picture/1') || imageUrl.contains('googleusercontent.com')) return _buildPlaceholder(fallbackIcon);
    if (kIsWeb && imageUrl.startsWith('http')) {
       return Image.network(
         imageUrl, fit: fit, errorBuilder: (context, error, stackTrace) => _buildPlaceholder(Icons.broken_image_rounded),
         loadingBuilder: (context, child, loadingProgress) => loadingProgress == null ? child : Container(color: Colors.grey[200]),
       );
    }
    if (imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl, fit: fit, memCacheWidth: 300, 
        placeholder: (context, url) => Container(color: Colors.grey[200]),
        errorWidget: (context, url, error) => _buildPlaceholder(Icons.broken_image),
      );
    }
    try {
      if (imageUrl.length > 100 && !imageUrl.startsWith('http')) {
        String cleanBase64 = imageUrl;
        if (cleanBase64.contains(',')) cleanBase64 = cleanBase64.split(',').last;
        return Image.memory(base64Decode(cleanBase64), fit: fit, gaplessPlayback: true, errorBuilder: (c, e, s) => _buildPlaceholder(Icons.broken_image));
      }
    } catch (e) {}
    return _buildPlaceholder(fallbackIcon);
  }

  Widget _buildPlaceholder(IconData icon) => Container(color: Colors.grey[200], child: Center(child: Icon(icon, color: Colors.grey[400], size: 40)));

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final dashboardState = ref.watch(dashboardProvider);

    // ✅ Filters out the current user dynamically
    final filteredAlumni = dashboardState.topAlumni.where((alumni) {
      final String id = (alumni['userId'] ?? alumni['_id'] ?? "").toString();
      return id != _currentUserId; 
    }).toList();

    if (dashboardState.isLoading && filteredAlumni.isEmpty) {
       return Scaffold(backgroundColor: scaffoldBg, body: const SafeArea(child: DashboardSkeleton()));
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => await ref.read(dashboardProvider.notifier).loadData(isRefresh: true),
          color: primaryColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dashboardState.errorMessage != null)
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(8), color: Colors.redAccent,
                    child: Text(dashboardState.errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center),
                  ),

                DigitalIDCard(userName: _displayName, programme: dashboardState.programme, year: dashboardState.year, alumniID: dashboardState.alumniID, imageUrl: dashboardState.profileImage),
                const ChapterCard(),
                const CelebrationWidget(),
                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Alumni Network", style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                      Icon(Icons.shuffle, size: 16, color: Colors.grey[400]), 
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                if (dashboardState.isLoading && filteredAlumni.isNotEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                else if (filteredAlumni.isEmpty && !dashboardState.isLoading)
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text("No recently active alumni found.", style: GoogleFonts.lato(color: Colors.grey)))
                else
                  SizedBox(
                    height: 90, 
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredAlumni.length > 20 ? 20 : filteredAlumni.length, 
                      itemBuilder: (context, index) {
                        final alumni = filteredAlumni[index];
                        final String name = alumni['fullName'] ?? "User";
                        final String img = alumni['profilePicture'] ?? "";
                        final String firstName = name.split(" ")[0];

                        return GestureDetector(
                          onTap: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => AlumniDetailScreen(alumniData: alumni))),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 20.0),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: primaryColor.withOpacity(0.5), width: 2)),
                                  child: CircleAvatar(radius: 28, backgroundColor: Colors.grey[200], child: ClipOval(child: SizedBox(width: 56, height: 56, child: _buildSafeImage(img, fallbackIcon: Icons.person)))),
                                ),
                                const SizedBox(height: 6),
                                Text(firstName, style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w500, color: textColor)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 25),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Recent & Upcoming Events", style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
                      Row(children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle)), const SizedBox(width: 4),
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: const Color(0xFF4CAF50).withOpacity(0.5), shape: BoxShape.circle)),
                      ])
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (dashboardState.isLoading && dashboardState.events.isNotEmpty)
                  const SizedBox.shrink()
                else if (dashboardState.events.isEmpty && !dashboardState.isLoading)
                  _buildEmptyState("No upcoming events")
                else
                  ListView.separated(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: dashboardState.events.length, separatorBuilder: (c, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildUpcomingEventCard(context, dashboardState.events[index]),
                  ),
                const SizedBox(height: 25),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Programme Updates", style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
                      if (_isAdmin)
                        IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddContentScreen(type: 'Programme'))), tooltip: "Add Programme")
                      else
                        Row(children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF607D8B), shape: BoxShape.circle)), const SizedBox(width: 4),
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: const Color(0xFF607D8B).withOpacity(0.5), shape: BoxShape.circle)),
                        ])
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                if (dashboardState.isLoading && dashboardState.programmes.isNotEmpty)
                  const SizedBox.shrink()
                else if (dashboardState.programmes.isEmpty && !dashboardState.isLoading)
                  _buildEmptyState("No updates available")
                else
                  ListView.separated(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: dashboardState.programmes.length > 3 ? 3 : dashboardState.programmes.length, separatorBuilder: (c, i) => const SizedBox(height: 16),
                    itemBuilder: (context, index) => _buildNewsUpdateCard(context, dashboardState.programmes[index]),
                  ),
                const SizedBox(height: 100), 
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingEventCard(BuildContext context, Map<String, dynamic> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    String title = data['title'] ?? "Untitled Event";
    String location = data['location'] ?? "ASCON Complex";
    String day = "25"; String month = "OCT"; String time = "TBA"; 
    String type = (data['type'] ?? "Event").toString().toUpperCase();

    String rawDate = data['date']?.toString() ?? '';
    if (rawDate.isNotEmpty) {
      try {
        final dateObj = DateTime.parse(rawDate);
        day = DateFormat("d").format(dateObj); month = DateFormat("MMM").format(dateObj).toUpperCase();
        if (dateObj.hour == 0 && dateObj.minute == 0) { time = "All Day"; } else { time = DateFormat("h:mm a").format(dateObj); }
      } catch (e) { time = "TBA"; }
    }
    if (data['time'] != null && data['time'].toString().isNotEmpty) { time = data['time']; }

    return Container(
      height: 95, 
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
             final String resolvedId = (data['_id'] ?? data['id'] ?? '').toString();
             final safeData = {...data.map((key, value) => MapEntry(key, value.toString())), '_id': resolvedId};
             Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (c) => EventDetailScreen(eventData: safeData)));
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0), 
            child: Row(
              children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.1) : primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.location_on_rounded, color: isDark ? Colors.white : primaryColor, size: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(location.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.grey[500])),
                      const SizedBox(height: 2),
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w900, color: isDark ? Colors.white : primaryColor, height: 1.1)), 
                      const SizedBox(height: 2),
                      Row(children: [Icon(Icons.access_time_rounded, size: 12, color: Colors.blueGrey), const SizedBox(width: 4), Text(time, style: GoogleFonts.lato(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.w700))]),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, 
                  children: [
                    Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(type, style: GoogleFonts.lato(fontSize: 8, fontWeight: FontWeight.w800, color: primaryColor, letterSpacing: 0.5))),
                    Container(
                      width: 48, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2))]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min, 
                          children: [
                            Container(height: 18, width: double.infinity, alignment: Alignment.center, color: primaryColor, child: Text(month, style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0))),
                            Container(height: 26, width: double.infinity, alignment: Alignment.center, color: isDark ? const Color(0xFF2C2C2C) : Colors.white, child: Text(day, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, height: 1.0))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewsUpdateCard(BuildContext context, Map<String, dynamic> data) {
    final String title = data['title'] ?? "Highlights";
    final String? imageUrl = data['image'] ?? data['imageUrl'];
    final String id = data['_id'] ?? data['id'] ?? "";
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final cardColor = Theme.of(context).cardColor; 

    return Container(
      height: 135, width: double.infinity, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: cardColor, boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (c) => ProgrammeDetailScreen(programme: data))),
          child: Stack(
            children: [
              Positioned.fill(child: _buildSafeImage(imageUrl, fallbackIcon: Icons.business, fit: BoxFit.cover)),
              Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [cardColor.withOpacity(1.0), cardColor.withOpacity(0.95), cardColor.withOpacity(0.6), cardColor.withOpacity(0.0)], stops: const [0.0, 0.45, 0.65, 1.0])))),
              Positioned(
                top: 0, bottom: 0, left: 16, width: MediaQuery.of(context).size.width * 0.70,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text("PROGRAMME", style: GoogleFonts.lato(fontSize: 9, fontWeight: FontWeight.w800, color: primaryColor, letterSpacing: 0.5))),
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -0.5)),
                    const SizedBox(height: 10),
                    Row(children: [Text("Read Now", style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFD4AF37))), const SizedBox(width: 4), Icon(Icons.arrow_forward_rounded, size: 14, color: const Color(0xFFD4AF37))])
                  ],
                ),
              ),
              if (_isAdmin) Positioned(top: 8, right: 8, child: CircleAvatar(backgroundColor: Colors.white.withOpacity(0.8), radius: 16, child: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 16), onPressed: () => _deleteProgramme(id), padding: EdgeInsets.zero)))
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) => Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(message, style: GoogleFonts.lato(color: Theme.of(context).textTheme.bodyMedium?.color))));
}