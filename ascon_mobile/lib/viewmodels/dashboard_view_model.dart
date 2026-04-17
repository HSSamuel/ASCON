import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart'; 

class DashboardState {
  final bool isLoading;
  final String? errorMessage;
  final List<dynamic> events;
  final List<dynamic> programmes;
  final List<dynamic> topAlumni;
  final List<dynamic> birthdays; 
  final String profileImage;
  final String programme;
  final String year;
  final String alumniID;
  final String firstName;
  final String fullName;
  final double profileCompletionPercent;
  final bool isProfileComplete;

  const DashboardState({
    this.isLoading = true,
    this.errorMessage,
    this.events = const [],
    this.programmes = const [],
    this.topAlumni = const [],
    this.birthdays = const [], 
    this.profileImage = "",
    this.programme = "Member",
    this.year = "....",
    this.alumniID = "PENDING",
    this.firstName = "Alumni",
    this.fullName = "Alumni",
    this.profileCompletionPercent = 0.0,
    this.isProfileComplete = false,
  });

  DashboardState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<dynamic>? events,
    List<dynamic>? programmes,
    List<dynamic>? topAlumni,
    List<dynamic>? birthdays, 
    String? profileImage,
    String? programme,
    String? year,
    String? alumniID,
    String? firstName,
    String? fullName,
    double? profileCompletionPercent,
    bool? isProfileComplete,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      events: events ?? this.events,
      programmes: programmes ?? this.programmes,
      topAlumni: topAlumni ?? this.topAlumni,
      birthdays: birthdays ?? this.birthdays, 
      profileImage: profileImage ?? this.profileImage,
      programme: programme ?? this.programme,
      year: year ?? this.year,
      alumniID: alumniID ?? this.alumniID,
      firstName: firstName ?? this.firstName,
      fullName: fullName ?? this.fullName,
      profileCompletionPercent: profileCompletionPercent ?? this.profileCompletionPercent,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final DataService _dataService = DataService();
  final AuthService _authService = AuthService();
  
  // ✅ Reference the fast local database
  final Box _cacheBox = Hive.box('ascon_cache');

  DashboardNotifier() : super(const DashboardState()) {
    loadData();
  }

