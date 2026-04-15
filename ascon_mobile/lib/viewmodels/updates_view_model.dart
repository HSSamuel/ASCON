import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import '../services/api_client.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';

class UpdatesState {
  final List<dynamic> posts;
  final List<dynamic> filteredPosts;
  final List<dynamic> highlights;
  final bool isLoading;
  final bool isPosting;
  final bool isAdmin;
  final String? currentUserId;
  final String? errorMessage;
  final bool showMediaOnly;

  const UpdatesState({
    this.posts = const [],
    this.filteredPosts = const [],
    this.highlights = const [],
    this.isLoading = true,
    this.isPosting = false,
    this.isAdmin = false,
    this.currentUserId,
    this.errorMessage,
    this.showMediaOnly = false,
  });

  UpdatesState copyWith({
    List<dynamic>? posts,
    List<dynamic>? filteredPosts,
    List<dynamic>? highlights,
    bool? isLoading,
    bool? isPosting,
    bool? isAdmin,
    String? currentUserId,
    String? errorMessage,
    bool? showMediaOnly,
  }) {
    return UpdatesState(
      posts: posts ?? this.posts,
      filteredPosts: filteredPosts ?? this.filteredPosts,
      highlights: highlights ?? this.highlights,
      isLoading: isLoading ?? this.isLoading,
      isPosting: isPosting ?? this.isPosting,
      isAdmin: isAdmin ?? this.isAdmin,
      currentUserId: currentUserId ?? this.currentUserId,
      errorMessage: errorMessage,
      showMediaOnly: showMediaOnly ?? this.showMediaOnly,
    );
  }
}

class UpdatesNotifier extends StateNotifier<UpdatesState> {
  final DataService _dataService = DataService();
  final AuthService _authService = AuthService();
  final ApiClient _api = ApiClient();

  UpdatesNotifier() : super(const UpdatesState()) {
    init();
  }

  Future<void> init() async {
    await _checkPermissions();
    await loadData();
  }

  Future<void> _checkPermissions() async {
    final adminStatus = await _authService.isAdmin;
    final userId = await _authService.currentUserId;
    state = state.copyWith(isAdmin: adminStatus, currentUserId: userId);
  }

  Future<void> loadData({bool silent = false}) async {
    if (!silent) state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final feed = await _dataService.fetchUpdates();
      final programmes = await _authService.getProgrammes();

      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          posts: feed,
          filteredPosts: feed,
          highlights: programmes,
        );
      }
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, errorMessage: "Failed to load updates.");
    }
  }

  void searchPosts(String query) {
    if (query.isEmpty) {
      state = state.copyWith(filteredPosts: state.posts);
    } else {
      final filtered = state.posts.where((post) {
        final text = (post['text'] ?? "").toString().toLowerCase();
        final author = (post['author']['fullName'] ?? "").toString().toLowerCase();
        return text.contains(query.toLowerCase()) || author.contains(query.toLowerCase());
      }).toList();
      state = state.copyWith(filteredPosts: filtered);
    }
  }

  void toggleMediaFilter() {
    final newValue = !state.showMediaOnly;
    List<dynamic> newFiltered;
    
    if (newValue) {
      newFiltered = state.posts.where((p) => p['mediaType'] == 'image').toList();
    } else {
      newFiltered = state.posts;
    }
    
    state = state.copyWith(showMediaOnly: newValue, filteredPosts: newFiltered);
  }

  Future<bool> editPost(String postId, String newText) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.put('/api/updates/$postId', {'text': newText});
      if (res['success'] == true) {
        await loadData(silent: true);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: "Failed to edit post.");
      return false;
    }
  }

  Future<List<dynamic>> fetchComments(String postId) async {
    try {
      final res = await _api.get('/api/updates/$postId');
      
      if (res['success'] == true) {
        dynamic postData = res['data'];

        if (postData is Map && postData.containsKey('data')) {
          postData = postData['data'];
        }

        if (postData is Map && postData['comments'] != null) {
          return List.from(postData['comments']);
        }
      }
    } catch (e) {
      debugPrint("Fetch Comments Error: $e");
    }
    return [];
  }

  Future<List<dynamic>> fetchLikers(String postId) async {
    try {
      final res = await _api.get('/api/updates/$postId/likes');
      
      if (res['success'] == true) {
        if (res['data'] is List) {
          return List.from(res['data']);
        } 
        
        if (res['data'] is Map && res['data']['data'] is List) {
          return List.from(res['data']['data']);
        }
      }
    } catch (e) {
      debugPrint("Fetch Likers Error: $e");
    }
    return [];
  }

  Future<bool> postComment(String postId, String text) async {
    try {
      final res = await _api.post('/api/updates/$postId/comment', {'text': text});
      if (res['success'] == true) {
        await loadData(silent: true);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> toggleLike(String postId) async {
    final index = state.filteredPosts.indexWhere((p) => p['_id'] == postId);
    if (index == -1) return;

    final updatedPosts = List<dynamic>.from(state.filteredPosts);
    final post = Map<String, dynamic>.from(updatedPosts[index]);
    
    bool isLiked = post['isLikedByMe'] == true;
    post['isLikedByMe'] = !isLiked;
    
    List likes = List.from(post['likes'] ?? []);
    if (!isLiked) {
      likes.add('dummy_id');
    } else if (likes.isNotEmpty) {
      likes.removeLast();
    }
    post['likes'] = likes;
    updatedPosts[index] = post;

    state = state.copyWith(filteredPosts: updatedPosts);

    try {
      await _api.put('/api/updates/$postId/like', {});
    } catch (e) {
      // Revert if needed
    }
  }

  // ✅ UPDATED: Accept List of Images
  Future<String?> createPost(String text, List<XFile>? images) async {
    state = state.copyWith(isPosting: true);
    try {
      final token = await _authService.getToken();
      var request = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/api/updates'));
      request.headers['auth-token'] = token ?? '';
      request.fields['text'] = text;

      // ✅ Map through multiple images
      if (images != null && images.isNotEmpty) {
        for (var img in images) {
          if (kIsWeb) {
            var bytes = await img.readAsBytes();
            request.files.add(http.MultipartFile.fromBytes('media', bytes, filename: img.name));
          } else {
            request.files.add(await http.MultipartFile.fromPath('media', img.path));
          }
        }
      }

      var response = await request.send();
      state = state.copyWith(isPosting: false);

      if (response.statusCode == 201) {
        await loadData(silent: true);
        return null; // Success
      } else {
        return "Failed to post update.";
      }
    } catch (e) {
      state = state.copyWith(isPosting: false);
      return "Connection error.";
    }
  }

  Future<bool> deletePost(String postId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _api.delete('/api/updates/$postId');
      await loadData(silent: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }
}

final updatesProvider = StateNotifierProvider.autoDispose<UpdatesNotifier, UpdatesState>((ref) {
  return UpdatesNotifier();
});