import 'dart:async';
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
  final Box _cacheBox = Hive.box('ascon_cache');

  DashboardNotifier() : super(const DashboardState()) {
    loadData();
  }

  Future<void> loadData({bool isRefresh = false}) async {
    const String cacheKey = 'dashboard_data_cache';
    
    final prefs = await SharedPreferences.getInstance();
    String localAlumniID = prefs.getString('alumni_id') ?? "PENDING";
    String cachedName = prefs.getString('user_name') ?? state.fullName;

    // Safely fetch cache (prevents keystore crash)
    Map<String, dynamic>? userMap;
    try {
      userMap = await _authService.getCachedUser();
    } catch (_) {}

    String localProgramme = userMap?['programmeTitle']?.toString() ?? "Member";
    if (localProgramme.trim().isEmpty) localProgramme = "Member";

    // 1. Check Local Cache First
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
              programme: cachedData['programme'] ?? localProgramme, 
              year: cachedData['year'] ?? "....",
              profileCompletionPercent: (cachedData['profileCompletionPercent'] ?? 0.0).toDouble(),
              isProfileComplete: cachedData['isProfileComplete'] ?? false,
            );
          }
        } catch (e) {
          debugPrint("Dashboard Cache read error: $e");
        }
      } else {
        state = state.copyWith(
          isLoading: true, 
          errorMessage: null, 
          fullName: cachedName, 
          alumniID: localAlumniID, 
          programme: localProgramme
        );
      }
    } else {
      state = state.copyWith(fullName: cachedName, errorMessage: null);
    }

    // 2. CHECK CONNECTIVITY 
    final connectivityResult = await (Connectivity().checkConnectivity());
    bool isOffline = connectivityResult.contains(ConnectivityResult.none);
    
    if (isOffline) {
      if (mounted && state.isLoading) state = state.copyWith(isLoading: false);
      return; 
    }

    // 3. BACKGROUND NETWORK FETCH
    try {
      final String? myId = await _authService.currentUserId;

      final results = await Future.wait([
        _dataService.fetchEvents().catchError((e) => <dynamic>[]),
        _authService.getProgrammes().catchError((e) => <dynamic>[]),
        _dataService.fetchProfile().catchError((e) => null),
        _dataService.fetchDirectory(query: "").catchError((e) => <dynamic>[]),
        _dataService.fetchCelebrants().catchError((e) => []),
      ]).timeout(const Duration(seconds: 25));

      // 🚨 FIX: Safe Data Casting without `as`
      var fetchedEvents = results[0] is List ? List.from(results[0]) : <dynamic>[];
      fetchedEvents.sort((a, b) {
        final idA = (a is Map) ? (a['_id'] ?? a['id'] ?? '').toString() : '';
        final idB = (b is Map) ? (b['_id'] ?? b['id'] ?? '').toString() : '';
        return idB.compareTo(idA);
      });

      var fetchedProgrammes = results[1] is List ? List.from(results[1]) : <dynamic>[];
      fetchedProgrammes.sort((a, b) {
        final idA = (a is Map) ? (a['_id'] ?? a['id'] ?? '').toString() : '';
        final idB = (b is Map) ? (b['_id'] ?? b['id'] ?? '').toString() : '';
        return idB.compareTo(idA);
      });

      String profileImage = state.profileImage;
      String programme = state.programme;
      String year = state.year;
      String fullName = cachedName; 
      String firstName = fullName.split(" ").isNotEmpty ? fullName.split(" ")[0] : "Alumni"; 
      String alumniID = localAlumniID;
      double profileCompletionPercent = state.profileCompletionPercent;
      bool isProfileComplete = state.isProfileComplete;

      // 🚨 FIX: Safe Map Casting
      final profile = results[2] is Map ? results[2] as Map<dynamic, dynamic> : null;
      
      if (profile != null) {
        profileImage = profile['profilePicture']?.toString() ?? state.profileImage;
        String incomingProgramme = profile['programmeTitle']?.toString() ?? "";
        programme = incomingProgramme.isNotEmpty ? incomingProgramme : state.programme;
        year = profile['yearOfAttendance']?.toString() ?? state.year;
        
        if (profile['fullName'] != null && profile['fullName'].toString().trim().isNotEmpty) {
          fullName = profile['fullName'].toString();
          firstName = fullName.split(" ")[0];
          prefs.setString('user_name', fullName); 
        }

        String? apiId = profile['alumniId']?.toString();
        if (apiId != null && apiId.isNotEmpty && apiId != "PENDING") {
          alumniID = apiId;
          await prefs.setString('alumni_id', apiId);
        }

        // 🚨 FIX: Safe Number/String Parsing
        var rawPercent = profile['profileCompletionPercent'];
        if (rawPercent != null) {
          if (rawPercent is num) {
            profileCompletionPercent = rawPercent.toDouble();
          } else if (rawPercent is String) {
            profileCompletionPercent = double.tryParse(rawPercent) ?? 0.0;
          }
        }
        
        var rawIsComplete = profile['isProfileComplete'];
        if (rawIsComplete is bool) {
          isProfileComplete = rawIsComplete;
        } else if (rawIsComplete is String) {
          isProfileComplete = rawIsComplete.toLowerCase() == 'true';
        }
      }

      var fetchedAlumni = results[3] is List ? List.from(results[3]) : <dynamic>[];
      if (myId != null) {
        fetchedAlumni.removeWhere((user) {
          if (user is! Map) return false;
          final id = user['_id'] ?? user['userId'];
          return id.toString() == myId;
        });
      }
      
      if (state.topAlumni.isEmpty || isRefresh) {
        fetchedAlumni.shuffle();
      }
      final topAlumni = fetchedAlumni.take(20).toList(); 

      List<dynamic> fetchedBirthdays = [];
      final celebrationResult = results[4];
      if (celebrationResult is Map) {
        fetchedBirthdays = celebrationResult['birthdays'] ?? [];
      } else if (celebrationResult is List) {
        fetchedBirthdays = celebrationResult;
      }

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
      
      // ✅ Friendly fallback message instead of "Something went wrong"
      String readableError = "Unable to sync data. Please pull down to refresh.";
      
      if (e is TimeoutException) {
        readableError = "Network timeout. Your connection might be slow.";
      } else if (e.toString().contains("SocketException") || e.toString().contains("ClientException")) {
        readableError = "Network error. Please check your connection.";
      }

      if (mounted && state.events.isEmpty) {
        state = state.copyWith(isLoading: false, errorMessage: readableError);
      } else if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }
}

final dashboardProvider = StateNotifierProvider.autoDispose<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier();
});