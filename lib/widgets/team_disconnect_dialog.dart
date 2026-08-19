// lib/widgets/team_disconnect_dialog.dart
//
// حوار غير قابل للإغلاق بيظهر على جهاز المساعد لما وضع الفريق يتقفل
// من غير ما هو يعمل حاجة (المدرس عطّل الميزة، أو أزاله من الفريق، أو
// ترخيص المدرس وقف) — بيوضحله السبب بعدّاد تنازلي، وبعدها بيسجّل
// خروجه تلقائيًا ويرجّع التطبيق لحالة تجربة مجانية جديدة (بياناته
// المحلية الخاصة بالفريق اتمسحت أصلاً قبل ما الحوار ده يظهر).
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/auth_controller.dart';

class TeamDisconnectDialog {
  static bool _active = false;

  static Future<void> show(String message) async {
    if (_active) return; // منع فتح أكتر من حوار مرة واحدة لو أكتر من سبب اتكشف قريب من بعض
    _active = true;
    try {
      await Get.dialog(
        _CountdownDialog(message: message),
        barrierDismissible: false,
      );
      try {
        await AuthController.to.signOut();
      } catch (e) {
        // حتى لو فشل تسجيل الخروج (مفيش نت مثلاً) — بيانات الفريق
        // المحلية اتمسحت أصلاً قبل ما الحوار ده يظهر، فلازم نكمل
        // للصفحة الرئيسية بدل ما نسيب المستخدم عالق على نفس الشاشة.
        debugPrint('TeamDisconnectDialog: فشل تسجيل الخروج التلقائي — $e');
      }
      Get.offAllNamed(ROUTE_HOME);
    } finally {
      _active = false;
    }
  }
}

class _CountdownDialog extends StatefulWidget {
  final String message;
  const _CountdownDialog({required this.message});

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  static const _seconds = 5;
  int _remaining = _seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        Get.back();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.groups_rounded, size: 42, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 12),
              Text(
                'هيتم تسجيل خروجك تلقائيًا خلال $_remaining...',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black45),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  value: _remaining / _seconds,
                  strokeWidth: 3,
                  color: AppTheme.primaryColor,
                  backgroundColor:
                      isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
