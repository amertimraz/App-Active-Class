// lib/views/license/activation_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/views/license/plans_page.dart';

class ActivationPage extends StatefulWidget {
  final bool showBackButton;
  const ActivationPage({super.key, this.showBackButton = false});
  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = false;
    });
    final err = await LicenseController.to.activateCode(_ctrl.text);
    if (!mounted) return;
    if (err == null) {
      setState(() {
        _success = true;
        _loading = false;
      });
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(ROUTE_HOME, (_) => false);
      }
    } else {
      setState(() {
        _error = err;
        _loading = false;
      });
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Logo ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Image.asset('assets/icon/logo_foreground.png',
                      width: 42, height: 42),
                ),
                const SizedBox(height: 20),
                const Text('Active Class',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryColor)),
                const SizedBox(height: 6),
                Text(
                  'أدخل كود التفعيل للاستمرار',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black45),
                ),
                const SizedBox(height: 32),

                // ── Card ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('كود التفعيل',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : Colors.black54)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _ctrl,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'ACTV-XXXX-XXXX-XXXX',
                          hintStyle: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              letterSpacing: 1,
                              color: isDark ? Colors.white30 : Colors.black26),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
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
                        onSubmitted: (_) => _loading ? null : _activate(),
                      ),
                      const SizedBox(height: 16),

                      // Error / Success
                      if (_error != null)
                        _Feedback(msg: _error!, isError: true),
                      if (_success)
                        const _Feedback(
                            msg: 'تم التفعيل بنجاح! جاري التحميل...',
                            isError: false),
                      if (_error != null || _success)
                        const SizedBox(height: 12),

                      // Activate button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _activate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('تفعيل الترخيص',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Footer links ──────────────────────────────────
                TextButton(
                  onPressed: () => Get.to(() => const PlansPage()),
                  child: Text('ليس لديك كود؟ اطلب ترقية',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: AppTheme.primaryColor.withValues(alpha: 0.8))),
                ),
                if (widget.showBackButton)
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('رجوع',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: Colors.grey)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  final String msg;
  final bool isError;
  const _Feedback({required this.msg, required this.isError});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (isError ? Colors.red : Colors.green).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color:
                  (isError ? Colors.red : Colors.green).withValues(alpha: 0.3)),
        ),
        child: Text(msg,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: isError ? Colors.red : Colors.green)),
      );
}
