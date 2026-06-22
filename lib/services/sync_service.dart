import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'firebase_user_service.dart';
import 'local_db_service.dart';

class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ValueNotifier<int> pendingItems = ValueNotifier<int>(0);

  Timer? _timer;

  Future<void> start() async {
    await refreshPendingCount();
    await syncNow();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) async {
      await refreshPendingCount();
      await syncNow();
    });
  }

  Future<bool> hasInternet() async {
    try {
      final result = await Connectivity().checkConnectivity();

      if (result.contains(ConnectivityResult.none)) {
        return false;
      }

      final lookup = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));

      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<int> refreshPendingCount() async {
    final loginLogs =
    await LocalDbService.instance.getUnsyncedRows('login_logs');
    final faultReports =
    await LocalDbService.instance.getUnsyncedRows('fault_reports');
    final maintenanceLogs =
    await LocalDbService.instance.getUnsyncedRows('maintenance_logs');
    final pcStatus = await LocalDbService.instance.getUnsyncedRows('pc_status');

    final count = loginLogs.length +
        faultReports.length +
        maintenanceLogs.length +
        pcStatus.length;

    pendingItems.value = count;
    return count;
  }

  Future<void> syncPendingData() async {
    await syncNow();
  }

  Future<void> syncNow() async {
    final online = await hasInternet();

    if (!online) {
      await refreshPendingCount();
      return;
    }

    try {
      await FirebaseUserService.downloadUsersToSQLite();

      await _syncTable(
        localTable: 'login_logs',
        firestoreCollection: 'login_logs',
      );

      await _syncTable(
        localTable: 'fault_reports',
        firestoreCollection: 'fault_reports',
      );

      await _syncTable(
        localTable: 'maintenance_logs',
        firestoreCollection: 'maintenance_logs',
      );

      await _syncTable(
        localTable: 'pc_status',
        firestoreCollection: 'pc_status',
      );

      await seedDefaultRoomsAndPcs();
      await refreshPendingCount();
    } catch (_) {
      await refreshPendingCount();
    }
  }

  Future<void> _syncTable({
    required String localTable,
    required String firestoreCollection,
  }) async {
    final rows = await LocalDbService.instance.getUnsyncedRows(localTable);

    for (final row in rows) {
      final id = row['id'].toString();
      final data = Map<String, dynamic>.from(row);
      data.remove('synced');

      await _firestore
          .collection(firestoreCollection)
          .doc(id)
          .set(data, SetOptions(merge: true));

      await LocalDbService.instance.markSynced(localTable, id);
    }
  }

  Future<void> seedDefaultRoomsAndPcs() async {
    final rooms = ['Lab 1', 'Lab 2', 'Lab 3'];

    for (final room in rooms) {
      await _firestore.collection('rooms').doc(room).set({
        'roomName': room,
        'active': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      for (int i = 1; i <= 3; i++) {
        final pcId = 'PC-${i.toString().padLeft(2, '0')}';

        await _firestore.collection('pcs').doc('${room}_$pcId').set({
          'roomName': room,
          'pcId': pcId,
          'status': 'unknown',
          'active': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    await _firestore.collection('system_config').doc('default').set({
      'appName': 'Hybrid PC Monitoring System',
      'offlineFirst': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}