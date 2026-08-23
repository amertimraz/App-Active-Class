// lib/views/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/auth_controller.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/views/auth/register_screen.dart';
import 'package:active_class/utils/helpers.dart';

class LoginScreen extends StatefulWidget {
  /// بتتفعّل لما الشاشة دي بتتفتح من شاشة "جدّد اشتراكك" (مفيش أي
  /// شاشة تانية في الستاك نرجعلها) — عشان لو تسجيل الدخول نجح واتضح
  /// إن الحساب ده مساعد في فريق نشط، نروح للرئيسية على طول بدل ما
  /// نوديه لشاشة الحساب اللي مش هيلاقي منها طريق للتطبيق أصلاً.
  final bool onSuccessGoHome;
  const LoginScreen({super.key, this.onSuccessGoHome = false});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await AuthController.to.signIn(
      phone: _phoneCtrl.text,
      password: _passCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      if (widget.onSuccessGoHome && TeamModeService().isEnabled.value) {
        Get.offAllNamed(ROUTE_HOME);
      } else {
        Get.offNamed(ROUTE_ACCOUNT);
      }
    } else {
      setState(() => _error = err);
      ToastHelper.error(err);
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
        title: const Text('تسجيل الدخول',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.person_rounded,
                      size: 42, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  'سجّل الدخول لحسابك',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black45),
                ),
                const SizedBox(height: 32),
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
                      _label('رقم التليفون', isDark),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        style: _fieldStyle(isDark),
                        decoration: _fieldDecoration('01xxxxxxxxx', isDark, border),
                        onChanged: (_) => setState(() => _error = null),
                      ),
                      const SizedBox(height: 16),
                      _label('الباسورد', isDark),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        textDirection: TextDirection.ltr,
                        style: _fieldStyle(isDark),
                        decoration: _fieldDecoration('••••••', isDark, border).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 18,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        onChanged: (_) => setState(() => _error = null),
                        onSubmitted: (_) => _loading ? null : _login(),
                      ),
                      const SizedBox(height: 16),
                      if (_error != null) _Feedback(msg: _error!),
                      if (_error != null) const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
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
                              : const Text('دخول',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton(
                          onPressed: _openForgotPasswordSupport,
                          child: Text('نسيت الباسورد؟',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.black45)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Get.off(() => const RegisterScreen()),
                  child: Text('معندكش حساب؟ إنشاء حساب جديد',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: AppTheme.primaryColor.withValues(alpha: 0.8))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // مفيش إيميل حقيقي ولا SMS في نظام الدخول ده (عشان نتجنب أي تكلفة
  // لكل رسالة) — يعني مفيش "استرجاع ذاتي" ممكن. البديل: طلب إعادة
  // تعيين عن طريق الدعم بالواتساب (نفس رقم الدعم المستخدم في باقي
  // التطبيق)، وبعد ما الأدمن يتأكد من هوية المدرس بيعيّن باسورد جديد
  // له من لوحة الإدارة.
  Future<void> _openForgotPasswordSupport() async {
    const supportPhone = '201096066818';
    final phone = _phoneCtrl.text.trim();
    final message = StringBuffer()
      ..writeln('مرحبًا، أنا مدرس ناسي باسورد حسابي في تطبيق Active Class.');
    if (phone.isNotEmpty) {
      message.writeln('رقم التليفون المسجل بيه: $phone');
    }
    message.writeln('برجاء إعادة تعيين الباسورد.');

    final uri = Uri.parse(
        'https://wa.me/$supportPhone?text=${Uri.encodeComponent(message.toString())}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) ToastHelper.error('تعذر فتح واتساب');
    }
  }

  Widget _label(String text, bool isDark) => Text(text,
      style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white70 : Colors.black54));

  TextStyle _fieldStyle(bool isDark) => TextStyle(
      fontFamily: 'Cairo',
      fontSize: 15,
      color: isDark ? Colors.white : Colors.black87);

  InputDecoration _fieldDecoration(String hint, bool isDark, Color border) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            color: isDark ? Colors.white30 : Colors.black26),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}

class _Feedback extends StatelessWidget {
  final String msg;
  const _Feedback({required this.msg});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Text(msg,
            style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 12, color: Colors.red)),
      );
}
