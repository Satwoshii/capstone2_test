import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/pc_identity.dart';

class DuplicateWorkstationLocationException implements Exception {
  final String workstationId;

  const DuplicateWorkstationLocationException(this.workstationId);

  @override
  String toString() {
    return 'This room and PC ID are already assigned to $workstationId.';
  }
}

class WorkstationRegistryService {
  WorkstationRegistryService._();

  static final WorkstationRegistryService instance =
  WorkstationRegistryService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User> ensureDevelopmentWorkstationSession() async {
    final current = _auth.currentUser;

    if (current != null) return current;

    final credential = await _auth.signInAnonymously().timeout(
      const Duration(seconds: 12),
    );

    final user = credential.user;

    if (user == null) {
      throw StateError(
        'Firebase did not create a workstation session.',
      );
    }

    return user;
  }

  Future<void> restoreDevelopmentWorkstationSession() async {
    final current = _auth.currentUser;

    if (current?.isAnonymous == true) return;

    await _auth.signOut();
    await ensureDevelopmentWorkstationSession();
  }

  Future<void> registerOrUpdate(PcIdentity identity) async {
    if (!identity.isConfigured) {
      throw ArgumentError('Room name and PC ID are required.');
    }

    final currentUser =
        _auth.currentUser ?? await ensureDevelopmentWorkstationSession();

    final roomKey = _locationKey(identity.roomName);
    final pcKey = _locationKey(identity.pcId);

    final duplicate = await _firestore
        .collection('workstations')
        .where('roomKey', isEqualTo: roomKey)
        .where('pcKey', isEqualTo: pcKey)
        .limit(2)
        .get()
        .timeout(const Duration(seconds: 12));

    for (final document in duplicate.docs) {
      if (document.id != identity.workstationId) {
        throw DuplicateWorkstationLocationException(document.id);
      }
    }

    final reference = _firestore
        .collection('workstations')
        .doc(identity.workstationId);

    final existing =
    await reference.get().timeout(const Duration(seconds: 12));

    await reference.set({
      'workstationId': identity.workstationId,
      'roomName': identity.roomName,
      'pcId': identity.pcId,
      'roomKey': roomKey,
      'pcKey': pcKey,
      'firebaseUid': currentUser.uid,
      'active': true,
      'status': 'online',
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(const Duration(seconds: 12));

    if (!currentUser.isAnonymous) {
      try {
        await _firestore.collection('audit_logs').add({
          'action': existing.exists
              ? 'workstation_location_updated'
              : 'workstation_registered',
          'workstationId': identity.workstationId,
          'roomName': identity.roomName,
          'pcId': identity.pcId,
          'previousRoomName': existing.data()?['roomName'],
          'previousPcId': existing.data()?['pcId'],
          'actorUid': currentUser.uid,
          'actorEmail': currentUser.email,
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 12));
      } catch (_) {
        // Registration must not be rolled back by a failed audit write.
      }
    }
  }

  Future<void> updateHeartbeat(
      PcIdentity identity,
      String status,
      ) async {
    if (!identity.isConfigured) return;

    final user = await ensureDevelopmentWorkstationSession();

    await _firestore
        .collection('workstations')
        .doc(identity.workstationId)
        .set({
      ...identity.toMap(),
      'firebaseUid': user.uid,
      'active': true,
      'status': status,
      'lastSeenAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(
      const Duration(seconds: 12),
    );
  }

  String _locationKey(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toUpperCase();
  }
}