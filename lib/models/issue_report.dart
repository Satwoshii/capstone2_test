class IssueReport {
  final String id;
  final String studentEmail;
  final String pcNumber;
  final String room;
  final String issueType;
  final String description;
  final String severity;
  final String source;
  final bool detectedBySystem;
  final DateTime createdAt;

  IssueReport({
    required this.id,
    required this.studentEmail,
    required this.pcNumber,
    required this.room,
    required this.issueType,
    required this.description,
    required this.severity,
    required this.source,
    required this.detectedBySystem,
    required this.createdAt,
  });

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'studentEmail': studentEmail,
      'pcNumber': pcNumber,
      'room': room,
      'issueType': issueType,
      'description': description,
      'severity': severity,
      'source': source,
      'detectedBySystem': detectedBySystem ? 1 : 0,
      'createdAt': createdAt,
    };
  }
}