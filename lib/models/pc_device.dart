class PcDevice {
  final String computerName;
  final String pcNumber;
  final String room;
  final String windowsDomain;
  final String status;

  const PcDevice({
    required this.computerName,
    required this.pcNumber,
    required this.room,
    required this.windowsDomain,
    this.status = 'active',
  });

  Map<String, dynamic> toMap() {
    return {
      'computerName': computerName,
      'pcNumber': pcNumber,
      'room': room,
      'windowsDomain': windowsDomain,
      'status': status,
    };
  }
}
