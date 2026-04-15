import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_riverpod/legacy.dart'; // REMOVED
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
    this.isLoading = true,
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

  ProfileNotifier() : super(const ProfileState()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true);
    try {
      final profile = await _dataService.fetchProfile();
      
      final isOnline = profile?['isOnline'] == true;
      final lastSeen = profile?['lastSeen'];
      final percent = _calculateCompletion(profile ?? {});

      if (mounted) {
        state = state.copyWith(
          userProfile: profile,
          isLoading: false,
          isOnline: isOnline,
          lastSeen: lastSeen,
          completionPercent: percent
        );
      }
      
      if (profile?['_id'] != null) {
        _listenToSocket(profile!['_id']);
      }
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }

  void _listenToSocket(String? userId) {
    if (userId == null) return;
    SocketService().userStatusStream.listen((data) {
      if (data['userId'] == userId && mounted) {
        state = state.copyWith(
          isOnline: data['isOnline'],
          lastSeen: data['isOnline'] ? null : data['lastSeen']
        );
      }
    });
  }

  double _calculateCompletion(Map<String, dynamic> data) {
    int total = 6; 
    int filled = 0;
    if (data['fullName'] != null) filled++;
    if (data['profilePicture'] != null) filled++;
    if (data['jobTitle'] != null) filled++;
    if (data['bio'] != null) filled++;
    if (data['city'] != null) filled++;
    if (data['phoneNumber'] != null) filled++;
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