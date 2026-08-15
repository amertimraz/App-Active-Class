// lib/views/team/join_team_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/services/team_mode_service.dart';

class JoinTeamScreen extends StatefulWidget {
  const JoinTeamScreen({super.key});
  @override
  State<JoinTeamScreen> createState() => _JoinTeamScreenState();
}

class _JoinTeamScreenState extends State<JoinTeamScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await TeamModeService().joinWithInvite(_codeCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      Get.back();
      Get.back();
    } else {
      setState(() => _error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final card = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('الانضمام لفريق',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('كود الدعوة',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : Colors.black54)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _codeCtrl,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                            color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'XXXXXXXX',
                          hintStyle: TextStyle(
                              fontFamily: 'Cairo',
                              color: isDark ? Colors.white30 : Colors.black26),
                          filled: true,
                          fillColor:
                              isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: border)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: border)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppTheme.primaryColor, width: 2)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        onChanged: (_) => setState(() => _error = null),
                        onSubmitted: (_) => _loading ? null : _join(),
                      ),
                      const SizedBox(height: 16),
                      if (_error != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Text(_error!,
                              style: const TextStyle(
                                  fontFamily: 'Cairo', fontSize: 12, color: Colors.red)),
                        ),
                      if (_error != null) const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _join,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('انضمام',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'هيتم تحميل بيانات الفريق (المجموعات والطلاب) على جهازك بعد الانضمام.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
