import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/chat_objects.dart';
import '../services/api_client.dart';

class ChatService {
  final ApiClient _api = ApiClient();

  Future<List<ChatMessage>> fetchMessages(String conversationId, {String? beforeId}) async {
    String endpoint = '/api/chat/$conversationId';
    if (beforeId != null) endpoint += '?beforeId=$beforeId';

    final result = await _api.get(endpoint);
    if (result['success'] == true) {
      final List<dynamic> data = result['data'];
      return data.map((m) => ChatMessage.fromJson(m)).toList();
    }
    return [];
  }

  Future<String?> startConversation(String receiverId, {String? groupId}) async {
    final Map<String, dynamic> body = {'receiverId': receiverId};
    if (groupId != null) body['groupId'] = groupId;

    final result = await _api.post('/api/chat/start', body);
    if (result['success'] == true) {
      return result['data']['_id'];
    }
    return null;
  }

  Future<ChatMessage?> sendMessage({
    required String conversationId,
    required String token,
    String? text,
    String? type,
    String? replyToId,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final baseUrl = AppConfig.baseUrl.endsWith('/')
        ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
        : AppConfig.baseUrl;
        
    final uri = Uri.parse('$baseUrl/api/chat/$conversationId');
    var request = http.MultipartRequest('POST', uri);
    request.headers['auth-token'] = token;

    if (text != null) request.fields['text'] = text;
    if (type != null) request.fields['type'] = type;
    if (replyToId != null) request.fields['replyToId'] = replyToId;

    if (fileBytes != null) {
      request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName ?? 'upload'));
    } else if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ChatMessage.fromJson(data);
    }
    return null;
  }

  Future<void> deleteMessages(List<String> ids, bool deleteForEveryone) async {
    await _api.post('/api/chat/delete-multiple', {
      'messageIds': ids,
      'deleteForEveryone': deleteForEveryone
    });
  }

  Future<void> markRead(String conversationId) async {
    await _api.put('/api/chat/read/$conversationId', {});
  }
}