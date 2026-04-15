import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:http_parser/http_parser.dart'; 
import '../config.dart';
import '../main.dart'; 
import '../screens/login_screen.dart'; 
import 'auth_service.dart'; 

class DataService {
  
  Future<Map<String, String>> _getHeaders() async {
    final String? token = await AuthService().getToken(); 
    return {
      'Content-Type': 'application/json',
      'auth-token': token ?? '', 
      'Authorization': 'Bearer ${token ?? ""}', 
    };
  }

  Future<void> _cacheData(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  Future<dynamic> _getCachedData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final String? cachedString = prefs.getString(key);
    if (cachedString != null) {
      debugPrint("📱 Loaded $key from Cache (Offline Mode)");
      return jsonDecode(cachedString);
    }
    return null;
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      _forceLogout(message: "Your session has expired. Please login again."); 
      throw Exception('Session expired'); 
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } 
    else {
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  }

  Future<void> _forceLogout({String message = "Session expired."}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 
    
    final context = navigatorKey.currentState?.context;
    
    if (context != null && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false, 
        builder: (ctx) => AlertDialog(
          title: const Text("Access Denied"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); 
                navigatorKey.currentState?.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    } else {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ==========================================
  // 1. USER PROFILE
  // ==========================================
  Future<Map<String, dynamic>?> fetchProfile() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/profile/me');
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 404) {
        _forceLogout(message: "We could not find your account details. You may need to register again.");
        return null;
      }

      final data = _handleResponse(response);

      if (data is Map<String, dynamic> && data.containsKey('data')) {
        return data['data'];
      }
      return data;
    } catch (e) {
      debugPrint("⚠️ Network Error or Logout triggered. Trying Cache...");
      return null; 
    }
  }

