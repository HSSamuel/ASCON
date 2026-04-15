import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter_riverpod/legacy.dart'; // REMOVED
import '../services/api_client.dart';
import '../services/data_service.dart';
import '../services/socket_service.dart';

class DirectoryState {
  final List<dynamic> allAlumni;
  final List<dynamic> searchResults;
  final Map<String, List<dynamic>> groupedAlumni;
  final List<dynamic> recommendedAlumni;
  final List<dynamic> smartMatches;
  final List<dynamic> nearbyAlumni;
  
  final bool isLoadingDirectory;
  final bool isLoadingMatches;
  final bool isLoadingNearMe;
  final bool hasRecommendations;
  final bool shouldShowPopup;
  
  final String activeFilter; 
  final String nearMeFilter;

  const DirectoryState({
    this.allAlumni = const [],
    this.searchResults = const [],
    this.groupedAlumni = const {},
    this.recommendedAlumni = const [],
    this.smartMatches = const [],
    this.nearbyAlumni = const [],
    this.isLoadingDirectory = false,
    this.isLoadingMatches = false,
    this.isLoadingNearMe = false,
    this.hasRecommendations = false,
    this.shouldShowPopup = false,
    this.activeFilter = "All",
    this.nearMeFilter = "",
  });

  DirectoryState copyWith({
    List<dynamic>? allAlumni,
    List<dynamic>? searchResults,
    Map<String, List<dynamic>>? groupedAlumni,
    List<dynamic>? recommendedAlumni,
    List<dynamic>? smartMatches,
    List<dynamic>? nearbyAlumni,
    bool? isLoadingDirectory,
    bool? isLoadingMatches,
    bool? isLoadingNearMe,
    bool? hasRecommendations,
    bool? shouldShowPopup,
    String? activeFilter,
    String? nearMeFilter,
  }) {
    return DirectoryState(
      allAlumni: allAlumni ?? this.allAlumni,
      searchResults: searchResults ?? this.searchResults,
      groupedAlumni: groupedAlumni ?? this.groupedAlumni,
      recommendedAlumni: recommendedAlumni ?? this.recommendedAlumni,
      smartMatches: smartMatches ?? this.smartMatches,
      nearbyAlumni: nearbyAlumni ?? this.nearbyAlumni,
      isLoadingDirectory: isLoadingDirectory ?? this.isLoadingDirectory,
      isLoadingMatches: isLoadingMatches ?? this.isLoadingMatches,
      isLoadingNearMe: isLoadingNearMe ?? this.isLoadingNearMe,
      hasRecommendations: hasRecommendations ?? this.hasRecommendations,
      shouldShowPopup: shouldShowPopup ?? this.shouldShowPopup,
      activeFilter: activeFilter ?? this.activeFilter,
      nearMeFilter: nearMeFilter ?? this.nearMeFilter,
    );
  }
}

class DirectoryNotifier extends StateNotifier<DirectoryState> {
  final ApiClient _api = ApiClient();
  final DataService _dataService = DataService();
  StreamSubscription? _statusSubscription;

  DirectoryNotifier() : super(const DirectoryState()) {
    init();
  }

