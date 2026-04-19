import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';

class ProfileState {
  final Map<String, dynamic>? userProfile;
  final bool isLoading;
  final bool isOnline;
  final String? lastSeen;
  final double completionPercent;

  const ProfileState({
    this.userProfile,
    this.isLoading = false, // ✅ FIX: Start false so cache paints instantly without a spinner frame
    this.isOnline = false,
    this.lastSeen,
    this.completionPercent = 0.0,
  });

  ProfileState copyWith({
    Map<String, dynamic>? userProfile,
    bool? isLoading,
    bool? isOnline,
    String? lastSeen,
    double? completionPercent,
  }) {
    return ProfileState(
      userProfile: userProfile ?? this.userProfile,
      isLoading: isLoading ?? this.isLoading,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      completionPercent: completionPercent ?? this.completionPercent,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final DataService _dataService = DataService();
  final AuthService _authService = AuthService();
  final Box _cacheBox = Hive.box('ascon_cache');

  ProfileNotifier() : super(const ProfileState()) {
    loadProfile();
  }

  Future<void> loadProfile({bool isRefresh = false, bool showSkeleton = false}) async {
    const String cacheKey = 'user_profile_cache';

    if (showSkeleton && mounted) {
      state = state.copyWith(isLoading: true);
    }

    // 1. MILLISECOND 0: Check Local Cache First 
    if (!isRefresh && !showSkeleton) {
      final String? cachedProfileStr = _cacheBox.get(cacheKey);
      if (cachedProfileStr != null) {
        try {
          final Map<String, dynamic> cachedProfile = jsonDecode(cachedProfileStr);
          if (mounted) {
            state = state.copyWith(
              userProfile: cachedProfile,
              isLoading: false,
              isOnline: cachedProfile['isOnline'] == true,
              lastSeen: cachedProfile['lastSeen']?.toString(),
              completionPercent: _calculateCompletion(cachedProfile),
            );
          }
        } catch (e) {
          debugPrint("Profile Cache read error: $e");
        }
      } else {
        if (mounted) state = state.copyWith(isLoading: true);
      }
    }

    // 2. BACKGROUND NETWORK FETCH 
    try {
      final profile = await _dataService.fetchProfile();
      
      if (profile != null) {
        final isOnline = profile['isOnline'] == true;
        final lastSeen = profile['lastSeen']?.toString();
        final percent = _calculateCompletion(profile);

        // 3. OVERWRITE CACHE WITH FRESH DATA
        await _cacheBox.put(cacheKey, jsonEncode(profile));

        // 4. SILENTLY UPDATE UI
        if (mounted) {
          state = state.copyWith(
            userProfile: profile,
            isLoading: false,
            isOnline: isOnline,
            lastSeen: lastSeen,
            completionPercent: percent
          );
        }
        
        if (profile['_id'] != null) {
          _listenToSocket(profile['_id']);
        }
      } else {
        if (mounted) state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      debugPrint("Network fetch failed, relying on cache: $e");
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }

  void _listenToSocket(String? userId) {
    if (userId == null) return;
    SocketService().userStatusStream.listen((data) {
      if (data['userId'] == userId && mounted) {
        state = state.copyWith(
          isOnline: data['isOnline'],
          lastSeen: data['isOnline'] ? null : data['lastSeen']?.toString()
        );
      }
    });
  }

  double _calculateCompletion(Map<String, dynamic> data) {
    int total = 6; 
    int filled = 0;
    if (data['fullName'] != null && data['fullName'].toString().isNotEmpty) filled++;
    if (data['profilePicture'] != null && data['profilePicture'].toString().isNotEmpty) filled++;
    if (data['jobTitle'] != null && data['jobTitle'].toString().isNotEmpty) filled++;
    if (data['bio'] != null && data['bio'].toString().isNotEmpty) filled++;
    if (data['city'] != null && data['city'].toString().isNotEmpty) filled++;
    if (data['phoneNumber'] != null && data['phoneNumber'].toString().isNotEmpty) filled++;
    return filled / total;
  }

  Future<void> logout() async {
    SocketService().logoutUser();
    await _authService.logout();
  }
}

final profileProvider = StateNotifierProvider.autoDispose<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier();
});