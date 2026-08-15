// lib/views/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/auth_controller.dart';
import 'package:active_class/views/auth/login_screen.dart';
import 'package:active_class/utils/helpers.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'الباسورد وتأكيد الباسورد مش متطابقين');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await AuthController.to.register(
      phone: _phoneCtrl.text,
      password: _passCtrl.text,
      displayName: _nameCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      Get.offNamed(ROUTE_ACCOUNT);
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
        title: const Text('إنشاء حساب جديد',
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
                      _label('الاسم (اختياري)', isDark),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameCtrl,
                        style: _fieldStyle(isDark),
                        decoration: _fieldDecoration('اسمك', isDark, border),
                      ),
                      const SizedBox(height: 16),
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
                        decoration: _fieldDecoration('6 أحرف على الأقل', isDark, border)
                            .copyWith(
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
                      ),
                      const SizedBox(height: 16),
                      _label('تأكيد الباسورد', isDark),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _confirmCtrl,
                        obscureText: _obscure,
                        textDirection: TextDirection.ltr,
                        style: _fieldStyle(isDark),
                        decoration: _fieldDecoration('أعد كتابة الباسورد', isDark, border),
                        onChanged: (_) => setState(() => _error = null),
                        onSubmitted: (_) => _loading ? null : _register(),
                      ),
                      const SizedBox(height: 16),
                      if (_error != null) _Feedback(msg: _error!),
                      if (_error != null) const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _register,
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
                              : const Text('إنشاء حساب',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Get.off(() => const LoginScreen()),
                  child: Text('عندك حساب بالفعل؟ سجّل الدخول',
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
