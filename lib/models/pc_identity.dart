class PcIdentity {
  final String workstationId;
  final String roomName;
  final String pcId;

  const PcIdentity({
    required this.workstationId,
    required this.roomName,
    required this.pcId,
  });

  bool get isConfigured {
    return roomName.trim().isNotEmpty && pcId.trim().isNotEmpty;
  }

  String get locationLabel {
    if (!isConfigured) return 'Location not assigned';
    return '$roomName - $pcId';
  }

  PcIdentity copyWith({
    String? roomName,
    String? pcId,
  }) {
    return PcIdentity(
      workstationId: workstationId,
      roomName: roomName ?? this.roomName,
      pcId: pcId ?? this.pcId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workstationId': workstationId,
      'roomName': roomName,
      'pcId': pcId,
    };
  }
}