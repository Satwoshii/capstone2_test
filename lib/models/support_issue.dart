class SupportIssue {
  final String? faultReportId;
  final String workstationId;
  final String roomName;
  final String pcId;
  final String category;
  final String subject;
  final String issue;
  final String details;
  final String severity;
  final bool linkedFault;
  final bool repaired;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? conversationId;
  final String? conversationStatus;
  final int unreadCount;

  const SupportIssue({
    required this.faultReportId,
    required this.workstationId,
    required this.roomName,
    required this.pcId,
    required this.category,
    required this.subject,
    required this.issue,
    required this.details,
    required this.severity,
    required this.linkedFault,
    required this.repaired,
    this.createdAt,
    this.updatedAt,
    this.conversationId,
    this.conversationStatus,
    this.unreadCount = 0,
  });

  bool get hasConversation => conversationId != null && conversationId! > 0;

  bool get canChat {
    final value = (conversationStatus ?? 'open').trim().toLowerCase();
    return !repaired && value != 'resolved' && value != 'closed';
  }

  factory SupportIssue.fromJson(Map<String, dynamic> json) {
    final faultId = _nullable(json['fault_report_id']);
    final subject = (json['subject'] ?? json['issue'] ?? 'ITSO Support Request')
        .toString();
    return SupportIssue(
      faultReportId: faultId,
      workstationId: (json['workstation_id'] ?? '').toString(),
      roomName: (json['room_name'] ?? '').toString(),
      pcId: (json['pc_id'] ?? '').toString(),
      category: (json['category'] ?? 'general').toString(),
      subject: subject,
      issue: (json['issue'] ?? subject).toString(),
      details: (json['details'] ?? '').toString(),
      severity: (json['severity'] ?? 'normal').toString(),
      linkedFault: _toBool(json['linked_fault']) || faultId != null,
      repaired: _toBool(json['repaired']),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
      conversationId: _toNullableInt(
        json['conversation_id'] ?? json['id'],
      ),
      conversationStatus: _nullable(
        json['conversation_status'] ?? json['status'],
      ),
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

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'yes';
  }

  static String? _nullable(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
