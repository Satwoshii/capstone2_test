import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/pc_identity.dart';
import 'local_db_service.dart';

class AppConfigService {
  AppConfigService._();

  static final AppConfigService instance = AppConfigService._();

  static const String defaultServerUrl = 'http://127.0.0.1/syswatch_api';

  Future<void> init() async {
    var workstationId = await LocalDbService.instance.getConfig('workstationId');

    if (workstationId == null || workstationId.trim().isEmpty) {
      final randomId = const Uuid()
          .v4()
          .replaceAll('-', '')
          .toUpperCase()
          .substring(0, 20);

      workstationId = 'WS-$randomId';
      await LocalDbService.instance.setConfig('workstationId', workstationId);
    }

    var token = await LocalDbService.instance.getConfig('workstationToken');
    if (token == null || token.trim().isEmpty) {
      token = '${const Uuid().v4()}${const Uuid().v4()}'.replaceAll('-', '');
      await LocalDbService.instance.setConfig('workstationToken', token);
    }

    final serverUrl = await LocalDbService.instance.getConfig('serverUrl');
    if (serverUrl == null || serverUrl.trim().isEmpty) {
      await LocalDbService.instance.setConfig('serverUrl', defaultServerUrl);
    }
  }

  Future<PcIdentity> getPcIdentity() async {
    final workstationId = await LocalDbService.instance.getConfig(
      'workstationId',
    );
    final room = await LocalDbService.instance.getConfig('roomName') ?? '';
    final pc = await LocalDbService.instance.getConfig('pcId') ?? '';

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
      throw StateError('The permanent workstation ID cannot be changed.');
    }

    if (identity.roomName.trim().isEmpty || identity.pcId.trim().isEmpty) {
      throw ArgumentError('Room name and PC ID are required.');
    }

    final locationChanged =
        current.roomName.trim() != identity.roomName.trim() ||
        current.pcId.trim() != identity.pcId.trim();

    await LocalDbService.instance.setConfig(
      'roomName',
      identity.roomName.trim(),
    );
    await LocalDbService.instance.setConfig('pcId', identity.pcId.trim());

    if (locationChanged) {
      await setRegistrationConfirmed(false);
    }
  }

  Future<String> getServerUrl() async {
    final value = await LocalDbService.instance.getConfig('serverUrl');
    if (value == null || value.trim().isEmpty) {
      return defaultServerUrl;
    }
    return normalizeServerUrl(value);
  }

  Future<void> saveServerUrl(String value) async {
    final normalized = normalizeServerUrl(value);
    final uri = Uri.tryParse(normalized);

    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.trim().isEmpty) {
      throw ArgumentError(
        'Enter a valid server URL, for example '
        'http://192.168.1.10/syswatch_api.',
      );
    }

    final existing = await LocalDbService.instance.getConfig('serverUrl');
    final existingNormalized = existing == null || existing.trim().isEmpty
        ? ''
        : normalizeServerUrl(existing);

    await LocalDbService.instance.setConfig('serverUrl', normalized);

    if (existingNormalized.isNotEmpty && existingNormalized != normalized) {
      await setRegistrationConfirmed(false);
      await clearStudentApiSession();
    }
  }

  String normalizeServerUrl(String value) {
    var result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  Future<String> getWorkstationToken() async {
    var token = await LocalDbService.instance.getConfig('workstationToken');
    if (token == null || token.trim().isEmpty) {
      await init();
      token = await LocalDbService.instance.getConfig('workstationToken');
    }
    return token ?? '';
  }

  Future<void> setRegistrationConfirmed(bool value) async {
    await LocalDbService.instance.setConfig(
      'workstationRegistered',
      value ? 'true' : 'false',
    );
  }

  Future<bool> isRegistrationConfirmed() async {
    return await LocalDbService.instance.getConfig('workstationRegistered') ==
        'true';
  }

  Future<void> saveStudentApiSession({
    required AppUser user,
    required String apiToken,
    String? expiresAt,
  }) async {
    await LocalDbService.instance.setConfig('studentApiToken', apiToken);
    await LocalDbService.instance.setConfig('studentTokenUid', user.uid);
    await LocalDbService.instance.setConfig(
      'studentTokenExpiresAt',
      expiresAt ?? '',
    );
  }

  Future<String> getStudentApiToken() async {
    final token = await LocalDbService.instance.getConfig('studentApiToken');
    if (token == null || token.trim().isEmpty) return '';

    final expiry = await getStudentTokenExpiresAt();
    if (expiry != null && !expiry.isAfter(DateTime.now().toUtc())) {
      await clearStudentApiSession();
      return '';
    }
    return token;
  }

  Future<String> getStudentTokenUid() async {
    return await LocalDbService.instance.getConfig('studentTokenUid') ?? '';
  }

  Future<DateTime?> getStudentTokenExpiresAt() async {
    final value =
        await LocalDbService.instance.getConfig('studentTokenExpiresAt');
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  Future<bool> hasValidStudentApiSession({String? expectedUid}) async {
    final token = await getStudentApiToken();
    if (token.isEmpty) return false;
    if (expectedUid == null || expectedUid.trim().isEmpty) return true;
    return await getStudentTokenUid() == expectedUid;
  }

  Future<void> clearStudentApiSession() async {
    await LocalDbService.instance.setConfig('studentApiToken', '');
    await LocalDbService.instance.setConfig('studentTokenUid', '');
    await LocalDbService.instance.setConfig('studentTokenExpiresAt', '');
  }
}
