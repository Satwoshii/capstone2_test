class ChatMessage {
  final String id;
  final int conversationId;
  final String senderUid;
  final String senderRole;
  final String senderName;
  final String message;
  final DateTime createdAt;
  final bool read;
  final bool pending;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderUid,
    required this.senderRole,
    required this.senderName,
    required this.message,
    required this.createdAt,
    required this.read,
    this.pending = false,
  });

  bool get isStudent => senderRole.trim().toLowerCase() == 'student';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] ?? json['client_message_id'] ?? '').toString(),
      conversationId: _toInt(json['conversation_id']),
      senderUid: (json['sender_uid'] ?? '').toString(),
      senderRole: (json['sender_role'] ?? '').toString(),
      senderName: (json['sender_name'] ?? json['sender_role'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      read: _toBool(json['read']),
      pending: _toBool(json['pending']),
    );
  }

  factory ChatMessage.fromPendingLocal(Map<String, dynamic> row) {
    return ChatMessage(
      id: (row['id'] ?? '').toString(),
      conversationId: _toInt(row['conversationId']),
      senderUid: (row['senderUserUid'] ?? '').toString(),
      senderRole: 'student',
      senderName: 'You',
      message: (row['message'] ?? '').toString(),
      createdAt: DateTime.tryParse((row['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      read: false,
      pending: true,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'yes';
  }
}
