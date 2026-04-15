import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';

class EventsState {
  final List<dynamic> events;
  final bool isLoading;
  final bool isPosting;
  final bool isAdmin;
  final String? errorMessage;

  const EventsState({
    this.events = const [],
    this.isLoading = true,
    this.isPosting = false,
    this.isAdmin = false,
    this.errorMessage,
  });

  EventsState copyWith({
    List<dynamic>? events,
    bool? isLoading,
    bool? isPosting,
    bool? isAdmin,
    String? errorMessage,
  }) {
    return EventsState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      isPosting: isPosting ?? this.isPosting,
      isAdmin: isAdmin ?? this.isAdmin,
      errorMessage: errorMessage,
    );
  }
}

class EventsNotifier extends StateNotifier<EventsState> {
  final DataService _dataService = DataService();
  final ApiClient _api = ApiClient();
  final AuthService _authService = AuthService();

  EventsNotifier() : super(const EventsState()) {
    init();
  }

  void init() {
    checkAdmin();
    loadEvents();
  }

  Future<void> checkAdmin() async {
    final bool adminStatus = await _authService.isAdmin;
    state = state.copyWith(isAdmin: adminStatus);
  }

  Future<void> loadEvents({bool silent = false}) async {
    if (!silent) state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      final fetchedEvents = await _dataService.fetchEvents();
      fetchedEvents.sort((a, b) {
        final da = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });

      if (mounted) {
        state = state.copyWith(isLoading: false, events: fetchedEvents);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, errorMessage: "Could not load events.");
      }
    }
  }

  Future<bool> deleteEvent(String eventId) async {
    final previousEvents = state.events;
    state = state.copyWith(events: state.events.where((e) => (e['_id'] ?? e['id']) != eventId).toList());

    try {
      await _api.delete('/api/events/$eventId');
      return true;
    } catch (e) {
      state = state.copyWith(events: previousEvents, errorMessage: "Failed to delete event.");
      return false;
    }
  }

  Future<bool> deleteProgramme(String programmeId) async {
    try {
      await _api.delete('/api/admin/programmes/$programmeId');
      return true;
    } catch (e) {
      return false;
    }
  }

  // ✅ UPDATED: Accept List of Images
  Future<String?> createEvent({
    required String title,
    required String description,
    required String location,
    required String time,
    required String type,
    required DateTime date,
    List<XFile>? images,
  }) async {
    return _uploadContent(
      endpoint: '/api/events',
      fields: {
        'title': title,
        'description': description,
        'location': location,
        'time': time,
        'type': type,
        'date': date.toIso8601String(),
      },
      images: images,
    );
  }

  // ✅ UPDATED: Accept List of Images
  Future<String?> createProgramme({
    required String title,
    required String description,
    required String location,
    required String duration,
    required String fee,
    List<XFile>? images,
  }) async {
    return _uploadContent(
      endpoint: '/api/admin/programmes',
      fields: {
        'title': title,
        'description': description,
        'location': location,
        'duration': duration,
        'fee': fee,
      },
      images: images,
    );
  }

  // ✅ UPDATED: Generic Upload Helper (Handles Multiple Images)
  Future<String?> _uploadContent({
    required String endpoint,
    required Map<String, String> fields,
    List<XFile>? images,
  }) async {
    state = state.copyWith(isPosting: true);
    try {
      final token = await _authService.getToken();
      var request = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}$endpoint'));
      request.headers['auth-token'] = token ?? '';

      fields.forEach((key, value) => request.fields[key] = value);

      // Loop through and append images array to MultipartRequest
      if (images != null && images.isNotEmpty) {
        for (var img in images) {
          if (kIsWeb) {
            var bytes = await img.readAsBytes();
            request.files.add(http.MultipartFile.fromBytes('images', bytes, filename: img.name));
          } else {
            request.files.add(await http.MultipartFile.fromPath('images', img.path));
          }
        }
      }

      var response = await request.send();
      final respStr = await response.stream.bytesToString();

      state = state.copyWith(isPosting: false);

      if (response.statusCode == 201) {
        await loadEvents(silent: true);
        return null;
      } else {
        final errorJson = jsonDecode(respStr);
        return errorJson['message'] ?? "Upload failed";
      }
    } catch (e) {
      state = state.copyWith(isPosting: false);
      return "Connection Error: ${e.toString()}";
    }
  }
}

final eventsProvider = StateNotifierProvider.autoDispose<EventsNotifier, EventsState>((ref) {
  return EventsNotifier();
});