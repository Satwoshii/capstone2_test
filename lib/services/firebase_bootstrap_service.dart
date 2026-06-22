import 'package:cloud_firestore/cloud_firestore.dart';

import 'pc_identity_service.dart';

class FirebaseBootstrapService {
  FirebaseBootstrapService._();

  static final FirebaseBootstrapService instance = FirebaseBootstrapService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initialize() async {
    await _createSystemConfiguration();
    await _registerCurrentPc();
    await _seedTroubleshootingGuides();
  }

  Future<void> _createSystemConfiguration() async {
    await _firestore.collection('system_config').doc('main').set({
      'appName': 'NU Clark ITSO Monitoring System',
      'schemaVersion': 2,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _registerCurrentPc() async {
    final computerName = PcIdentityService.getComputerName();
    final reference = _firestore.collection('pcs').doc(computerName);
    final existing = await reference.get();

    await reference.set({
      'computerName': computerName,
      'pcNumber': PcIdentityService.getPcNumberFromComputerName(),
      'room': PcIdentityService.getRoomFromComputerName(),
      'windowsDomain': PcIdentityService.getDomainName(),
      'status': 'active',
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _seedTroubleshootingGuides() async {
    const guides = <String, Map<String, dynamic>>{
      'mouse_not_detected': {
        'issueType': 'mouse',
        'title': 'Mouse not detected',
        'suggestion': 'Reconnect the mouse and test another USB port.',
      },
      'keyboard_not_detected': {
        'issueType': 'keyboard',
        'title': 'Keyboard not detected',
        'suggestion': 'Reconnect the keyboard and test another USB port.',
      },
      'monitor_not_detected': {
        'issueType': 'monitor',
        'title': 'Monitor not detected',
        'suggestion': 'Check the monitor power and display cable.',
      },
      'network_not_detected': {
        'issueType': 'network',
        'title': 'Network unavailable',
        'suggestion': 'Check the Ethernet cable and network adapter.',
      },
      'storage_warning': {
        'issueType': 'storage',
        'title': 'Storage warning',
        'suggestion': 'Save your work and notify ITSO immediately.',
      },
    };

    final batch = _firestore.batch();
    for (final entry in guides.entries) {
      batch.set(
        _firestore.collection('troubleshooting_guides').doc(entry.key),
        {
          ...entry.value,
          'enabled': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }
}
