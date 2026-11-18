// lib/widgets/team_access_blocked_dialog.dart
//
// spec 058 / P4 — المساعد المقيَّد اللي المدرس لسه ما حدّدش له أي مجموعة/سنتر: حوار غير
// قابل للإغلاق بيوضّح السبب ويمنعه من الشغل. مش بيمسح بياناته ولا بيسجّل خروجه تلقائيًا:
// أول ما المدرس يمنحه مجموعات، الحوار بيتشال تلقائيًا (التطبيق بيتحقق كل دقيقة تقريبًا)
// أو بزر «تحديث».
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/controllers/auth_controller.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/widgets/chalk_dialog.dart';

class TeamAccessBlockedDialog {
  static bool _open = false;

  static bool get isOpen => _open;

  /// يفتح الحوار (مرة واحدة). [onRefresh] بيعيد فحص الوصول من السيرفر.
  static Future<void> show({required Future<void> Function() onRefresh}) async {
    if (_open) return;
    _open = true;
    try {
      await Get.dialog(
        PopScope(
          canPop: false,
          child: _BlockedBody(onRefresh: onRefresh),
        ),
        barrierDismissible: false,
      );
    } finally {
      _open = false;
    }
  }

  /// يقفل الحوار لو مفتوح (المدرس منح المساعد مجموعات).
  static void dismiss() {
    if (!_open) return;
    if (Get.isDialogOpen == true) Get.back();
  }
}

class _BlockedBody extends StatefulWidget {
  final Future<void> Function() onRefresh;
  const _BlockedBody({required this.onRefresh});

  @override
  State<_BlockedBody> createState() => _BlockedBodyState();
}

class _BlockedBodyState extends State<_BlockedBody> {
  bool _busy = false;

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChalkDialog(
      icon: Icons.lock_person_rounded,
      tone: ChalkTone.caution,
      title: 'لسه ما اتحدّدلكش مجموعات',
      body: const [
        ChalkRule(
          icon: Icons.info_outline_rounded,
          text: 'المدرس لسه ما حدّدلك أي سنتر أو مجموعة تشتغل عليها، فمش '
              'هتقدر تفتح بيانات الفريق دلوقتي.',
        ),
        ChalkRule(
          icon: Icons.chat_rounded,
          text: 'كلّم المدرس يحدّدلك المجموعات من «المساعدين والحسابات»، وبعدها '
              'اضغط «تحديث». هتفتح لوحدها أول ما يحدّدلك.',
        ),
      ],
      actions: [
        ChalkAction(
          label: _busy ? 'جاري التحديث...' : 'تحديث',
          icon: Icons.refresh_rounded,
          onPressed: () {
            if (!_busy) _refresh();
          },
        ),
        ChalkAction(
          label: 'تسجيل الخروج',
          kind: ChalkActionKind.text,
          onPressed: () async {
            Get.back();
            try {
              await AuthController.to.signOut();
            } catch (_) {}
            Get.offAllNamed(ROUTE_HOME);
          },
        ),
      ],
    );
  }
}
