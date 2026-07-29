import 'package:flutter/material.dart';

import '../services/app_config_service.dart';
import '../widgets/simple_app_bar.dart';

class PcConfigScreen extends StatefulWidget {
  const PcConfigScreen({super.key});

  @override
  State<PcConfigScreen> createState() => _PcConfigScreenState();
}

class _PcConfigScreenState extends State<PcConfigScreen> {
  final roomController = TextEditingController();
  final pcController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    roomController.dispose();
    pcController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final pc = await AppConfigService.instance.getPcIdentity();

    roomController.text = pc.roomName;
    pcController.text = pc.pcId;
  }

  Future<void> _save() async {
    final current = await AppConfigService.instance.getPcIdentity();
    final identity = current.copyWith(
      roomName: roomController.text.trim(),
      pcId: pcController.text.trim(),
    );

    await AppConfigService.instance.savePcIdentity(identity);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PC configuration saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: simpleAppBar('PC Configuration'),
      body: Center(
        child: SizedBox(
          width: 430,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings, size: 60),
                  const SizedBox(height: 16),
                  const Text(
                    'Workstation Identity',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: roomController,
                    decoration: const InputDecoration(
                      labelText: 'Room Name',
                      hintText: 'Lab 1',
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
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Configuration'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
