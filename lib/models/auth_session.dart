import 'package:cloud_firestore/cloud_firestore.dart';

class AuthSession {
  final String sessionId;
  final String pcNumber;
  final String room;
  final String status;
  final String? studentEmail;
  final DateTime createdAt;
  final DateTime expiresAt;

  const AuthSession({
    required this.sessionId,
    required this.pcNumber,
    required this.room,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.studentEmail,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toFirestore() {
    return {
      'sessionId': sessionId,
      'pcNumber': pcNumber,
      'room': room,
      'status': status,
      'studentEmail': studentEmail,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  factory AuthSession.fromFirestore(Map<String, dynamic> data) {
    return AuthSession(
      sessionId: data['sessionId']?.toString() ?? '',
      pcNumber: data['pcNumber']?.toString() ?? '',
      room: data['room']?.toString() ?? '',
      status: data['status']?.toString() ?? 'pending',
      studentEmail: data['studentEmail']?.toString(),
      createdAt: _dateFromValue(data['createdAt']),
      expiresAt: _dateFromValue(data['expiresAt']),
    );
  }

  static DateTime _dateFromValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }
}
