import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import 'auth_service.dart';
import 'local_db_service.dart';

class FirebaseUserService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<AppUser> loginStaff({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();

    if (!doc.exists) {
      throw Exception('User profile does not exist in Firestore.');
    }

    final user = AppUser.fromFirestore(doc);

    if (!user.active) {
      throw Exception('This account is disabled.');
    }

    await LocalDbService.instance.upsertUser(user);

    return user;
  }

  static Future<void> downloadUsersToSQLite() async {
    final snapshot = await _firestore.collection('users').get();

    for (final doc in snapshot.docs) {
      final user = AppUser.fromFirestore(doc);
      await LocalDbService.instance.upsertUser(user);
    }
  }

  static Future<void> createUserProfile({
    required String uid,
    required String email,
    required String displayName,
    required String role,
    String? studentId,
    String? plainPassword,
  }) async {
    final passwordHash =
        plainPassword == null ? null : AuthService.hashPassword(plainPassword);

    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role,
      'studentId': studentId,
      'passwordHash': passwordHash,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
