import 'chat_message.dart';

class SupportChatSnapshot {
  final List<ChatMessage> messages;
  final String status;
  final bool repaired;

  const SupportChatSnapshot({
    required this.messages,
    required this.status,
    required this.repaired,
  });

  bool get canChat {
    final normalized = status.trim().toLowerCase();
    return !repaired && normalized != 'resolved' && normalized != 'closed';
  }
}
