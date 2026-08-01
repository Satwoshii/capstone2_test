import '../models/pc_identity.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'app_config_service.dart';

class DuplicateWorkstationLocationException implements Exception {
  final String workstationId;

  const DuplicateWorkstationLocationException(this.workstationId);

  @override
  String toString() {
    if (workstationId.trim().isEmpty) {
      return 'This room and PC ID are already assigned to another workstation.';
    }
    return 'This room and PC ID are already assigned to $workstationId.';
  }
}

class WorkstationRegistryService {
  WorkstationRegistryService._();

  static final WorkstationRegistryService instance =
      WorkstationRegistryService._();

  Future<void> registerOrUpdate(PcIdentity identity) async {
    if (!identity.isConfigured) {
      throw ArgumentError('Room name and PC ID are required.');
    }

    try {
      await ApiClient.instance.postJson(
        ApiEndpoints.registerWorkstation,
        body: {
          'workstation_id': identity.workstationId,
          'room_name': identity.roomName,
          'pc_id': identity.pcId,
          'workstation_token':
              await AppConfigService.instance.getWorkstationToken(),
        },
      );
    } on ApiRequestException catch (error) {
      if (error.statusCode == 409 || error.code == 'duplicate_assignment') {
        final assignedTo = error.response?['assigned_to']?.toString() ?? '';
        throw DuplicateWorkstationLocationException(assignedTo);
      }
      rethrow;
    }
  }

  Future<void> updateHeartbeat(
    PcIdentity identity,
    String status,
  ) async {
    if (!identity.isConfigured) return;

    await ApiClient.instance.postJson(
      ApiEndpoints.workstationHeartbeat,
      body: {
        'workstation_id': identity.workstationId,
        'room_name': identity.roomName,
        'pc_id': identity.pcId,
        'status': status,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }
}
