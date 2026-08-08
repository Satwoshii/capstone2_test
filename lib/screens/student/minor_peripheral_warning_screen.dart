import 'package:flutter/material.dart';

import '../../models/hardware_status.dart';
import '../../models/pc_identity.dart';
import '../../widgets/issue_support_launcher.dart';

class MinorPeripheralWarningScreen extends StatefulWidget {
  final PcIdentity pc;
  final HardwareStatus hardware;
  final bool sessionActive;
  final bool isDarkMode;
  final Future<void> Function()? onContinueInBackground;

  const MinorPeripheralWarningScreen({
    super.key,
    required this.pc,
    required this.hardware,
    required this.sessionActive,
    this.isDarkMode = true,
    this.onContinueInBackground,
  });

  @override
  State<MinorPeripheralWarningScreen> createState() =>
      _MinorPeripheralWarningScreenState();
}

class _MinorPeripheralWarningScreenState
    extends State<MinorPeripheralWarningScreen> with TickerProviderStateMixin {

  late final AnimationController _entryCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _pulseAnim;

  bool get _dark => widget.isDarkMode;

  Color get _bgColor    => _dark ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
  Color get _cardColor  => _dark ? const Color(0xFF13141A) : Colors.white;
  Color get _fieldColor => _dark ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);
  Color get _textColor  => _dark ? Colors.white : const Color(0xFF1A1C1E);
  Color get _borderCol  =>
      _dark ? const Color(0x12FFFFFF) : Colors.black.withOpacity(0.09);

  static const Color _warnA = Color(0xFFF5A623);
  static const Color _warnB = Color(0xFFFF6B35);

  List<_Tip> get _tips {
    final list = <_Tip>[];
    for (final issue in widget.hardware.minorIssues) {
      switch (issue) {
        case 'mouse':
          list.add(_Tip(Icons.mouse_rounded,     'Reconnect the mouse or try another USB port.'));
          list.add(_Tip(Icons.lightbulb_outline, 'Check whether the mouse sensor light turns on.'));
          break;
        case 'keyboard':
          list.add(_Tip(Icons.keyboard_rounded,  'Reconnect the keyboard or try another USB port.'));
          list.add(_Tip(Icons.lightbulb_outline, 'Check whether Caps Lock or Num Lock responds.'));
          break;
        case 'monitor':
          list.add(_Tip(Icons.monitor_rounded,   'Check the monitor power and display cables.'));
          list.add(_Tip(Icons.lightbulb_outline, 'Make sure the monitor is turned on.'));
          break;
      }
    }
    final seen = <String>{};
    return list.where((t) => seen.add(t.text)).toList();
  }

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _fadeAnim  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.88, end: 1.1)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue(BuildContext context) async {
    Navigator.of(context).pop();
    await widget.onContinueInBackground?.call();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _bgColor,
        body: Stack(
          children: [
            _buildAmbientOrbs(),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: _buildCard(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientOrbs() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(top: -90,  left:  -70, child: _orb(320, _warnA.withOpacity(0.07))),
          Positioned(bottom: -110, right: -60, child: _orb(360, _warnB.withOpacity(0.06))),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );

  Widget _buildCard() {
    return Container(
      width: 600,
      padding: const EdgeInsets.fromLTRB(40, 44, 40, 40),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_dark ? 0.55 : 0.10),
            blurRadius: 64,
            offset: const Offset(0, 28),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildWarningBadge(),
          const SizedBox(height: 18),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_warnA, _warnB],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds),
            child: const Text(
              'MINOR PERIPHERAL WARNING',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.w800, letterSpacing: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildDevicePills(),
          const SizedBox(height: 20),
          Text(
            widget.sessionActive
                ? 'Your session remains active. SysWatch will keep checking the device in the background.'
                : 'You may continue to student authentication. SysWatch will keep checking the device.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textColor.withOpacity(0.70), fontSize: 14.5, height: 1.55),
          ),
          const SizedBox(height: 24),
          ..._tips.map(_buildTipTile),
          if (_tips.isNotEmpty) const SizedBox(height: 20),
          _buildRecoveryBadge(),
          const SizedBox(height: 20),
          Text(
            '${widget.pc.roomName}  ·  ${widget.pc.pcId}',
            style: TextStyle(color: _textColor.withOpacity(0.30), fontSize: 12, letterSpacing: 0.4),
          ),
          if (widget.sessionActive) ...[
            const SizedBox(height: 16),
            const IssueSupportLauncher(compact: true),
          ],
          const SizedBox(height: 24),
          Divider(color: _textColor.withOpacity(0.08), thickness: 1),
          const SizedBox(height: 20),
          _buildContinueButton(),
        ],
      ),
    );
  }

  Widget _buildWarningBadge() {
    return SizedBox(
      width: 110, height: 110,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, __) => Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: _pulseAnim.value,
              child: Container(
                width: 104, height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _warnA.withOpacity(0.28), width: 1.5),
                  boxShadow: [BoxShadow(color: _warnA.withOpacity(0.18), blurRadius: 28, spreadRadius: 4)],
                ),
              ),
            ),
            Container(
              width: 82, height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_warnA.withOpacity(0.18), _warnB.withOpacity(0.12)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                border: Border.all(color: _warnA.withOpacity(0.55), width: 2),
              ),
            ),
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [_warnA, _warnB],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ).createShader(b),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 40),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicePills() {
    const icons = {
      'mouse':    Icons.mouse_rounded,
      'keyboard': Icons.keyboard_rounded,
      'monitor':  Icons.monitor_rounded,
    };
    return Wrap(
      spacing: 8, runSpacing: 8,
      alignment: WrapAlignment.center,
      children: widget.hardware.minorIssues.map((issue) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _warnA.withOpacity(0.10),
            border: Border.all(color: _warnA.withOpacity(0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icons[issue] ?? Icons.device_unknown_rounded, color: _warnA, size: 15),
              const SizedBox(width: 7),
              Text(
                issue.toUpperCase(),
                style: TextStyle(color: _warnA, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.0),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTipTile(_Tip tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _fieldColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderCol),
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: LinearGradient(
                  colors: [_warnA.withOpacity(0.15), _warnB.withOpacity(0.10)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: Icon(tip.icon, color: _warnA, size: 17),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                tip.text,
                style: TextStyle(color: _textColor.withOpacity(0.80), fontSize: 13.5, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderCol),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monitor_heart_rounded, color: _warnA.withOpacity(0.75), size: 16),
          const SizedBox(width: 9),
          Text(
            'Automatic recovery check runs every 10 seconds',
            style: TextStyle(color: _textColor.withOpacity(0.50), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      height: 50, width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_warnA, _warnB],
            begin: Alignment.centerLeft, end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: _warnA.withOpacity(0.28), blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: ElevatedButton.icon(
          onPressed: () => _continue(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: const Color(0xFF1A0A00),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: Icon(
            widget.sessionActive ? Icons.visibility_off_rounded : Icons.arrow_forward_rounded,
            size: 19,
          ),
          label: Text(
            widget.sessionActive ? 'Continue in Background' : 'Continue to Login',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
          ),
        ),
      ),
    );
  }
}

class _Tip {
  final IconData icon;
  final String text;
  const _Tip(this.icon, this.text);
}