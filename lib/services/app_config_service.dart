import '../models/pc_identity.dart';
import 'local_db_service.dart';

class AppConfigService {
  AppConfigService._();

  static final AppConfigService instance = AppConfigService._();

  Future<void> init() async {
    final room = await LocalDbService.instance.getConfig('roomName');
    final pc = await LocalDbService.instance.getConfig('pcId');

    if (room == null) {
      await LocalDbService.instance.setConfig('roomName', 'Lab 1');
    }

    if (pc == null) {
      await LocalDbService.instance.setConfig('pcId', 'PC-01');
    }
  }

  Future<PcIdentity> getPcIdentity() async {
    final room = await LocalDbService.instance.getConfig('roomName') ?? 'Lab 1';
    final pc = await LocalDbService.instance.getConfig('pcId') ?? 'PC-01';

    return PcIdentity(roomName: room, pcId: pc);
  }

  Future<void> savePcIdentity(PcIdentity identity) async {
    await LocalDbService.instance.setConfig('roomName', identity.roomName);
    await LocalDbService.instance.setConfig('pcId', identity.pcId);
  }
}
