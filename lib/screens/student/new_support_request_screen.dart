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

  // ── Palette (matches StartupScreen) ────────────────────────────────────────
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor =>
      _isDarkMode ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
  Color get _cardColor =>
      _isDarkMode ? const Color(0xFF13141A) : Colors.white;
  Color get _fieldFill =>
      _isDarkMode ? const Color(0xFF0D0F14) : const Color(0xFFF6F7F9);
  Color get _accentA => const Color(0xFF2EE6C5);
  Color get _accentB => const Color(0xFF4F8EF7);
  Color get _border =>
      _isDarkMode ? const Color(0x12FFFFFF) : Colors.black.withOpacity(0.09);
  Color get _fieldBorder =>
      _isDarkMode ? const Color(0x1AFFFFFF) : Colors.black.withOpacity(0.12);
  Color get _textPrimary => _isDarkMode ? Colors.white : Colors.black87;
  Color get _textSecondary =>
      _isDarkMode ? const Color(0x99FFFFFF) : Colors.black54;

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
          backgroundColor: _isDarkMode ? const Color(0xFF1B1D24) : null,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          _buildAmbientOrbs(),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: _buildCard(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientOrbs() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -90,
            left: -90,
            child: _orb(300, _accentA.withOpacity(0.06)),
          ),
          Positioned(
            bottom: -110,
            right: -70,
            child: _orb(340, _accentB.withOpacity(0.05)),
          ),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(Icons.arrow_back_rounded, color: _textPrimary),
          ),
          const SizedBox(width: 4),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [_accentA, _accentB],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds),
            child: const Text(
              'Report Issue',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => ThemeService.instance.toggleTheme(),
            icon: Icon(
              _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: _textSecondary,
            ),
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 32, 30, 28),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 56,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderIcon(),
            const SizedBox(height: 18),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [_accentA, _accentB],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(bounds),
              child: const Text(
                'How can ITSO help?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You can ask for help even when Syswatch has not '
                  'detected a PC issue.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),

            _fieldLabel('Category'),
            const SizedBox(height: 8),
            _buildStyledDropdown<String>(
              value: _category,
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
            const SizedBox(height: 18),

            _fieldLabel('Link an active PC issue (optional)'),
            const SizedBox(height: 8),
            if (_loadingIssues)
              _buildLoadingBar()
            else ...[
              _buildStyledDropdown<String>(
                value: _faultReportId ?? _noIssueValue,
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
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  _issueError ??
                      'Leave this blank for a general support request.',
                  style: TextStyle(
                    color: _issueError != null
                        ? const Color(0xFFFF6B6B)
                        : _textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),

            _fieldLabel('Subject'),
            const SizedBox(height: 8),
            _buildStyledTextField(
              controller: _subjectController,
              enabled: !_submitting,
              maxLength: 150,
              hintText: 'Example: Microsoft Word will not open',
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.length < 3) {
                  return 'Enter a subject with at least 3 characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            _fieldLabel('Message'),
            const SizedBox(height: 8),
            _buildStyledTextField(
              controller: _messageController,
              enabled: !_submitting,
              minLines: 5,
              maxLines: 10,
              maxLength: 4000,
              hintText: 'Describe what happened and what help you need.',
              validator: (value) =>
              (value ?? '').trim().isEmpty ? 'Enter a message.' : null,
            ),
            const SizedBox(height: 8),

            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIcon() {
    return Center(
      child: SizedBox(
        width: 84,
        height: 84,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _accentA.withOpacity(0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accentA.withOpacity(0.22),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _accentA.withOpacity(0.14),
                    _accentB.withOpacity(0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: _accentA.withOpacity(0.5), width: 1.5),
              ),
              child: ShaderMask(
                shaderCallback: (b) => LinearGradient(
                  colors: [_accentA, _accentB],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(b),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: _textSecondary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  InputDecoration _decoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: _textSecondary.withOpacity(0.6)),
      filled: true,
      fillColor: _fieldFill,
      counterStyle: TextStyle(color: _textSecondary.withOpacity(0.6), fontSize: 11),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _fieldBorder),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _fieldBorder.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _accentA.withOpacity(0.8), width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.6),
      ),
      errorStyle: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required bool enabled,
    required String hintText,
    int? maxLength,
    int minLines = 1,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      style: TextStyle(color: _textPrimary, fontSize: 14),
      cursorColor: _accentA,
      decoration: _decoration(hintText: hintText),
      validator: validator,
    );
  }

  Widget _buildStyledDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      dropdownColor: _cardColor,
      iconEnabledColor: _accentA,
      style: TextStyle(color: _textPrimary, fontSize: 14),
      decoration: _decoration(),
    );
  }

  Widget _buildLoadingBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 5,
        width: double.infinity,
        child: LinearProgressIndicator(
          backgroundColor:
          _isDarkMode ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05),
          valueColor: AlwaysStoppedAnimation<Color>(_accentA),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final disabled = _submitting;
    return Opacity(
      opacity: disabled ? 0.7 : 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: disabled ? null : _submit,
            child: Ink(
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_accentA, _accentB]),
                boxShadow: [
                  BoxShadow(
                    color: _accentA.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: _submitting
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Report Issue',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
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