  // =========================================================================
  // ✅ OFFLINE-FIRST DASHBOARD LOADING
  // =========================================================================
  Future<void> loadData({bool isRefresh = false}) async {
    const String cacheKey = 'dashboard_data_cache';
    
    final prefs = await SharedPreferences.getInstance();
    String localAlumniID = prefs.getString('alumni_id') ?? "PENDING";
    String cachedName = prefs.getString('user_name') ?? state.fullName;

    // 1. MILLISECOND 0: Check Local Cache First (Instant Load)
    if (!isRefresh) {
      final String? cachedDataStr = _cacheBox.get(cacheKey);
      if (cachedDataStr != null) {
        try {
          final Map<String, dynamic> cachedData = jsonDecode(cachedDataStr);
          if (mounted) {
            state = state.copyWith(
              isLoading: false,
              errorMessage: null,
              fullName: cachedName,
              firstName: cachedName.split(" ")[0],
              alumniID: localAlumniID,
              events: cachedData['events'] ?? [],
              programmes: cachedData['programmes'] ?? [],
              topAlumni: cachedData['topAlumni'] ?? [],
              birthdays: cachedData['birthdays'] ?? [],
              profileImage: cachedData['profileImage'] ?? "",
              programme: cachedData['programme'] ?? "Member",
              year: cachedData['year'] ?? "....",
              profileCompletionPercent: (cachedData['profileCompletionPercent'] ?? 0.0).toDouble(),
              isProfileComplete: cachedData['isProfileComplete'] ?? false,
            );
            debugPrint("⚡ Loaded Dashboard instantly from cache.");
          }
        } catch (e) {
          debugPrint("Dashboard Cache read error: $e");
        }
      } else {
        state = state.copyWith(isLoading: true, errorMessage: null, fullName: cachedName, alumniID: localAlumniID);
      }
    } else {
      state = state.copyWith(fullName: cachedName, errorMessage: null);
    }

    // 2. CHECK CONNECTIVITY (Fail Fast)
    final connectivityResult = await (Connectivity().checkConnectivity());
    bool isOffline = connectivityResult.contains(ConnectivityResult.none);
    
    if (isOffline) {
      debugPrint("🚫 Offline. Relying entirely on dashboard cache.");
      if (mounted && state.isLoading) state = state.copyWith(isLoading: false);
      return; 
    }

    // 3. BACKGROUND NETWORK FETCH
    try {
      final String? myId = await _authService.currentUserId;

      final results = await Future.wait([
        _dataService.fetchEvents(),                  
        _authService.getProgrammes(),                
        _dataService.fetchProfile(),                 
        _dataService.fetchDirectory(query: ""),
        _dataService.fetchCelebrants(),      
      ]);

      // 1. Process Events
      var fetchedEvents = List.from(results[0] as List);
      fetchedEvents.sort((a, b) {
        final idA = a['_id'] ?? a['id'] ?? '';
        final idB = b['_id'] ?? b['id'] ?? '';
        return idB.toString().compareTo(idA.toString());
      });

      // 2. Process Programmes
      var fetchedProgrammes = List.from(results[1] as List);
      fetchedProgrammes.sort((a, b) {
        final idA = a['_id'] ?? a['id'] ?? '';
        final idB = b['_id'] ?? b['id'] ?? '';
        return idB.toString().compareTo(idA.toString());
      });

      // 3. Process Profile
      String profileImage = "";
      String programme = "Member";
      String year = "....";
      
      String fullName = cachedName; 
      String firstName = fullName.split(" ")[0]; 
      
      String alumniID = localAlumniID;
      double profileCompletionPercent = 0.0;
      bool isProfileComplete = false;

      final profile = results[2] as Map<String, dynamic>?;
      if (profile != null) {
        profileImage = profile['profilePicture'] ?? "";
        programme = profile['programmeTitle'] ?? "Member";
        if (programme.isEmpty) programme = "Member";
        year = profile['yearOfAttendance']?.toString() ?? "....";
        
        if (profile['fullName'] != null && profile['fullName'].toString().trim().isNotEmpty) {
          fullName = profile['fullName'];
          firstName = fullName.split(" ")[0];
          prefs.setString('user_name', fullName); 
        }

        String? apiId = profile['alumniId'];
        if (apiId != null && apiId.isNotEmpty && apiId != "PENDING") {
          alumniID = apiId;
          await prefs.setString('alumni_id', apiId);
        }

        if (profile.containsKey('profileCompletionPercent')) {
          profileCompletionPercent = (profile['profileCompletionPercent'] as num).toDouble();
          isProfileComplete = profile['isProfileComplete'] ?? false;
        }
      }

      // 4. Process Directory (Top Alumni)
      var fetchedAlumni = List.from(results[3] as List);
      if (myId != null) {
        fetchedAlumni.removeWhere((user) {
          final id = user['_id'] ?? user['userId'];
          return id.toString() == myId;
        });
      }
      
      fetchedAlumni.shuffle(); 
      final topAlumni = fetchedAlumni.take(20).toList(); 

      // 5. Process Birthdays
      List<dynamic> fetchedBirthdays = [];
      final celebrationResult = results[4];
      if (celebrationResult is Map) {
        fetchedBirthdays = celebrationResult['birthdays'] ?? [];
      } else if (celebrationResult is List) {
        fetchedBirthdays = celebrationResult;
      }

      // 4. OVERWRITE CACHE WITH FRESH DATA
      await _cacheBox.put(cacheKey, jsonEncode({
        'events': fetchedEvents,
        'programmes': fetchedProgrammes,
        'topAlumni': topAlumni,
        'birthdays': fetchedBirthdays,
        'profileImage': profileImage,
        'programme': programme,
        'year': year,
        'profileCompletionPercent': profileCompletionPercent,
        'isProfileComplete': isProfileComplete,
      }));

      // 5. SILENTLY UPDATE UI
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: null, 
          events: fetchedEvents,
          programmes: fetchedProgrammes,
          topAlumni: topAlumni,
          birthdays: fetchedBirthdays, 
          profileImage: profileImage,
          programme: programme,
          year: year,
          alumniID: alumniID,
          firstName: firstName,
          fullName: fullName,
          profileCompletionPercent: profileCompletionPercent,
          isProfileComplete: isProfileComplete,
        );
      }

    } catch (e) {
      debugPrint("⚠️ Error loading dashboard data: $e");
      
      String readableError = "Something went wrong. Please try again.";
      
      if (e is ApiException) {
        if (e.statusCode == 0) {
          readableError = "No internet connection. Please check your network.";
        } else if (e.statusCode == 500) {
          readableError = "Server error. We're working on it.";
        } else {
          readableError = e.message;
        }
      } else if (e.toString().contains("SocketException")) {
        readableError = "Network error. Please check your connection.";
      }

      if (mounted && state.events.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: readableError,
        );
      } else if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }
}

final dashboardProvider = StateNotifierProvider.autoDispose<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier();
});