  Future<bool> updateProfile(Map<String, String> fields, XFile? imageFile) async {
    try {
      final token = await AuthService().getToken();
      if (token == null) return false;

      final uri = Uri.parse('${AppConfig.baseUrl}/api/profile/update');
      final request = http.MultipartRequest('PUT', uri);

      request.headers.addAll({'auth-token': token});
      request.fields.addAll(fields);

      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        String mimeType = "image/jpeg"; 
        if (imageFile.name.toLowerCase().endsWith(".png")) mimeType = "image/png";
        
        var type = MediaType.parse(mimeType);

        request.files.add(http.MultipartFile.fromBytes(
          'profilePicture',
          bytes,
          filename: imageFile.name,
          contentType: type,
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("❌ Update Error: $e");
      return false;
    }
  }

  // ==========================================
  // 2. EVENTS
  // ==========================================
  Future<List<dynamic>> fetchEvents() async {
    const String cacheKey = 'cached_events';
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/events');
      final response = await http.get(url, headers: headers);
      final data = _handleResponse(response);
      
      List<dynamic> events = [];
      if (data is List) {
        events = data;
      } else if (data is Map && data.containsKey('events') && data['events'] is List) {
        events = data['events'];
      } else if (data is Map && data.containsKey('data') && data['data'] is List) {
        events = data['data'];
      }
      await _cacheData(cacheKey, events);
      return events;
    } catch (e) {
      final cached = await _getCachedData(cacheKey);
      if (cached != null && cached is List) return cached;
      return []; 
    }
  }

  Future<Map<String, dynamic>?> fetchEventById(String id) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/events/$id');
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('data')) {
          return data['data'];
        }
        return data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint("❌ Error fetching single event: $e");
      return null;
    }
  }

  // ==========================================
  // 3. PROGRAMMES
  // ==========================================
  Future<Map<String, dynamic>?> fetchProgrammeById(String id) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/admin/programmes/$id'); 
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('data')) {
          return data['data'];
        }
        return data;
      }
    } catch (e) {
      debugPrint("Error fetching programme: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>> registerProgrammeInterest({
    required String programmeId,
    required String fullName,
    required String email,
    required String phone,
    required String sex,
    required String addressStreet,
    String? addressLine2,
    required String city,
    required String state,
    required String country,
    required String sponsoringOrganisation,
    required String department,
    required String jobTitle,
    String? userId,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/programme-interest');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'programmeId': programmeId,
          'fullName': fullName,
          'email': email,
          'phone': phone,
          'sex': sex,
          'addressStreet': addressStreet,
          'addressLine2': addressLine2 ?? "",
          'city': city,
          'state': state,
          'country': country,
          'sponsoringOrganisation': sponsoringOrganisation,
          'department': department,
          'jobTitle': jobTitle,
          if (userId != null) 'userId': userId,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error.'};
    }
  }

  // ==========================================
  // 4. UPDATES (Social Feed)
  // ==========================================
  Future<List<dynamic>> fetchUpdates() async {
    const String cacheKey = 'cached_updates';
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/updates');
      final response = await http.get(url, headers: headers);
      final data = _handleResponse(response);

      List<dynamic> updates = [];
      if (data is List) {
        updates = data;
      } else if (data is Map && data.containsKey('data') && data['data'] is List) {
        updates = data['data'];
      }
      
      await _cacheData(cacheKey, updates);
      return updates;
    } catch (e) {
      final cached = await _getCachedData(cacheKey);
      if (cached != null && cached is List) return cached;
      return [];
    }
  }

  // ==========================================
  // 5. DIRECTORY & GROUPS
  // ==========================================
  Future<Map<String, dynamic>?> fetchAlumniById(String userId) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/directory/$userId'); 
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? data; 
      }
      debugPrint("❌ fetchAlumniById failed with status: ${response.statusCode}");
      return null;
    } catch (e) {
      debugPrint("❌ Error fetching full alumni profile: $e");
      return null;
    }
  }

  Future<List<dynamic>> fetchDirectory({String query = ""}) async {
    final bool isDefaultFetch = query.isEmpty;
    const String cacheKey = 'cached_directory';
    try {
      final headers = await _getHeaders();
      String endpoint = '${AppConfig.baseUrl}/api/directory';
      if (query.isNotEmpty) endpoint += '?search=$query';
      
      final url = Uri.parse(endpoint);
      final response = await http.get(url, headers: headers);
      final data = _handleResponse(response);
      
      List<dynamic> alumni = [];
      if (data is List) {
        alumni = data;
      } else if (data is Map && data.containsKey('data') && data['data'] is List) {
        alumni = data['data']; 
      }
      
      if (isDefaultFetch) await _cacheData(cacheKey, alumni);
      return alumni;
    } catch (e) {
      if (isDefaultFetch) {
        final cached = await _getCachedData(cacheKey);
        if (cached != null && cached is List) return cached;
      }
      return [];
    }
  }

  Future<List<dynamic>> fetchMyGroups() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/groups/my-groups');
      final response = await http.get(url, headers: headers);
      final data = _handleResponse(response);

      if (data != null && data['success'] == true && data['data'] is List) {
        return data['data'];
      }
      return [];
    } catch (e) {
      debugPrint("Fetch Groups Error: $e");
      return [];
    }
  }

  // ✅ Renamed from fetchGroupInfo to match ChatScreen usage (or aliased)
  // This ensures the header data loading works
  Future<Map<String, dynamic>?> fetchGroupDetails(String groupId) async {
    return await fetchGroupInfo(groupId);
  }

  Future<Map<String, dynamic>?> fetchGroupInfo(String groupId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/api/groups/$groupId/info'), headers: headers);
      final data = _handleResponse(response);
      return data['data'];
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateGroupIcon(String groupId, XFile imageFile) async {
    try {
      final token = await AuthService().getToken();
      if (token == null) return false;

      final uri = Uri.parse('${AppConfig.baseUrl}/api/groups/$groupId/icon');
      final request = http.MultipartRequest('PUT', uri);

      request.headers.addAll({'auth-token': token});

      final bytes = await imageFile.readAsBytes();
      String mimeType = "image/jpeg";
      if (imageFile.name.toLowerCase().endsWith(".png")) mimeType = "image/png";
      
      var type = MediaType.parse(mimeType);

      request.files.add(http.MultipartFile.fromBytes(
        'icon',
        bytes,
        filename: imageFile.name,
        contentType: type,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("❌ Group Icon Update Error: $e");
      return false;
    }
  }

  Future<void> toggleGroupAdmin(String groupId, String targetUserId) async {
    try {
      final headers = await _getHeaders();
      await http.put(
        Uri.parse('${AppConfig.baseUrl}/api/groups/$groupId/toggle-admin'),
        headers: headers,
        body: jsonEncode({'targetUserId': targetUserId})
      );
    } catch (_) {}
  }

  Future<void> removeGroupMember(String groupId, String targetUserId) async {
    try {
      final headers = await _getHeaders();
      await http.put(
        Uri.parse('${AppConfig.baseUrl}/api/groups/$groupId/remove-member'),
        headers: headers,
        body: jsonEncode({'targetUserId': targetUserId})
      );
    } catch (_) {}
  }

  // ==========================================
  // 6. NOTIFICATIONS
  // ==========================================
  Future<List<dynamic>> fetchMyNotifications() async {
    try {
      final headers = await _getHeaders(); 
      final url = Uri.parse('${AppConfig.baseUrl}/api/notifications/my-notifications');
      
      final response = await http.get(url, headers: headers);
      final data = _handleResponse(response);

      if (data != null && data['success'] == true && data['data'] is List) {
        return data['data'];
      }
      return [];
    } catch (e) {
      debugPrint("Notification Fetch Error: $e");
      return [];
    }
  }

  Future<int> fetchUnreadNotificationCount() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/notifications/unread-count');
      
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<bool> deleteNotification(String id) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/notifications/$id');
      
      final response = await http.delete(url, headers: headers);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error deleting notification: $e");
      return false;
    }
  }

  // ==========================================
  // 7. MISC REGISTRATIONS
  // ==========================================
  Future<Map<String, dynamic>> registerEventInterest({
    required String eventId,
    required String eventTitle,
    required String eventType,
    required String fullName,
    required String email,
    required String phone,
    required String sex,
    required String organization,
    required String jobTitle,
    String? specialRequirements,
    String? userId,
  }) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/api/event-registration');

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "eventId": eventId,
          "eventTitle": eventTitle,
          "eventType": eventType,
          "fullName": fullName,
          "email": email,
          "phone": phone,
          "sex": sex,
          "organization": organization,
          "jobTitle": jobTitle,
          "specialRequirements": specialRequirements,
          "userId": userId,
        }),
      );

      final data = jsonDecode(response.body);
      return {"success": response.statusCode == 201, "message": data['message'] ?? "Registration submitted"};
    } catch (e) {
      return {"success": false, "message": "Connection error. Please try again."};
    }
  }

  // ==========================================
  // 8. MENTORSHIP
  // ==========================================
  Future<String> getMentorshipStatus(String targetUserId) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/mentorship/status/$targetUserId');
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status']; 
      }
      return "None";
    } catch (e) {
      return "None";
    }
  }

  Future<Map<String, dynamic>> sendMentorshipRequest(String mentorId, String pitch) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/mentorship/request');
      
      final response = await http.post(
        url, 
        headers: headers,
        body: jsonEncode({'mentorId': mentorId, 'pitch': pitch})
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 201) {
         return {'success': true, 'message': 'Request Sent Successfully!'};
      } else {
         return {'success': false, 'message': data['message'] ?? 'Failed to send request.'};
      }
    } catch (e) {
      debugPrint("Mentorship Request Error: $e");
      return {'success': false, 'message': 'Connection Error. Please try again.'};
    }
  }

  Future<bool> respondToMentorshipRequest(String requestId, String status) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/mentorship/respond/$requestId');
      
      final response = await http.put(
        url, 
        headers: headers,
        body: jsonEncode({'status': status})
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getMentorshipDashboard() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/mentorship/dashboard');
      final response = await http.get(url, headers: headers);

      final data = _handleResponse(response);
      return data;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getMentorshipStatusFull(String targetUserId) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/mentorship/status/$targetUserId');
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': "None"};
    } catch (e) {
      return {'status': "None"};
    }
  }

  Future<bool> deleteMentorshipInteraction(String requestId, String type) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/mentorship/$type/$requestId');
      
      final response = await http.delete(url, headers: headers);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ==========================================
  // 9. SMART RECOMMENDATIONS & AI
  // ==========================================
  Future<Map<String, dynamic>> fetchRecommendations() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/directory/recommendations');
      
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'matches': []};
    } catch (e) {
      return {'success': false, 'matches': []};
    }
  }

  Future<List<dynamic>> fetchSmartMatches() async {
    const String cacheKey = 'cached_smart_matches';
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/directory/smart-matches');
      final response = await http.get(url, headers: headers);
      final data = _handleResponse(response);

      if (data != null && data['success'] == true && data['data'] is List) {
        await _cacheData(cacheKey, data['data']);
        return data['data'];
      }
      return [];
    } catch (e) {
      final cached = await _getCachedData(cacheKey);
      if (cached != null && cached is List) return cached;
      return [];
    }
  }

  Future<List<dynamic>> fetchAlumniNearMe({String? city}) async {
    try {
      final headers = await _getHeaders();
      String endpoint = '${AppConfig.baseUrl}/api/directory/near-me';
      if (city != null && city.isNotEmpty) {
        endpoint += '?city=$city';
      }
      
      final url = Uri.parse(endpoint);
      final response = await http.get(url, headers: headers);
      final data = _handleResponse(response);

      if (data != null && data['success'] == true && data['data'] is List) {
        return data['data'];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ==========================================
  // 🗳️ POLLS
  // ==========================================
  Future<List<dynamic>> fetchPolls() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/api/polls'), headers: headers);
      final data = _handleResponse(response);
      return data['data'] ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> votePoll(String pollId, String optionId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/api/polls/$pollId/vote'),
        headers: headers,
        body: jsonEncode({'optionId': optionId})
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ==========================================
  // 🎂 CELEBRATIONS
  // ==========================================
  Future<dynamic> fetchCelebrants() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/api/directory/celebrations'), headers: headers);
      final data = _handleResponse(response);
      return data['data'] ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> removeGroupIcon(String groupId) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/groups/$groupId/icon');
      final response = await http.delete(url, headers: headers);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteGroupNotice(String groupId, String noticeId) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/groups/$groupId/notices/$noticeId');
      final response = await http.delete(url, headers: headers);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> editGroupNotice(String groupId, String noticeId, String title, String content) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/groups/$groupId/notices/$noticeId');
      final response = await http.put(
        url, 
        headers: headers,
        body: jsonEncode({'title': title, 'content': content})
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> fetchGroupPolls(String groupId) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/polls/group/$groupId');
      final response = await http.get(url, headers: headers);
      final data = _handleResponse(response);
      return data['data'] ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> deletePoll(String pollId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/api/polls/$pollId'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updatePollQuestion(String pollId, String newQuestion) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/api/polls/$pollId'),
        headers: headers,
        body: jsonEncode({'question': newQuestion}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteGroupDocument(String groupId, String docId) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/groups/$groupId/documents/$docId');
      final response = await http.delete(url, headers: headers);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Delete Document Error: $e");
      return false;
    }
  }
}