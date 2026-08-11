// lib/services/in_app_update_service.dart
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

import 'package:active_class/services/install_source_service.dart';

/// يفحص وجود تحديث عبر Google Play Core API الرسمي (In-App Updates) —
/// البديل المتوافق مع سياسة Google Play لآلية التحديث القديمة (GitHub)
/// اللي بقت متعطّلة لمن يثبّت من المتجر. التحميل والتثبيت بيتما بالكامل
/// عن طريق Play نفسها، إحنا بس بنستقبل الحالة ونوري رسالة للمستخدم.
class InAppUpdateService {
  static bool _checkedThisSession = false;

  static Future<void> checkAndPrompt(BuildContext context) async {
    if (_checkedThisSession) return;
    _checkedThisSession = true;

    if (!await InstallSourceService.isInstalledFromPlayStore()) return;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
            'تم تحميل تحديث جديد للتطبيق',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'إعادة التشغيل',
            onPressed: () {
              InAppUpdate.completeFlexibleUpdate().catchError((_) {});
            },
          ),
        ));
      } else if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (_) {
      // مش خطوة حرجة — تجاهل أي فشل (بدون اتصال، Play غير متاح، إلخ)
    }
  }
}