  void init() {
    loadDirectory();
    loadRecommendations();
    loadSmartMatches();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  void setFilter(String filter) {
    state = state.copyWith(activeFilter: filter);
    
    if (filter == "Near Me") {
      loadNearMe();
    } else {
      loadDirectory(); 
    }
  }

  Future<void> loadDirectory({String query = ""}) async {
    state = state.copyWith(isLoadingDirectory: true);

    try {
      String endpoint = '/api/directory?search=$query';
      
      if (state.activeFilter == "Mentors") endpoint += '&mentorship=true';
      if (state.activeFilter == "Classmates") endpoint += '&classmates=true';

      final response = await _api.get(endpoint);

      if (response['success'] == true) {
        final dynamic rawData = response['data'];
        List<dynamic> list = [];

        if (rawData is List) {
          list = rawData;
        } else if (rawData is Map && rawData['data'] is List) {
          list = rawData['data'];
        }

        if (mounted) {
          state = state.copyWith(
            allAlumni: list,
            searchResults: list,
            groupedAlumni: _groupUsersByYear(list),
            isLoadingDirectory: false,
          );
        }
      }
    } catch (e) {
      debugPrint("Directory Load Error: $e");
      if (mounted) state = state.copyWith(isLoadingDirectory: false);
    }
  }

  void onSearchChanged(String query) {
    if (state.activeFilter == "Near Me") {
       return; 
    }

    if (query.isEmpty) {
      state = state.copyWith(
        searchResults: state.allAlumni,
        groupedAlumni: _groupUsersByYear(state.allAlumni)
      );
    } else {
      final lowerQuery = query.toLowerCase();
      final filtered = state.allAlumni.where((user) {
        final name = (user['fullName'] ?? '').toString().toLowerCase();
        final org = (user['organization'] ?? '').toString().toLowerCase();
        final year = (user['yearOfAttendance'] ?? '').toString().toLowerCase();
        final job = (user['jobTitle'] ?? '').toString().toLowerCase();
        return name.contains(lowerQuery) || org.contains(lowerQuery) || year.contains(lowerQuery) || job.contains(lowerQuery);
      }).toList();
      
      state = state.copyWith(
        searchResults: filtered,
        groupedAlumni: _groupUsersByYear(filtered)
      );
    }
  }

  Future<void> loadRecommendations() async {
    try {
      final result = await _dataService.fetchRecommendations();
      if (result['success'] == true) {
        final recs = result['matches'] ?? [];
        bool shouldPopup = false;
        
        if (recs.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          final lastShown = prefs.getInt('last_recommendation_popup_time') ?? 0;
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastShown > 86400000) {
            shouldPopup = true;
            prefs.setInt('last_recommendation_popup_time', now);
          }
        }
        
        if (mounted) {
          state = state.copyWith(
            recommendedAlumni: recs, 
            hasRecommendations: recs.isNotEmpty,
            shouldShowPopup: shouldPopup
          );
        }
      }
    } catch (_) {}
  }

  Future<void> loadSmartMatches() async {
    state = state.copyWith(isLoadingMatches: true);
    try {
      final matches = await _dataService.fetchSmartMatches();
      if (mounted) state = state.copyWith(smartMatches: matches, isLoadingMatches: false);
    } catch (_) {
      if (mounted) state = state.copyWith(isLoadingMatches: false);
    }
  }

  Future<void> loadNearMe({String? city}) async {
    state = state.copyWith(isLoadingNearMe: true);
    try {
      final nearby = await _dataService.fetchAlumniNearMe(city: city);
      if (mounted) state = state.copyWith(nearbyAlumni: nearby, isLoadingNearMe: false);
    } catch (_) {
      if (mounted) state = state.copyWith(isLoadingNearMe: false);
    }
  }

  void setNearMeFilter(String val) {
    state = state.copyWith(nearMeFilter: val);
  }

  Map<String, List<dynamic>> _groupUsersByYear(List<dynamic> users) {
    Map<String, List<dynamic>> groups = {};
    for (var user in users) {
      String year = user['yearOfAttendance']?.toString() ?? 'Others';
      if (!groups.containsKey(year)) groups[year] = [];
      groups[year]!.add(user);
    }
    
    var sortedKeys = groups.keys.toList()..sort((a, b) {
      if (a == 'Others') return 1;
      if (b == 'Others') return -1;
      return b.compareTo(a);
    });
    return {for (var key in sortedKeys) key: groups[key]!};
  }

  void _listenToSocket() {
    _statusSubscription = SocketService().userStatusStream.listen((data) {
    });
  }
}

final directoryProvider = StateNotifierProvider.autoDispose<DirectoryNotifier, DirectoryState>((ref) {
  return DirectoryNotifier();
});