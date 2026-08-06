import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/issue_report.dart';
import '../../models/student_log.dart';
import '../../services/local_db_service.dart';
import '../../services/pc_identity_service.dart';
import '../../services/sync_service.dart';
import '../../services/theme_service.dart';
import '../../services/windows_hardware_service.dart';
import 'student_block_screen.dart';

class PeripheralFormScreen extends StatefulWidget {
  final String studentEmail;
  final String pcNumber;
  final String room;

  const PeripheralFormScreen({
    super.key,
    required this.studentEmail,
    required this.pcNumber,
    required this.room,
  });

  @override
  State<PeripheralFormScreen> createState() => _PeripheralFormScreenState();
}

class _PeripheralFormScreenState extends State<PeripheralFormScreen> {
  final _descriptionController = TextEditingController();
  final _uuid = const Uuid();

  bool _checking = true;
  bool _submitting = false;
  bool mouseOk = true;
  bool keyboardOk = true;
  bool monitorOk = true;
  bool networkOk = true;
  List<String> _warnings = const [];
  List<String> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _runAutomaticCheck();
  }

  Future<void> _runAutomaticCheck() async {
    setState(() => _checking = true);
    final result = await WindowsHardwareService.checkHardware();
    if (!mounted) return;
    setState(() {
      mouseOk = result.mouseDetected;
      keyboardOk = result.keyboardDetected;
      monitorOk = result.monitorDetected;
      networkOk = result.networkDetected;
      _warnings = result.warnings;
      _checking = false;
    });
    await _loadSuggestions();
  }

  List<String> get _failedComponents {
    final result = <String>[];
    if (!mouseOk) result.add('mouse');
    if (!keyboardOk) result.add('keyboard');
    if (!monitorOk) result.add('monitor');
    if (!networkOk) result.add('network');
    return result;
  }

  Future<void> _loadSuggestions() async {
    final values = <String>[];
    for (final issue in _failedComponents) {
      values.addAll(await LocalDbService.instance.getSuggestions(issue));
    }
    if (mounted) setState(() => _suggestions = values);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final now = DateTime.now();
      final logId = _uuid.v4();
      final log = StudentLog(
        id: logId,
        studentEmail: widget.studentEmail,
        windowsUsername: PcIdentityService.getWindowsUsername(),
        pcNumber: widget.pcNumber,
        room: widget.room,
        loginTime: now,
      );
      await LocalDbService.instance.insertStudentLog(log.toLocalMap());

      if (_failedComponents.isNotEmpty) {
        final report = IssueReport(
          id: _uuid.v4(),
          studentEmail: widget.studentEmail,
          pcNumber: widget.pcNumber,
          room: widget.room,
          issueType: _failedComponents.join(', '),
          description: _descriptionController.text.trim().isEmpty
              ? 'A problem was detected and confirmed during startup checking.'
              : _descriptionController.text.trim(),
          severity:
              _failedComponents.contains('network') ? 'High' : 'Minor',
          source: 'peripheral_confirmation_form',
          detectedBySystem: true,
          createdAt: now,
        );
        await LocalDbService.instance.insertIssueReport(report.toLocalMap());
      }

      await SyncService.instance.refreshPendingCount();
      await SyncService.instance.syncPendingData();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StudentBlockScreen(
            logId: logId,
            studentEmail: widget.studentEmail,
            pcNumber: widget.pcNumber,
            room: widget.room,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save the form: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _conditionTile(String name, bool value, ValueChanged<bool> changed) {
    return Card(
      child: SwitchListTile(
        title: Text(name),
        subtitle: Text(value ? 'Detected / working' : 'Problem detected'),
        secondary: Icon(value ? Icons.check_circle : Icons.warning),
        value: value,
        onChanged: (newValue) async {
          setState(() => changed(newValue));
          await _loadSuggestions();
        },
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peripheral Confirmation'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Run hardware check again',
            onPressed: _checking ? null : _runAutomaticCheck,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          _checking
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 14),
                      Text('Checking Windows devices and Event Viewer...'),
                    ],
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          widget.studentEmail,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text('PC ${widget.pcNumber} • Room ${widget.room}'),
                        const SizedBox(height: 12),
                        const Text(
                          'The system filled these values automatically. Double-check the devices you can physically confirm before submitting.',
                        ),
                        const SizedBox(height: 12),
                        _conditionTile('Mouse', mouseOk, (v) => mouseOk = v),
                        _conditionTile('Keyboard', keyboardOk, (v) => keyboardOk = v),
                        _conditionTile('Monitor', monitorOk, (v) => monitorOk = v),
                        _conditionTile(
                          'Ethernet / LAN connection',
                          networkOk,
                          (v) => networkOk = v,
                        ),
                        if (_suggestions.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Suggested checks',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          ..._suggestions.map(
                            (tip) => ListTile(
                              leading: const Icon(Icons.tips_and_updates),
                              title: Text(tip),
                            ),
                          ),
                        ],
                        if (_warnings.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Card(
                            child: ListTile(
                              leading: Icon(Icons.health_and_safety),
                              title: Text('System health checked automatically'),
                              subtitle: Text(
                                'CPU, RAM, and disk health are recorded for ITSO monitoring and do not need student confirmation.',
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        TextField(
                          controller: _descriptionController,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Additional issue description',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: const Icon(Icons.save),
                          label: Text(
                            _submitting ? 'Saving...' : 'Submit and Continue',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          Positioned(
            bottom: 24,
            right: 24,
            child: _buildThemeToggle(context),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: () => ThemeService.instance.toggleTheme(),
        icon: Icon(
          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          color: isDark ? Colors.amber : Colors.blue,
        ),
        tooltip: 'Toggle Light/Dark Mode',
      ),
    );
  }
}
