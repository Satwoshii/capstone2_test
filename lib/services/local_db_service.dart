import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/pc_identity.dart';

class LocalDbService {
  LocalDbService._();

  static final LocalDbService instance = LocalDbService._();

  Database? _db;

  Database get db {
    final database = _db;
    if (database == null) {
      throw Exception('Database not initialized');
    }
    return database;
  }

  Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = path.join(directory.path, 'hybrid_pc_monitoring.db');

    _db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        uid TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        displayName TEXT NOT NULL,
        role TEXT NOT NULL,
        studentId TEXT,
        passwordHash TEXT,
        active INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE config (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE login_logs (
        id TEXT PRIMARY KEY,
        uid TEXT,
        studentId TEXT,
        email TEXT,
        displayName TEXT,
        role TEXT,
        workstationId TEXT,
        roomName TEXT,
        pcId TEXT,
        loginTime TEXT,
        logoutTime TEXT,
        status TEXT,
        synced INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE fault_reports (
        id TEXT PRIMARY KEY,
        workstationId TEXT,
        roomName TEXT,
        pcId TEXT,
        studentEmail TEXT,
        issue TEXT,
        details TEXT,
        severity TEXT,
        source TEXT,
        detectedBySystem INTEGER,
        createdAt TEXT,
        repaired INTEGER NOT NULL,
        repairedAt TEXT,
        technicianNotes TEXT,
        synced INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE maintenance_logs (
        id TEXT PRIMARY KEY,
        faultReportId TEXT,
        workstationId TEXT,
        roomName TEXT,
        pcId TEXT,
        technicianName TEXT,
        notes TEXT,
        repairDate TEXT,
        synced INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pc_status (
        id TEXT PRIMARY KEY,
        workstationId TEXT,
        roomName TEXT,
        pcId TEXT,
        status TEXT,
        lastCheck TEXT,
        lastStudentEmail TEXT,
        details TEXT,
        synced INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_chat_messages (
        id TEXT PRIMARY KEY,
        conversationId INTEGER NOT NULL,
        faultReportId TEXT NOT NULL,
        senderUserUid TEXT NOT NULL,
        message TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pending_chat_synced '
      'ON pending_chat_messages(synced)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pending_chat_conversation '
      'ON pending_chat_messages(conversationId, createdAt)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_users_student_id ON users(studentId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_login_logs_synced ON login_logs(synced)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_fault_reports_synced ON fault_reports(synced)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_maintenance_logs_synced ON maintenance_logs(synced)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pc_status_synced ON pc_status(synced)',
    );
  }

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _addColumnIfMissing(db, 'login_logs', 'workstationId TEXT');
      await _addColumnIfMissing(db, 'fault_reports', 'workstationId TEXT');
      await _addColumnIfMissing(db, 'maintenance_logs', 'workstationId TEXT');
      await _addColumnIfMissing(db, 'pc_status', 'workstationId TEXT');
      await _addColumnIfMissing(db, 'pc_status', 'lastStudentEmail TEXT');
    }

    // Version 3 switches the application to the intranet API. No schema migration is
    // required because the intranet server settings are stored in config.
    if (oldVersion < 3) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_users_student_id ON users(studentId)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_login_logs_synced ON login_logs(synced)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_fault_reports_synced ON fault_reports(synced)',
      );
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_chat_messages (
          id TEXT PRIMARY KEY,
          conversationId INTEGER NOT NULL,
          faultReportId TEXT NOT NULL,
          senderUserUid TEXT NOT NULL,
          message TEXT NOT NULL,
          createdAt TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_pending_chat_synced '
        'ON pending_chat_messages(synced)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_pending_chat_conversation '
        'ON pending_chat_messages(conversationId, createdAt)',
      );
    }
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String columnDefinition,
  ) async {
    final columnName = columnDefinition.split(' ').first;
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any(
      (column) => column['name']?.toString() == columnName,
    );

    if (!exists) {
      await db.execute(
        'ALTER TABLE $table ADD COLUMN $columnDefinition',
      );
    }
  }

