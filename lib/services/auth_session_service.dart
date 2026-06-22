import 'package:cloud_firestore/cloud_firestore.dart';

class AuthSessionService {
  AuthSessionService._();

  static final AuthSessionService instance =
  AuthSessionService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<void> createSession({
    required String sessionId,
    required String pcNumber,
    required String room,
  }) async {
    final now = DateTime.now();

    await _firestore
        .collection('auth_sessions')
        .doc(sessionId)
        .set({
      'sessionId': sessionId,
      'pcNumber': pcNumber,
      'room': room,
      'status': 'pending',
      'studentEmail': null,
      'studentUid': null,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(
        now.add(const Duration(minutes: 2)),
      ),
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>
  watchSession(
      String sessionId,
      ) {
    return _firestore
        .collection('auth_sessions')
        .doc(sessionId)
        .snapshots();
  }

  Future<void> approveSession({
    required String sessionId,
    required String studentEmail,
    required String studentUid,
  }) async {
    final reference = _firestore
        .collection('auth_sessions')
        .doc(sessionId);

    final snapshot = await reference.get();
    final data = snapshot.data();

    if (data == null) {
      throw StateError(
        'Authentication session was not found.',
      );
    }

    final status = data['status']?.toString();

    if (status == 'approved') {
      throw StateError(
        'This authentication session was already approved.',
      );
    }

    if (status == 'expired') {
      throw StateError(
        'This authentication session has expired.',
      );
    }

    if (status == 'cancelled') {
      throw StateError(
        'This authentication session was cancelled.',
      );
    }

    final expiresAt = data['expiresAt'];

    if (expiresAt is Timestamp &&
        expiresAt.toDate().isBefore(DateTime.now())) {
      await reference.update({
        'status': 'expired',
        'expiredAt': FieldValue.serverTimestamp(),
      });

      throw StateError(
        'The authentication QR code has expired.',
      );
    }

    await reference.update({
      'status': 'approved',
      'studentEmail': studentEmail,
      'studentUid': studentUid,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelSession(
      String sessionId,
      ) async {
    final reference = _firestore
        .collection('auth_sessions')
        .doc(sessionId);

    final snapshot = await reference.get();

    if (!snapshot.exists) return;

    final status =
    snapshot.data()?['status']?.toString();

    if (status == 'approved' ||
        status == 'expired' ||
        status == 'cancelled') {
      return;
    }

    await reference.update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> expireSession(
      String sessionId,
      ) async {
    final reference = _firestore
        .collection('auth_sessions')
        .doc(sessionId);

    final snapshot = await reference.get();

    if (!snapshot.exists) return;

    final status =
    snapshot.data()?['status']?.toString();

    if (status != 'pending') return;

    await reference.update({
      'status': 'expired',
      'expiredAt': FieldValue.serverTimestamp(),
    });
  }
}