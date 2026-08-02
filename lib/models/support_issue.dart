class SupportIssue {
  final String faultReportId;
  final String workstationId;
  final String roomName;
  final String pcId;
  final String issue;
  final String details;
  final String severity;
  final DateTime? createdAt;
  final int? conversationId;
  final String? conversationStatus;
  final int unreadCount;

  const SupportIssue({
    required this.faultReportId,
    required this.workstationId,
    required this.roomName,
    required this.pcId,
    required this.issue,
    required this.details,
    required this.severity,
    this.createdAt,
    this.conversationId,
    this.conversationStatus,
    this.unreadCount = 0,
  });

  bool get hasConversation => conversationId != null && conversationId! > 0;

  bool get canChat {
    final value = (conversationStatus ?? 'open').trim().toLowerCase();
    return value != 'resolved' && value != 'closed';
  }

  factory SupportIssue.fromJson(Map<String, dynamic> json) {
    return SupportIssue(
      faultReportId: (json['fault_report_id'] ?? json['id'] ?? '').toString(),
      workstationId: (json['workstation_id'] ?? '').toString(),
      roomName: (json['room_name'] ?? '').toString(),
      pcId: (json['pc_id'] ?? '').toString(),
      issue: (json['issue'] ?? 'Unknown issue').toString(),
      details: (json['details'] ?? '').toString(),
      severity: (json['severity'] ?? 'medium').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      conversationId: _toNullableInt(json['conversation_id']),
      conversationStatus: _nullable(json['conversation_status']),
      unreadCount: _toInt(json['unread_count']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _toNullableInt(dynamic value) {
    final parsed = _toInt(value);
    return parsed <= 0 ? null : parsed;
  }

  static String? _nullable(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