  Future<void> setConfig(String key, String value) async {
    await db.insert(
      'config',
      {
        'key': key,
        'value': value,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getConfig(String key) async {
    final result = await db.query(
      'config',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return result.first['value'] as String;
  }

  Future<void> upsertUser(AppUser user) async {
    await db.insert(
      'users',
      user.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertUsers(Iterable<AppUser> users) async {
    final batch = db.batch();
    for (final user in users) {
      batch.insert(
        'users',
        user.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> countCachedStudents() async {
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM users WHERE role = 'student' AND active = 1",
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<AppUser?> findUserByStudentId(String studentId) async {
    final result = await db.query(
      'users',
      where: 'UPPER(studentId) = UPPER(?) AND active = 1',
      whereArgs: [studentId],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return AppUser.fromLocalMap(result.first);
  }

  Future<String> insertLoginLog({
    required AppUser user,
    required PcIdentity pc,
  }) async {
    final id = const Uuid().v4();

    await db.insert('login_logs', {
      'id': id,
      'uid': user.uid,
      'studentId': user.studentId,
      'email': user.email,
      'displayName': user.displayName,
      'role': user.role,
      'workstationId': pc.workstationId,
      'roomName': pc.roomName,
      'pcId': pc.pcId,
      'loginTime': DateTime.now().toIso8601String(),
      'logoutTime': null,
      'status': 'logged_in',
      'synced': 0,
    });

    return id;
  }

  Future<void> insertStudentLog(Map<String, dynamic> data) async {
    final loginTimeValue = data['loginTime'];
    final loginTime = loginTimeValue is DateTime
        ? loginTimeValue.toIso8601String()
        : loginTimeValue?.toString() ?? DateTime.now().toIso8601String();
    final workstationId =
        data['workstationId'] ?? await getConfig('workstationId');

    await db.insert(
      'login_logs',
      {
        'id': data['id'] ?? const Uuid().v4(),
        'uid': data['uid'],
        'studentId': data['studentId'],
        'email': data['studentEmail'] ?? data['email'],
        'displayName': data['displayName'] ?? data['studentEmail'] ?? '',
        'role': data['role'] ?? 'student',
        'workstationId': workstationId,
        'roomName': data['room'] ?? data['roomName'],
        'pcId': data['pcNumber'] ?? data['pcId'],
        'loginTime': loginTime,
        'logoutTime': data['logoutTime']?.toString(),
        'status': data['status'] ?? 'logged_in',
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> logout(String loginLogId) async {
    await markStudentSessionEnded(loginLogId);
  }

  Future<void> markStudentSessionEnded(String logId) async {
    await db.update(
      'login_logs',
      {
        'logoutTime': DateTime.now().toIso8601String(),
        'status': 'logged_out',
        'synced': 0,
      },
      where: 'id = ?',
      whereArgs: [logId],
    );
  }

  Future<String> insertFaultReport({
    required PcIdentity pc,
    required String issue,
    required String details,
    String? studentEmail,
    String severity = 'medium',
    String source = 'background_pc_monitor',
    bool recovered = false,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toIso8601String();

    await db.insert('fault_reports', {
      'id': id,
      'workstationId': pc.workstationId,
      'roomName': pc.roomName,
      'pcId': pc.pcId,
      'studentEmail': studentEmail,
      'issue': issue,
      'details': details,
      'severity': severity,
      'source': source,
      'detectedBySystem': 1,
      'createdAt': now,
      'repaired': recovered ? 1 : 0,
      'repairedAt': recovered ? now : null,
      'technicianNotes': recovered ? 'Automatically detected recovery.' : null,
      'synced': 0,
    });

    return id;
  }

  Future<void> insertIssueReport(Map<String, dynamic> data) async {
    final createdAtValue = data['createdAt'];
    final createdAt = createdAtValue is DateTime
        ? createdAtValue.toIso8601String()
        : createdAtValue?.toString() ?? DateTime.now().toIso8601String();
    final workstationId =
        data['workstationId'] ?? await getConfig('workstationId');

    await db.insert(
      'fault_reports',
      {
        'id': data['id'] ?? const Uuid().v4(),
        'workstationId': workstationId,
        'roomName': data['room'] ?? data['roomName'],
        'pcId': data['pcNumber'] ?? data['pcId'],
        'studentEmail': data['studentEmail'],
        'issue': data['issueType'] ?? data['issue'],
        'details': data['description'] ?? data['details'],
        'severity': data['severity'] ?? 'medium',
        'source': data['source'] ?? 'manual_report',
        'detectedBySystem': data['detectedBySystem'] == true ||
            data['detectedBySystem'] == 1
            ? 1
            : 0,
        'createdAt': createdAt,
        'repaired': 0,
        'repairedAt': null,
        'technicianNotes': null,
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> hasOpenAutomaticFault({
    required PcIdentity pc,
    required String issue,
  }) async {
    final rows = await db.query(
      'fault_reports',
      columns: ['id'],
      where: '''
        roomName = ? AND
        pcId = ? AND
        issue = ? AND
        source = ? AND
        repaired = 0
      ''',
      whereArgs: [
        pc.roomName,
        pc.pcId,
        issue,
        'background_pc_monitor',
      ],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<String>> getOpenAutomaticFaultIssues(PcIdentity pc) async {
    final rows = await db.query(
      'fault_reports',
      distinct: true,
      columns: ['issue'],
      where: '''
        roomName = ? AND
        pcId = ? AND
        source = ? AND
        repaired = 0
      ''',
      whereArgs: [
        pc.roomName,
        pc.pcId,
        'background_pc_monitor',
      ],
    );

    return rows
        .map((row) => row['issue']?.toString() ?? '')
        .where((issue) => issue.isNotEmpty)
        .toList();
  }

  Future<void> markAutomaticFaultRecovered({
    required PcIdentity pc,
    required String issue,
  }) async {
    final now = DateTime.now().toIso8601String();

    await db.update(
      'fault_reports',
      {
        'repaired': 1,
        'repairedAt': now,
        'technicianNotes': 'Automatically detected recovery.',
        'synced': 0,
      },
      where: '''
        roomName = ? AND
        pcId = ? AND
        issue = ? AND
        source = ? AND
        repaired = 0
      ''',
      whereArgs: [
        pc.roomName,
        pc.pcId,
        issue,
        'background_pc_monitor',
      ],
    );
  }

  Future<void> markFaultRepaired({
    required String reportId,
    required String technicianName,
    required String notes,
  }) async {
    final reports = await db.query(
      'fault_reports',
      where: 'id = ?',
      whereArgs: [reportId],
      limit: 1,
    );

    if (reports.isEmpty) return;

    final report = reports.first;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'fault_reports',
      {
        'repaired': 1,
        'repairedAt': now,
        'technicianNotes': notes,
        'synced': 0,
      },
      where: 'id = ?',
      whereArgs: [reportId],
    );

    await db.insert('maintenance_logs', {
      'id': const Uuid().v4(),
      'faultReportId': reportId,
      'workstationId': report['workstationId'],
      'roomName': report['roomName'],
      'pcId': report['pcId'],
      'technicianName': technicianName,
      'notes': notes,
      'repairDate': now,
      'synced': 0,
    });
  }

  Future<void> upsertPcStatus({
    required PcIdentity pc,
    required String status,
    required String details,
    String? lastStudentEmail,
  }) async {
    final id = pc.workstationId;

    await db.insert(
      'pc_status',
      {
        'id': id,
        'workstationId': pc.workstationId,
        'roomName': pc.roomName,
        'pcId': pc.pcId,
        'status': status,
        'lastCheck': DateTime.now().toIso8601String(),
        'lastStudentEmail': lastStudentEmail,
        'details': details,
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String> getCurrentPcStatus(String workstationId) async {
    final matchingRows = await db.query(
      'pc_status',
      columns: ['status'],
      where: 'workstationId = ? OR id = ?',
      whereArgs: [workstationId, workstationId],
      orderBy: 'lastCheck DESC',
      limit: 1,
    );

    if (matchingRows.isNotEmpty) {
      return matchingRows.first['status']?.toString() ?? 'online';
    }

    // Supports status rows written before database version 2.
    final latestRows = await db.query(
      'pc_status',
      columns: ['status'],
      orderBy: 'lastCheck DESC',
      limit: 1,
    );

    if (latestRows.isEmpty) return 'online';
    return latestRows.first['status']?.toString() ?? 'online';
  }

  Future<List<String>> getSuggestions(String issueType) async {
    final issue = issueType.toLowerCase();

    if (issue.contains('mouse')) {
      return [
        'Check if the mouse USB cable is properly connected.',
        'Try using another USB port.',
        'Restart the workstation if the mouse is still not detected.',
      ];
    }

    if (issue.contains('keyboard')) {
      return [
        'Check if the keyboard cable is properly connected.',
        'Try another USB port.',
        'Check if Num Lock or Caps Lock indicator responds.',
      ];
    }

    if (issue.contains('monitor')) {
      return [
        'Check if the monitor power cable is connected.',
        'Check the HDMI/VGA cable.',
        'Make sure the monitor is turned on.',
      ];
    }

    if (issue.contains('network') || issue.contains('ethernet')) {
      return [
        'Check if the Ethernet/LAN cable is properly connected.',
        'Check if the Ethernet port light is blinking.',
        'Report to ITSO if the LAN cable or port is damaged.',
      ];
    }

    if (issue.contains('storage') || issue.contains('disk')) {
      return [
        'Do not continue using the workstation if disk failure is detected.',
        'Report the issue to ITSO immediately.',
        'Backup important data if accessible.',
      ];
    }

    if (issue.contains('cpu') || issue.contains('ram')) {
      return [
        'This is a system health issue and should be handled by ITSO.',
        'Restart the workstation only if instructed by ITSO.',
        'Use another workstation if the issue continues.',
      ];
    }

    return [
      'Double-check the device connection.',
      'Restart the workstation if the issue continues.',
      'Report the issue to ITSO.',
    ];
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRows(String table) async {
    return db.query(
      table,
      where: 'synced = ?',
      whereArgs: [0],
    );
  }

  Future<void> markSynced(String table, String id) async {
    await db.update(
      table,
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getFaultReports() {
    return db.query('fault_reports', orderBy: 'createdAt DESC');
  }

  Future<List<Map<String, dynamic>>> getLoginLogs() {
    return db.query('login_logs', orderBy: 'loginTime DESC');
  }

  Future<List<Map<String, dynamic>>> getPcStatuses() {
    return db.query('pc_status', orderBy: 'lastCheck DESC');
  }

  Future<List<Map<String, dynamic>>> getOpenFaultReports() {
    return db.query(
      'fault_reports',
      where: 'repaired = ?',
      whereArgs: [0],
      orderBy: 'createdAt DESC',
    );
  }

  Future<String> insertPendingChatMessage({
    required int conversationId,
    required String faultReportId,
    required String senderUserUid,
    required String message,
  }) async {
    final id = const Uuid().v4();
    await db.insert(
      'pending_chat_messages',
      {
        'id': id,
        'conversationId': conversationId,
        'faultReportId': faultReportId,
        'senderUserUid': senderUserUid,
        'message': message.trim(),
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return id;
  }

  Future<List<Map<String, dynamic>>> getPendingChatMessages({
    int? conversationId,
    String? senderUserUid,
  }) async {
    final where = <String>[];
    final args = <Object?>[];

    where.add('synced = ?');
    args.add(0);
    if (conversationId != null) {
      where.add('conversationId = ?');
      args.add(conversationId);
    }
    if (senderUserUid != null && senderUserUid.trim().isNotEmpty) {
      where.add('senderUserUid = ?');
      args.add(senderUserUid);
    }

    return db.query(
      'pending_chat_messages',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'createdAt ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedChatMessages({
    required String senderUserUid,
  }) {
    return db.query(
      'pending_chat_messages',
      where: 'synced = ? AND senderUserUid = ?',
      whereArgs: [0, senderUserUid],
      orderBy: 'createdAt ASC',
    );
  }

  Future<void> deletePendingChatMessage(String id) async {
    await db.delete(
      'pending_chat_messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markChatMessageSynced(String id) async {
    await db.update(
      'pending_chat_messages',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteSyncedChatMessages() async {
    await db.delete(
      'pending_chat_messages',
      where: 'synced = ?',
      whereArgs: [1],
    );
  }

}
