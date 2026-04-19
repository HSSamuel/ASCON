import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
    this.isLoading = false, 
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
  
  // ✅ Reference the fast local database
  final Box _cacheBox = Hive.box('ascon_cache');

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

  // =========================================================================
  // ✅ OFFLINE-FIRST UPDATES LOADING
  // =========================================================================
  Future<void> loadData({bool silent = false}) async {
    const String updatesCacheKey = 'updates_feed_cache';
    const String highlightsCacheKey = 'updates_highlights_cache';

    // 1. MILLISECOND 0: Check Local Cache First (Instant Load)
    if (!silent) {
      final String? cachedUpdates = _cacheBox.get(updatesCacheKey);
      final String? cachedHighlights = _cacheBox.get(highlightsCacheKey);
      
      if (cachedUpdates != null) {
        try {
          final List<dynamic> feed = jsonDecode(cachedUpdates);
          final List<dynamic> highlights = cachedHighlights != null ? jsonDecode(cachedHighlights) : [];
          
          if (mounted) {
            state = state.copyWith(
              isLoading: false, // Turn off spinner immediately if cache exists
              posts: feed,
              filteredPosts: state.showMediaOnly ? feed.where((p) => p['mediaType'] == 'image').toList() : feed,
              highlights: highlights,
            );
          }
        } catch (e) {
          debugPrint("Updates Cache read error: $e");
        }
      } else if (state.posts.isEmpty) {
        state = state.copyWith(isLoading: true, errorMessage: null);
      }
    }

    // 2. CHECK CONNECTIVITY (Fail Fast)
    final connectivityResult = await (Connectivity().checkConnectivity());
    bool isOffline = connectivityResult.contains(ConnectivityResult.none);
    
    if (isOffline) {
      if (mounted && state.isLoading) state = state.copyWith(isLoading: false);
      return; 
    }

    // 3. BACKGROUND NETWORK FETCH (Concurrent & Timeout Enforced)
    try {
      // ✅ FIX: Run simultaneously and force a 10-second timeout so the spinner doesn't hang for minutes
      final results = await Future.wait([
        _dataService.fetchUpdates().timeout(const Duration(seconds: 10)),
        _authService.getProgrammes().timeout(const Duration(seconds: 10))
      ]);

      final feed = results[0];
      final programmes = results[1];

      // 4. OVERWRITE CACHE WITH FRESH DATA
      await _cacheBox.put(updatesCacheKey, jsonEncode(feed));
      await _cacheBox.put(highlightsCacheKey, jsonEncode(programmes));

      // 5. SILENTLY UPDATE UI
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          posts: feed,
          filteredPosts: state.showMediaOnly ? feed.where((p) => p['mediaType'] == 'image').toList() : feed,
          highlights: programmes,
        );
      }
    } catch (e) {
      // Catch timeouts and socket exceptions immediately
      if (mounted && state.posts.isEmpty) {
        state = state.copyWith(isLoading: false, errorMessage: "Failed to connect. Please check your network.");
      } else if (mounted) {
        state = state.copyWith(isLoading: false); // Ensure spinner turns off!
      }
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

  Future<String?> createPost(String text, List<XFile>? images) async {
    if (state.isPosting) return null; 

    state = state.copyWith(isPosting: true);
    try {
      final token = await _authService.getToken();
      var request = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/api/updates'));
      request.headers['auth-token'] = token ?? '';
      request.fields['text'] = text;

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

      // ✅ FIX 1: Enforce a strict 30-second timeout to prevent indefinite hanging
      var response = await request.send().timeout(const Duration(seconds: 30));
      
      state = state.copyWith(isPosting: false);

      if (response.statusCode == 201 || response.statusCode == 200) {
        // ✅ FIX 2: Removed 'await'. This tells the app to refresh the feed in the 
        // background, allowing the UI to return 'null' and close the sheet instantly.
        loadData(silent: true);
        return null; 
      } else {
        return "Failed to post update.";
      }
    } catch (e) {
      state = state.copyWith(isPosting: false);
      if (e.toString().contains('Timeout')) {
        return "Request timed out. Please check your network.";
      }
      return "Connection error.";
    }
  }

  Future<bool> deletePost(String postId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _api.delete('/api/updates/$postId');
      
      // Remove from cache directly to make it snappy
      final updatedPosts = state.posts.where((p) => p['_id'] != postId).toList();
      await _cacheBox.put('updates_feed_cache', jsonEncode(updatedPosts));

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