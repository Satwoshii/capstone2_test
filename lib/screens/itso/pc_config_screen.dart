import 'package:flutter/material.dart';

import '../../services/app_config_service.dart';
import '../../services/sync_service.dart';
import '../../services/theme_service.dart';
import '../../services/workstation_registry_service.dart';
import '../../widgets/simple_app_bar.dart';

class PcConfigScreen extends StatefulWidget {
  const PcConfigScreen({super.key});

  @override
  State<PcConfigScreen> createState() => _PcConfigScreenState();
}

class _PcConfigScreenState extends State<PcConfigScreen> {
  final serverUrlController = TextEditingController();
  final roomController = TextEditingController();
  final pcController = TextEditingController();
  final workstationIdController = TextEditingController();
  final tokenController = TextEditingController();

  bool loading = true;
  bool saving = false;
  String serverStatus = 'Not checked';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    serverUrlController.dispose();
    roomController.dispose();
    pcController.dispose();
    workstationIdController.dispose();
    tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final identity = await AppConfigService.instance.getPcIdentity();
    final serverUrl = await AppConfigService.instance.getServerUrl();
    final token = await AppConfigService.instance.getWorkstationToken();

    if (!mounted) return;
    setState(() {
      workstationIdController.text = identity.workstationId;
      roomController.text = identity.roomName;
      pcController.text = identity.pcId;
      serverUrlController.text = serverUrl;
      tokenController.text = token;
      loading = false;
    });
  }

  Future<void> _testServer() async {
    try {
      await AppConfigService.instance.saveServerUrl(serverUrlController.text);
      final online = await SyncService.instance.isServerReachable();
      if (!mounted) return;
      setState(() {
        serverStatus = online ? 'Server online' : 'Server unreachable';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => serverStatus = error.toString());
    }
  }

  Future<void> _saveAndRegister() async {
    if (saving) return;
    setState(() => saving = true);

    try {
      await AppConfigService.instance.saveServerUrl(serverUrlController.text);
      final current = await AppConfigService.instance.getPcIdentity();
      final identity = current.copyWith(
        roomName: roomController.text.trim(),
        pcId: pcController.text.trim(),
      );

      await WorkstationRegistryService.instance.registerOrUpdate(identity);
      await AppConfigService.instance.savePcIdentity(identity);
      await AppConfigService.instance.setRegistrationConfirmed(true);
      await SyncService.instance.syncPendingData();

      if (!mounted) return;
      setState(() => serverStatus = 'Registered and connected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workstation registered on the intranet server.'),
        ),
      );
    } on DuplicateWorkstationLocationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception:', '').trim(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PC Configuration'),
        actions: [
          IconButton(
            onPressed: () => ThemeService.instance.toggleTheme(),
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: 560,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lan, size: 60),
                          const SizedBox(height: 16),
                          const Text(
                            'Intranet Workstation Identity',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: serverUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Syswatch server URL',
                              hintText: 'http://192.168.1.10/syswatch_api',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Status: $serverStatus'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: saving ? null : _testServer,
                            icon: const Icon(Icons.wifi_tethering),
                            label: const Text('Test local server'),
                          ),
                          const Divider(height: 32),
                          TextField(
                            controller: workstationIdController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Permanent workstation ID',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: tokenController,
                            readOnly: true,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Workstation token',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: roomController,
                            decoration: const InputDecoration(
                              labelText: 'Room Name',
                              hintText: '706',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: pcController,
                            decoration: const InputDecoration(
                              labelText: 'PC ID',
                              hintText: 'PC-01',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: saving ? null : _saveAndRegister,
                              icon: const Icon(Icons.app_registration),
                              label: Text(
                                saving
                                    ? 'Registering...'
                                    : 'Save and Register Workstation',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
