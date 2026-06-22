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
        version: 1,
        onCreate: _onCreate,
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
        roomName TEXT,
        pcId TEXT,
        status TEXT,
        lastCheck TEXT,
        details TEXT,
        synced INTEGER NOT NULL
      )
    ''');
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

  Future<AppUser?> findUserByStudentId(String studentId) async {
    final result = await db.query(
      'users',
      where: 'studentId = ? AND active = 1',
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

    await db.insert(
      'login_logs',
      {
        'id': data['id'] ?? const Uuid().v4(),
        'uid': data['uid'],
        'studentId': data['studentId'],
        'email': data['studentEmail'] ?? data['email'],
        'displayName': data['displayName'] ?? data['studentEmail'] ?? '',
        'role': data['role'] ?? 'student',
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
  }) async {
    final id = const Uuid().v4();

    await db.insert('fault_reports', {
      'id': id,
      'roomName': pc.roomName,
      'pcId': pc.pcId,
      'studentEmail': null,
      'issue': issue,
      'details': details,
      'severity': 'medium',
      'source': 'startup_hardware_check',
      'detectedBySystem': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'repaired': 0,
      'repairedAt': null,
      'technicianNotes': null,
      'synced': 0,
    });

    return id;
  }

  Future<void> insertIssueReport(Map<String, dynamic> data) async {
    final createdAtValue = data['createdAt'];
    final createdAt = createdAtValue is DateTime
        ? createdAtValue.toIso8601String()
        : createdAtValue?.toString() ?? DateTime.now().toIso8601String();

    await db.insert(
      'fault_reports',
      {
        'id': data['id'] ?? const Uuid().v4(),
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
  }) async {
    final id = '${pc.roomName}_${pc.pcId}'.replaceAll(' ', '_');

    await db.insert(
      'pc_status',
      {
        'id': id,
        'roomName': pc.roomName,
        'pcId': pc.pcId,
        'status': status,
        'lastCheck': DateTime.now().toIso8601String(),
        'details': details,
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
}