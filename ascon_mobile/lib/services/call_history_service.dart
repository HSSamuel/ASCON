import 'api_client.dart';

class CallHistoryService {
  static final CallHistoryService _instance = CallHistoryService._internal();
  factory CallHistoryService() => _instance;
  CallHistoryService._internal();

  final ApiClient _api = ApiClient();

  /// Fetch synchronized call logs from the Server
  Future<List<dynamic>> getLogs() async {
    try {
      final res = await _api.get('/api/calls');
      
      if (res['success'] == true && res['data'] is List) {
        return res['data'];
      }
      return [];
    } catch (e) {
      // ✅ Now throws properly to the UI instead of returning an empty array silently
      throw Exception("Failed to fetch call logs: $e");
    }
  }

  /// Delete a specific call log by ID
  Future<void> deleteLog(String id) async {
    try {
      await _api.delete('/api/calls/$id');
    } catch (e) {
      throw Exception("Error deleting log: $e");
    }
  }
  
  /// Helper method to fetch unread missed calls count
  Future<int> getUnreadMissedCallsCount() async {
    try {
      final logs = await getLogs();
      int count = 0;
      for (var log in logs) {
        if ((log['status'] == 'missed' || log['type'] == 'missed') && log['read'] != true && log['isRead'] != true) {
          count++;
        }
      }
      return count;
    } catch (e) {
      // Throwing here is okay, but returning 0 allows the Badge logic to not break completely if offline
      return 0; 
    }
  }
}