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

class _NewSupportRequestScreenState extends State<NewSupportRequestScreen>
    with SingleTickerProviderStateMixin {

  final _formKey           = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  List<SupportIssue> _activeIssues = const [];
  String  _category      = 'general';
  String? _faultReportId;
  bool    _loadingIssues = true;
  bool    _submitting    = false;
  String? _issueError;

  static const String _noIssueValue = '__no_issue__';

  static const _categories = <String, (String, IconData)>{
    'general':    ('General',    Icons.help_outline_rounded),
    'hardware':   ('Hardware',   Icons.memory_rounded),
    'peripheral': ('Peripheral', Icons.mouse_rounded),
    'network':    ('Network',    Icons.wifi_rounded),
    'software':   ('Software',   Icons.apps_rounded),
    'account':    ('Account',    Icons.manage_accounts_rounded),
    'other':      ('Other',      Icons.more_horiz_rounded),
  };

  late final AnimationController _entryCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgColor    => _dark ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
  Color get _cardColor  => _dark ? const Color(0xFF13141A) : Colors.white;
  Color get _fieldColor => _dark ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);
  Color get _textColor  => _dark ? Colors.white : const Color(0xFF1A1C1E);
  Color get _hintColor  => _dark ? Colors.white38 : Colors.black38;
  Color get _borderCol  => _dark ? const Color(0x12FFFFFF) : Colors.black.withValues(alpha: 0.09);

  static const Color _accentA = Color(0xFF2EE6C5);
  static const Color _accentB = Color(0xFF4F8EF7);

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();
    _loadIssues();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadIssues() async {
    try {
      final issues = await SupportChatService.instance.listActiveIssues();
      if (!mounted) return;
      setState(() { _activeIssues = issues; _loadingIssues = false; _issueError = null; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loadingIssues = false; _issueError = error.toString().replaceFirst('Exception:', '').trim(); });
    }
  }

  void _selectIssue(String? value) {
    final selected = value == _noIssueValue ? null : value;
    setState(() {
      _faultReportId = selected;
      if (selected != null) {
        final issue = _activeIssues.firstWhere((i) => i.faultReportId == selected);
        _category = _categoryForIssue(issue.issue);
        if (_subjectController.text.trim().isEmpty) _subjectController.text = issue.issue;
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final conversation = await SupportChatService.instance.createConversation(
        category: _category, subject: _subjectController.text,
        message: _messageController.text, faultReportId: _faultReportId,
      );
      if (!mounted) return;
      Navigator.pop(context, conversation);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.toString().replaceFirst('Exception:', '').trim()),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          _buildAmbientOrbs(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(position: _slideAnim, child: _buildCard()),
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            right: 24,
            child: _buildCircularThemeToggle(),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularThemeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        shape: BoxShape.circle,
        border: Border.all(color: _borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_dark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: () => ThemeService.instance.toggleTheme(),
        icon: Icon(
          _dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          color: _dark ? Colors.amber : _accentB,
        ),
        tooltip: 'Toggle Light/Dark Mode',
      ),
    );
  }

  Widget _buildAmbientOrbs() {
    return IgnorePointer(
      child: Stack(children: [
        Positioned(top: -80,    left:  -80, child: _orb(300, _accentA.withOpacity(0.07))),
        Positioned(bottom:-100, right: -60, child: _orb(340, _accentB.withOpacity(0.06))),
      ]),
    );
  }

  Widget _orb(double size, Color color) => Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent])));

  Widget _buildCard() {
    return Container(
      width: 640,
      padding: const EdgeInsets.fromLTRB(40, 44, 40, 40),
      decoration: BoxDecoration(
        color: _cardColor, borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderCol),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(_dark ? 0.55 : 0.10), blurRadius: 64, offset: const Offset(0, 28))],
      ),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _sectionLabel('Category'),
          const SizedBox(height: 10),
          _buildCategoryPicker(),
          const SizedBox(height: 24),
          _sectionLabel('Link a PC Issue  (optional)'),
          const SizedBox(height: 10),
          _buildIssueDropdown(),
          const SizedBox(height: 24),
          _sectionLabel('Subject'),
          const SizedBox(height: 10),
          _buildSubjectField(),
          const SizedBox(height: 24),
          _sectionLabel('Message'),
          const SizedBox(height: 10),
          _buildMessageField(),
          const SizedBox(height: 28),
          _buildSubmitButton(),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back_rounded, size: 16, color: _textColor.withOpacity(0.30)),
            label: Text('Cancel', style: TextStyle(color: _textColor.withOpacity(0.30), fontSize: 13)),
            style: TextButton.styleFrom(splashFactory: NoSplash.splashFactory),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(
        width: 58, height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [_accentA.withOpacity(0.15), _accentB.withOpacity(0.10)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: Border.all(color: _accentA.withOpacity(0.40), width: 1.5),
          boxShadow: [BoxShadow(color: _accentA.withOpacity(0.12), blurRadius: 16, spreadRadius: 2)],
        ),
        child: ShaderMask(
          shaderCallback: (b) => const LinearGradient(colors: [_accentA, _accentB],
              begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(b),
          child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 28),
        ),
      ),
      const SizedBox(width: 18),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(colors: [_accentA, _accentB]).createShader(b),
          child: const Text('NEW SUPPORT REQUEST',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
        ),
        const SizedBox(height: 4),
        Text('You can ask for help even when SysWatch has not detected a PC issue.',
            style: TextStyle(color: _textColor.withOpacity(0.42), fontSize: 13, height: 1.4)),
      ])),
    ]);
  }

  Widget _sectionLabel(String text) {
    return Text(text.toUpperCase(),
        style: TextStyle(color: _textColor.withOpacity(0.35), fontSize: 11,
            fontWeight: FontWeight.w700, letterSpacing: 1.2));
  }

  Widget _buildCategoryPicker() {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: _categories.entries.map((entry) {
        final selected = _category == entry.key;
        return GestureDetector(
          onTap: _submitting ? null : () => setState(() => _category = entry.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: selected ? const LinearGradient(colors: [_accentA, _accentB]) : null,
              color: selected ? null : _fieldColor,
              border: Border.all(color: selected ? Colors.transparent : _borderCol),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(entry.value.$2, size: 14,
                  color: selected ? const Color(0xFF080A0E) : _textColor.withOpacity(0.50)),
              const SizedBox(width: 7),
              Text(entry.value.$1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: selected ? const Color(0xFF080A0E) : _textColor.withOpacity(0.60))),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIssueDropdown() {
    if (_loadingIssues) {
      return Container(
        height: 52,
        decoration: BoxDecoration(color: _fieldColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: _borderCol)),
        child: Center(child: SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(_accentA.withOpacity(0.60))))),
      );
    }
    if (_issueError != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: _fieldColor, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.redAccent.withOpacity(0.30))),
        child: Row(children: [
          Icon(Icons.error_outline_rounded, color: Colors.redAccent.withOpacity(0.70), size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(_issueError!, style: TextStyle(color: _textColor.withOpacity(0.55), fontSize: 13))),
        ]),
      );
    }
    return _StyledDropdown(
      fieldColor: _fieldColor, borderCol: _borderCol, textColor: _textColor, accentA: _accentA,
      icon: Icons.link_rounded,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _faultReportId ?? _noIssueValue,
          isExpanded: true,
          dropdownColor: _cardColor,
          style: TextStyle(color: _textColor, fontSize: 14),
          iconSize: 0,
          onChanged: _submitting ? null : _selectIssue,
          items: [
            DropdownMenuItem<String>(
              value: _noIssueValue,
              child: Text('No linked issue', style: TextStyle(color: _textColor.withOpacity(0.45), fontSize: 14)),
            ),
            for (final issue in _activeIssues)
              DropdownMenuItem<String>(
                value: issue.faultReportId,
                child: Text('${issue.issue} (${issue.severity})', overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _textColor, fontSize: 14)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectField() {
    return Container(
      decoration: BoxDecoration(color: _fieldColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: _borderCol)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(Icons.title_rounded, color: _accentA.withOpacity(0.75), size: 18)),
        Expanded(child: TextFormField(
          controller: _subjectController,
          enabled: !_submitting,
          maxLength: 150,
          style: TextStyle(color: _textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. Microsoft Word will not open',
            hintStyle: TextStyle(color: _hintColor, fontSize: 13.5),
            labelText: 'Subject',
            labelStyle: TextStyle(color: _textColor.withOpacity(0.40), fontSize: 13),
            floatingLabelStyle: TextStyle(color: _accentA.withOpacity(0.80), fontSize: 12),
            counterStyle: TextStyle(color: _textColor.withOpacity(0.25), fontSize: 11),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          ),
          validator: (value) {
            final text = (value ?? '').trim();
            if (text.length < 3) return 'Enter a subject with at least 3 characters.';
            return null;
          },
        )),
      ]),
    );
  }

  Widget _buildMessageField() {
    return Container(
      decoration: BoxDecoration(color: _fieldColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: _borderCol)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: _messageController,
        enabled: !_submitting,
        minLines: 5, maxLines: 10, maxLength: 4000,
        style: TextStyle(color: _textColor, fontSize: 14, height: 1.5),
        decoration: InputDecoration(
          hintText: 'Describe what happened and what help you need.',
          hintStyle: TextStyle(color: _hintColor, fontSize: 13.5),
          labelText: 'Message',
          labelStyle: TextStyle(color: _textColor.withOpacity(0.40), fontSize: 13),
          floatingLabelStyle: TextStyle(color: _accentA.withOpacity(0.80), fontSize: 12),
          counterStyle: TextStyle(color: _textColor.withOpacity(0.25), fontSize: 11),
          alignLabelWithHint: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
        ),
        validator: (value) => (value ?? '').trim().isEmpty ? 'Enter a message.' : null,
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _submitting ? null : const LinearGradient(colors: [_accentA, _accentB]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: _submitting ? null
              : [BoxShadow(color: _accentA.withOpacity(0.28), blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: ElevatedButton.icon(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _submitting ? _fieldColor : Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: _submitting ? _textColor.withOpacity(0.40) : const Color(0xFF080A0E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: _submitting
              ? SizedBox(width: 17, height: 17,
              child: CircularProgressIndicator(strokeWidth: 2, color: _textColor.withOpacity(0.40)))
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(_submitting ? 'Sending…' : 'Send Support Request',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
        ),
      ),
    );
  }

  String _categoryForIssue(String issue) {
    final v = issue.toLowerCase();
    if (v.contains('Ethernet') || v.contains('Network')) return 'Network';
    if (v.contains('Keyboard') || v.contains('Mouse') || v.contains('Monitor')) return 'Peripheral';
    if (v.contains('Software') || v.contains('Application')) return 'Software';
    return 'hardware';
  }
}

class _StyledDropdown extends StatelessWidget {
  final Color  fieldColor;
  final Color  borderCol;
  final Color  textColor;
  final Color  accentA;
  final IconData icon;
  final Widget child;

  const _StyledDropdown({
    required this.fieldColor, required this.borderCol,
    required this.textColor,  required this.accentA,
    required this.icon,       required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: fieldColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderCol)),
      child: Row(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(icon, color: accentA.withOpacity(0.75), size: 18)),
        Expanded(child: Padding(padding: const EdgeInsets.only(right: 14), child: child)),
        Padding(padding: const EdgeInsets.only(right: 14),
            child: Icon(Icons.expand_more_rounded, size: 18, color: textColor.withOpacity(0.35))),
      ]),
    );
  }
}