import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';
import '../widgets/dashboard_card.dart';
import 'staff_portal_screen.dart';
import 'pc_config_screen.dart';

class ItsoDashboardScreen extends StatefulWidget {
  final AppUser user;

  const ItsoDashboardScreen({
    super.key,
    required this.user,
  });

  @override
  State<ItsoDashboardScreen> createState() => _ItsoDashboardScreenState();
}

class _ItsoDashboardScreenState extends State<ItsoDashboardScreen> {
  List<Map<String, dynamic>> faults = [];
  List<Map<String, dynamic>> logs = [];
  List<Map<String, dynamic>> pcs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final localFaults = await LocalDbService.instance.getFaultReports();
    final localLogs = await LocalDbService.instance.getLoginLogs();
    final localPcs = await LocalDbService.instance.getPcStatuses();

    if (!mounted) return;

    setState(() {
      faults = localFaults;
      logs = localLogs;
      pcs = localPcs;
    });
  }

  Future<void> _repair(Map<String, dynamic> report) async {
    final notesController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Mark as Repaired'),
          content: TextField(
            controller: notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Technician notes',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await LocalDbService.instance.markFaultRepaired(
      reportId: report['id'],
      technicianName: widget.user.displayName,
      notes: notesController.text.trim(),
    );

    await SyncService.instance.syncNow();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final onlineCount = pcs.where((pc) => pc['status'] == 'online').length;
    final brokenCount = pcs.where((pc) => pc['status'] == 'broken').length;
    final pendingRepairs =
        faults.where((fault) => fault['repaired'] == 0).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ITSO Dashboard'),
        actions: [
          IconButton(
            tooltip: 'PC Configuration',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PcConfigScreen()),
              );
            },
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () async {
              await SyncService.instance.syncNow();
              await _load();
            },
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const StaffPortalScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                DashboardCard(
                  title: 'Online PCs',
                  value: onlineCount.toString(),
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
                DashboardCard(
                  title: 'Broken PCs',
                  value: brokenCount.toString(),
                  icon: Icons.warning,
                  color: Colors.red,
                ),
                DashboardCard(
                  title: 'Pending Repairs',
                  value: pendingRepairs.toString(),
                  icon: Icons.build,
                  color: Colors.orange,
                ),
                DashboardCard(
                  title: 'Login Logs',
                  value: logs.length.toString(),
                  icon: Icons.history,
                  color: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              'Fault Reports',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (faults.isEmpty)
              const Card(
                child: ListTile(
                  title: Text('No fault reports yet.'),
                ),
              ),
            ...faults.map((report) {
              final repaired = report['repaired'] == 1;

              return Card(
                child: ListTile(
                  leading: Icon(
                    repaired ? Icons.check_circle : Icons.warning,
                    color: repaired ? Colors.green : Colors.red,
                  ),
                  title: Text('${report['roomName']} - ${report['pcId']}'),
                  subtitle: Text(
                    '${report['issue']}\n${report['details']}\n${report['createdAt']}',
                  ),
                  isThreeLine: true,
                  trailing: repaired
                      ? const Text('Repaired')
                      : ElevatedButton(
                          onPressed: () => _repair(report),
                          child: const Text('Mark Repaired'),
                        ),
                ),
              );
            }),
            const SizedBox(height: 28),
            const Text(
              'Recent Login Logs',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (logs.isEmpty)
              const Card(
                child: ListTile(
                  title: Text('No login logs yet.'),
                ),
              ),
            ...logs.take(20).map((log) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(log['displayName'] ?? log['email'] ?? ''),
                  subtitle: Text(
                    '${log['studentId'] ?? ''}\n${log['roomName']} - ${log['pcId']}',
                  ),
                  trailing: Text(log['status'] ?? ''),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
