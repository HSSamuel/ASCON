import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../services/data_service.dart';
import '../services/auth_service.dart';

class DashboardState {
  final bool isLoading;
  final String? errorMessage;
  final List<dynamic> events;
  final List<dynamic> programmes;
  final List<dynamic> topAlumni;
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
    
    if (!mounted) return;

    String localAlumniID = prefs.getString('alumni_id') ?? "PENDING";
    String cachedName = prefs.getString('user_name') ?? state.fullName;

    Map<String, dynamic>? userMap;
    try {
      userMap = await _authService.getCachedUser();
    } catch (_) {}
    if (!mounted) return;

    String localProgramme = userMap?['programmeTitle']?.toString() ?? "Member";
    if (localProgramme.trim().isEmpty) localProgramme = "Member";

    if (!isRefresh) {
      final String? cachedDataStr = _cacheBox.get(cacheKey);
      if (cachedDataStr != null) {
        try {
          final Map<String, dynamic> cachedData = jsonDecode(cachedDataStr);
          state = state.copyWith(
            isLoading: false,
            errorMessage: null,
            fullName: cachedName,
            firstName: cachedName.split(" ")[0],
            alumniID: localAlumniID,
            events: cachedData['events'] ?? [],
            programmes: cachedData['programmes'] ?? [],
            topAlumni: cachedData['topAlumni'] ?? [],
            profileImage: cachedData['profileImage'] ?? "",
            programme: cachedData['programme'] ?? localProgramme, 
            year: cachedData['year'] ?? "....",
            profileCompletionPercent: (cachedData['profileCompletionPercent'] ?? 0.0).toDouble(),
            isProfileComplete: cachedData['isProfileComplete'] ?? false,
          );
        } catch (e) {
          debugPrint("Dashboard Cache read error: $e");
        }
      } else {
        state = state.copyWith(isLoading: true, errorMessage: null, fullName: cachedName, alumniID: localAlumniID, programme: localProgramme);
      }
    } else {
      state = state.copyWith(fullName: cachedName, errorMessage: null);
    }

    final connectivityResult = await (Connectivity().checkConnectivity());
    if (!mounted) return;
    
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (state.isLoading) state = state.copyWith(isLoading: false);
      return; 
    }

    try {
      final String? myId = await _authService.currentUserId;
      if (!mounted) return;

      final results = await Future.wait([
        _dataService.fetchEvents().catchError((e) => <dynamic>[]),
        _authService.getProgrammes().catchError((e) => <dynamic>[]),
        _dataService.fetchProfile().catchError((e) => null),
        _dataService.fetchDirectory(query: "").catchError((e) => <dynamic>[]),
      ]).timeout(const Duration(seconds: 25));
      
      if (!mounted) return;

      // ✅ FIX: Explicitly cast to Iterable before using List.from
      var fetchedEvents = results[0] is Iterable ? List.from(results[0] as Iterable) : <dynamic>[];
      fetchedEvents.sort((a, b) {
        final idA = (a is Map) ? (a['_id'] ?? a['id'] ?? '').toString() : '';
        final idB = (b is Map) ? (b['_id'] ?? b['id'] ?? '').toString() : '';
        return idB.compareTo(idA);
      });

      // ✅ FIX: Explicitly cast to Iterable
      var fetchedProgrammes = results[1] is Iterable ? List.from(results[1] as Iterable) : <dynamic>[];
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

        var rawPercent = profile['profileCompletionPercent'];
        if (rawPercent != null) {
          if (rawPercent is num) profileCompletionPercent = rawPercent.toDouble();
          else if (rawPercent is String) profileCompletionPercent = double.tryParse(rawPercent) ?? 0.0;
        }
        
        var rawIsComplete = profile['isProfileComplete'];
        if (rawIsComplete is bool) isProfileComplete = rawIsComplete;
        else if (rawIsComplete is String) isProfileComplete = rawIsComplete.toLowerCase() == 'true';
      }

      // ✅ FIX: Explicitly cast to Iterable
      var fetchedAlumni = results[3] is Iterable ? List.from(results[3] as Iterable) : <dynamic>[];
      if (myId != null) {
        fetchedAlumni.removeWhere((user) {
          if (user is! Map) return false;
          return (user['_id'] ?? user['userId']).toString() == myId;
        });
      }
      
      if (state.topAlumni.isEmpty || isRefresh) fetchedAlumni.shuffle();
      final topAlumni = fetchedAlumni.take(20).toList(); 

      await _cacheBox.put(cacheKey, jsonEncode({
        'events': fetchedEvents,
        'programmes': fetchedProgrammes,
        'topAlumni': topAlumni,
        'profileImage': profileImage,
        'programme': programme,
        'year': year,
        'profileCompletionPercent': profileCompletionPercent,
        'isProfileComplete': isProfileComplete,
      }));
      
      if (!mounted) return;

      state = state.copyWith(
        isLoading: false,
        errorMessage: null, 
        events: fetchedEvents,
        programmes: fetchedProgrammes,
        topAlumni: topAlumni,
        profileImage: profileImage,
        programme: programme,
        year: year,
        alumniID: alumniID,
        firstName: firstName,
        fullName: fullName,
        profileCompletionPercent: profileCompletionPercent,
        isProfileComplete: isProfileComplete,
      );

    } catch (e) {
      debugPrint("⚠️ Error loading dashboard data: $e");
      if (!mounted) return;
      String readableError = "Unable to sync data. Please pull down to refresh.";
      if (e is TimeoutException) readableError = "Network timeout.";
      
      if (state.events.isEmpty) {
        state = state.copyWith(isLoading: false, errorMessage: readableError);
      } else {
        state = state.copyWith(isLoading: false);
      }
    }
  }
}

final dashboardProvider = StateNotifierProvider.autoDispose<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier();
});