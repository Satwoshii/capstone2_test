import 'package:flutter/material.dart';

import '../../models/support_issue.dart';
import '../../services/support_chat_service.dart';
import '../../services/theme_service.dart';

class NewSupportRequestScreen extends StatefulWidget {
  const NewSupportRequestScreen({super.key});

  @override
  State<NewSupportRequestScreen> createState() =>
      _NewSupportRequestScreenState();
}

class _NewSupportRequestScreenState extends State<NewSupportRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  List<SupportIssue> _activeIssues = const [];
  String _category = 'general';
  String? _faultReportId;
  static const String _noIssueValue = '__no_issue__';
  bool _loadingIssues = true;
  bool _submitting = false;
  String? _issueError;

  static const _categories = <String, String>{
    'general': 'General Assistance',
    'hardware': 'Hardware',
    'peripheral': 'Peripheral',
    'network': 'Network',
    'software': 'Software',
    'account': 'Account or Login',
    'other': 'Other',
  };

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadIssues() async {
    try {
      final issues = await SupportChatService.instance.listActiveIssues();
      if (!mounted) return;
      setState(() {
        _activeIssues = issues;
        _loadingIssues = false;
        _issueError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingIssues = false;
        _issueError = error.toString().replaceFirst('Exception:', '').trim();
      });
    }
  }

  void _selectIssue(String? value) {
    final selectedValue = value == _noIssueValue ? null : value;
    setState(() {
      _faultReportId = selectedValue;
      if (selectedValue != null) {
        final issue = _activeIssues.firstWhere(
          (item) => item.faultReportId == selectedValue,
        );
        _category = _categoryForIssue(issue.issue);
        if (_subjectController.text.trim().isEmpty) {
          _subjectController.text = issue.issue;
        }
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final conversation =
          await SupportChatService.instance.createConversation(
        category: _category,
        subject: _subjectController.text,
        message: _messageController.text,
        faultReportId: _faultReportId,
      );
      if (!mounted) return;
      Navigator.pop(context, conversation);
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
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New ITSO Support Request'),
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'How can ITSO help?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You can ask for help even when Syswatch has not '
                        'detected a PC issue.',
                      ),
                      const SizedBox(height: 22),
                      DropdownButtonFormField<String>(
                        value: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final entry in _categories.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                        ],
                        onChanged: _submitting
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _category = value);
                                }
                              },
                      ),
                      const SizedBox(height: 16),
                      if (_loadingIssues)
                        const LinearProgressIndicator()
                      else
                        DropdownButtonFormField<String>(
                          value: _faultReportId ?? _noIssueValue,
                          decoration: InputDecoration(
                            labelText: 'Link an active PC issue (optional)',
                            border: const OutlineInputBorder(),
                            helperText: _issueError ??
                                'Leave this blank for a general support request.',
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: _noIssueValue,
                              child: Text('No linked issue'),
                            ),
                            for (final issue in _activeIssues)
                              DropdownMenuItem<String>(
                                value: issue.faultReportId,
                                child: Text(
                                  '${issue.issue} (${issue.severity})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: _submitting ? null : _selectIssue,
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _subjectController,
                        enabled: !_submitting,
                        maxLength: 150,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          hintText: 'Example: Microsoft Word will not open',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.length < 3) {
                            return 'Enter a subject with at least 3 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _messageController,
                        enabled: !_submitting,
                        minLines: 5,
                        maxLines: 10,
                        maxLength: 4000,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          hintText: 'Describe what happened and what help you need.',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter a message.'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                        label: const Text('Send Support Request'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _categoryForIssue(String issue) {
    final value = issue.toLowerCase();
    if (value.contains('ethernet') || value.contains('network')) {
      return 'network';
    }
    if (value.contains('keyboard') ||
        value.contains('mouse') ||
        value.contains('monitor')) {
      return 'peripheral';
    }
    if (value.contains('software') || value.contains('application')) {
      return 'software';
    }
    return 'hardware';
  }
}
