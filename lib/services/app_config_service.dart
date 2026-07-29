import 'package:uuid/uuid.dart';

import '../models/pc_identity.dart';
import 'local_db_service.dart';

class AppConfigService {
  AppConfigService._();

  static final AppConfigService instance = AppConfigService._();

  Future<void> init() async {
    final workstationId =
    await LocalDbService.instance.getConfig('workstationId');

    if (workstationId == null || workstationId.trim().isEmpty) {
      final randomId = const Uuid()
          .v4()
          .replaceAll('-', '')
          .toUpperCase()
          .substring(0, 20);

      await LocalDbService.instance.setConfig(
        'workstationId',
        'WS-$randomId',
      );
    }
  }

  Future<PcIdentity> getPcIdentity() async {
    final workstationId =
    await LocalDbService.instance.getConfig('workstationId');

    final room =
        await LocalDbService.instance.getConfig('roomName') ?? '';

    final pc =
        await LocalDbService.instance.getConfig('pcId') ?? '';

    if (workstationId == null || workstationId.trim().isEmpty) {
      await init();
      return getPcIdentity();
    }

    return PcIdentity(
      workstationId: workstationId,
      roomName: room,
      pcId: pc,
    );
  }

  Future<void> savePcIdentity(PcIdentity identity) async {
    final current = await getPcIdentity();

    if (identity.workstationId != current.workstationId) {
      throw StateError(
        'The permanent workstation ID cannot be changed.',
      );
    }

    if (identity.roomName.trim().isEmpty ||
        identity.pcId.trim().isEmpty) {
      throw ArgumentError('Room name and PC ID are required.');
    }

    await LocalDbService.instance.setConfig(
      'roomName',
      identity.roomName,
    );

    await LocalDbService.instance.setConfig(
      'pcId',
      identity.pcId,
    );

    await LocalDbService.instance.setConfig(
      'workstationRegistered',
      'true',
    );
  }

  Future<bool> isRegistrationConfirmed() async {
    return await LocalDbService.instance.getConfig(
      'workstationRegistered',
    ) ==
        'true';
  }
}