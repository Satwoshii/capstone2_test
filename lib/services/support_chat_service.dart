import '../models/chat_message.dart';
import '../models/support_issue.dart';
import '../models/support_chat_snapshot.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'app_config_service.dart';
import 'local_db_service.dart';

class SupportChatService {
  SupportChatService._();

  static final SupportChatService instance = SupportChatService._();

  Future<List<SupportIssue>> listConversations() async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.supportConversations,
      includeStudentToken: true,
    );
    return _mapIssues(response['conversations']);
  }

  Future<List<SupportIssue>> listActiveIssues() async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.supportActiveIssues,
      includeStudentToken: true,
    );
    return _mapIssues(response['issues']);
  }

  Future<SupportIssue> createConversation({
    required String category,
    required String subject,
    required String message,
    String? faultReportId,
  }) async {
    final cleanSubject = subject.trim();
    final cleanMessage = message.trim();
    if (cleanSubject.length < 3) {
      throw Exception('Enter a subject with at least 3 characters.');
    }
    if (cleanMessage.isEmpty) {
      throw Exception('Enter a message for ITSO Support.');
    }

    final response = await ApiClient.instance.postJson(
      ApiEndpoints.supportCreate,
      includeStudentToken: true,
      body: {
        'category': category.trim().toLowerCase(),
        'subject': cleanSubject,
        'message': cleanMessage,
        'fault_report_id': faultReportId,
      },
    );
    final raw = response['conversation'];
    if (raw is! Map) {
      throw Exception('The server did not return the support request.');
    }
    return SupportIssue.fromJson(
      raw.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<SupportIssue> openConversation(String faultReportId) async {
    final response = await ApiClient.instance.postJson(
      ApiEndpoints.supportOpenConversation,
      includeStudentToken: true,
      body: {'fault_report_id': faultReportId},
    );
    final raw = response['conversation'] ?? response['issue'];
    if (raw is! Map) {
      throw Exception('The server did not return the support conversation.');
    }
    return SupportIssue.fromJson(
      raw.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<SupportChatSnapshot> listMessages({
    required int conversationId,
    required String currentStudentUid,
  }) async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.supportMessages,
      includeStudentToken: true,
      query: {'conversation_id': conversationId.toString()},
    );

    final messages = <ChatMessage>[];
    final raw = response['messages'];
    if (raw is List) {
      for (final item in raw.whereType<Map>()) {
        messages.add(
          ChatMessage.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
      }
    }

    final pending = await LocalDbService.instance.getPendingChatMessages(
      conversationId: conversationId,
      senderUserUid: currentStudentUid,
    );
    messages.addAll(pending.map(ChatMessage.fromPendingLocal));
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return SupportChatSnapshot(
      messages: messages,
      status: (response['conversation_status'] ?? 'open').toString(),
      repaired: _toBool(response['repaired']),
    );
  }

  Future<ChatMessage> sendMessage({
    required int conversationId,
    required String? faultReportId,
    required String senderUserUid,
    required String message,
  }) async {
    final clean = message.trim();
    if (clean.isEmpty) throw Exception('Enter a message.');
    if (clean.length > 4000) throw Exception('The message is too long.');

    final clientMessageId =
        await LocalDbService.instance.insertPendingChatMessage(
      conversationId: conversationId,
      faultReportId: faultReportId ?? '',
      senderUserUid: senderUserUid,
      message: clean,
    );

    try {
      final response = await ApiClient.instance.postJson(
        ApiEndpoints.supportSend,
        includeStudentToken: true,
        body: {
          'conversation_id': conversationId,
          'message': clean,
          'client_message_id': clientMessageId,
        },
      );
      await LocalDbService.instance.markChatMessageSynced(clientMessageId);
      await LocalDbService.instance.deleteSyncedChatMessages();

      final raw = response['message'];
      if (raw is Map) {
        return ChatMessage.fromJson(
          raw.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } on ApiUnavailableException {
      // The local row remains pending and SyncService retries it later.
    } on ApiRequestException {
      await LocalDbService.instance.deletePendingChatMessage(clientMessageId);
      rethrow;
    }

    final rows = await LocalDbService.instance.getPendingChatMessages(
      conversationId: conversationId,
      senderUserUid: senderUserUid,
    );
    final row = rows.firstWhere(
      (item) => item['id']?.toString() == clientMessageId,
      orElse: () => <String, dynamic>{
        'id': clientMessageId,
        'conversationId': conversationId,
        'senderUserUid': senderUserUid,
        'message': clean,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
    return ChatMessage.fromPendingLocal(row);
  }

  Future<void> markRead(int conversationId) async {
    await ApiClient.instance.postJson(
      ApiEndpoints.supportMarkRead,
      includeStudentToken: true,
      body: {'conversation_id': conversationId},
    );
  }

  Future<int> syncPendingMessages() async {
    final userUid = await AppConfigService.instance.getStudentTokenUid();
    final token = await AppConfigService.instance.getStudentApiToken();
    if (userUid.isEmpty || token.isEmpty) return 0;

    final rows = await LocalDbService.instance.getUnsyncedChatMessages(
      senderUserUid: userUid,
    );
    var synced = 0;

    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      final conversationId = _toInt(row['conversationId']);
      final message = row['message']?.toString() ?? '';
      if (id.isEmpty || conversationId <= 0 || message.trim().isEmpty) continue;

      try {
        await ApiClient.instance.postJson(
          ApiEndpoints.supportSend,
          includeStudentToken: true,
          body: {
            'conversation_id': conversationId,
            'message': message,
            'client_message_id': id,
          },
        );
        await LocalDbService.instance.markChatMessageSynced(id);
        synced++;
      } on ApiRequestException catch (error) {
        if (error.code == 'conversation_closed' ||
            error.code == 'conversation_not_found') {
          await LocalDbService.instance.deletePendingChatMessage(id);
          continue;
        }
        rethrow;
      }
    }

    if (synced > 0) {
      await LocalDbService.instance.deleteSyncedChatMessages();
    }
    return synced;
  }

  List<SupportIssue> _mapIssues(dynamic raw) {
    if (raw is! List) return const <SupportIssue>[];
    return raw.whereType<Map>().map((item) {
      return SupportIssue.fromJson(
        item.map((key, value) => MapEntry(key.toString(), value)),
      );
    }).toList();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'yes';
  }
}
