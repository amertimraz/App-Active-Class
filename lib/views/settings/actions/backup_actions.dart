part of '../settings_page.dart';

// spec 051 — أفعال النسخ الاحتياطي والحذف (نقل حرفي)

Future<void> _handleEnhancedBackup(BuildContext context) async {
  final svc = BackupService();
  final result = await ProgressDialog.run(
    context,
    title: 'جاري إنشاء النسخة الاحتياطية...',
    icon: Icons.backup_rounded,
    task: svc.createBackup,
  );
  // فسحة صغيرة عشان أنيميشن إغلاق حوار التقدّم يخلص تماماً قبل ما
  // نفتح حوار تاني على نفس الـ Navigator (تجنّب تعارض بين إغلاق
  // وفتح حوارين في نفس الوقت تقريباً).
  await Future.delayed(const Duration(milliseconds: 80));
  if (!context.mounted) return;

  if (!result.success) {
    ToastHelper.error(result.error ?? 'فشل إنشاء النسخة الاحتياطية');
    return;
  }

  // نسخة Downloads اختيارية وبطيئة على بعض الأجهزة (MediaStore بيجمّد
  // الـ main thread لثوانٍ — قيد في المكتبة الأصلية مش حاجة نقدر نلغيها
  // من الداخل) — بنأجّلها شوية عشان شاشة النجاح تترسم وتبان فعلاً
  // للمستخدم قبل ما الجمود المؤقت يحصل، بدل ما تفضل شاشة "معلّقة"
  // بصريًا من أول لمسة. من غير toast عمداً: بتتنفذ بعيد زمنياً عن
  // لمسة المستخدم وممكن تحصل بعد ما يغيّر شاشة.
  if (result.localPath != null && result.fileName != null) {
    Future.delayed(const Duration(milliseconds: 500), () {
      svc.saveToDownloads(result.localPath!, result.fileName!);
    });
  }

  // البيانات اللي فعلياً اتحفظت جوه النسخة (نفس محتوى قاعدة البيانات
  // الحالية وقت الحفظ)، عشان المستخدم يشوف بالظبط قد إيه اتحفظ.
  final summary = await DatabaseService().getDataSummary();
  if (!context.mounted) return;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('✅ تم إنشاء النسخة الاحتياطية',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(Icons.storage_rounded, Colors.green,
              'محفوظة داخل التطبيق (دائمة)'),
          const SizedBox(height: 6),
          Text('الحجم: ${result.fileSize ?? '—'}',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
          const Divider(height: 20),
          _DataSummaryList(summary: summary),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo')),
        ),
        if (result.localPath != null)
          ElevatedButton.icon(
            onPressed: () {
              svc.shareBackup(result.localPath!);
              Navigator.of(ctx).pop();
            },
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text('مشاركة', style: TextStyle(fontFamily: 'Cairo')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
      ],
    ),
  );
}

// ── Restore ───────────────────────────────────────────────────────────────
Future<void> _handleRestoreBackup(BuildContext context) async {
  final svc = BackupService();

  // عرض خيارات الاستعادة
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('استعادة نسخة احتياطية',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // تحذير
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'سيتم استبدال جميع البيانات الحالية بالنسخة المختارة. هذا الإجراء لا يمكن التراجع عنه.',
                    style: TextStyle(
                        fontFamily: 'Cairo', fontSize: 12, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // خيار 1: نسخ محفوظة
          _ChoiceButton(
            icon: Icons.history_rounded,
            color: AppTheme.primaryColor,
            title: 'من النسخ المحفوظة',
            subtitle: 'استعادة من نسخة أنشأتها سابقاً',
            onTap: () => Navigator.of(ctx).pop('local'),
          ),
          const SizedBox(height: 10),
          // خيار 2: اختيار ملف
          _ChoiceButton(
            icon: Icons.folder_open_rounded,
            color: const Color(0xFF8B5CF6),
            title: 'اختيار ملف من الجهاز',
            subtitle: 'اختر ملف .zip (أو .db قديم) من Downloads أو أي مكان آخر',
            onTap: () => Navigator.of(ctx).pop('pick'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
        ),
      ],
    ),
  );

  if (choice == null || !context.mounted) return;

  String? selectedPath;

  if (choice == 'local') {
    // عرض النسخ المحفوظة
    LoadingDialog.show(context, message: 'جاري تحميل النسخ...');
    final backups = await svc.getLocalBackups();
    if (!context.mounted) return;
    LoadingDialog.hide();

    if (backups.isEmpty) {
      ToastHelper.info(
          'لا توجد نسخ احتياطية محفوظة داخل التطبيق.\nجرّب "اختيار ملف من الجهاز"');
      return;
    }

    selectedPath = await showDialog<String>(
      context: context,
      builder: (ctx) => _BackupListDialog(backups: backups, svc: svc),
    );
  } else {
    // File picker
    final picked = await svc.pickBackupFile();
    if (picked == 'INVALID_EXT') {
      if (context.mounted) {
        ToastHelper.error(
            'الملف المختار ليس ملف نسخة احتياطية صالح (.zip أو .db)');
      }
      return;
    }
    selectedPath = picked;
  }

  if (selectedPath == null || !context.mounted) return;

  // تأكيد نهائي
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('تأكيد الاستعادة',
          style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              color: Colors.red)),
      content: const Text(
        'هل أنت متأكد؟\nسيتم مسح جميع البيانات الحالية واستبدالها بالنسخة المختارة.',
        style: TextStyle(fontFamily: 'Cairo'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child:
              const Text('استعادة الآن', style: TextStyle(fontFamily: 'Cairo')),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;
  // فسحة صغيرة عشان أنيميشن إغلاق حوار التأكيد يخلص الأول
  await Future.delayed(const Duration(milliseconds: 80));
  if (!context.mounted) return;

  final success = await ProgressDialog.run(
    context,
    title: 'جاري استعادة النسخة الاحتياطية...',
    icon: Icons.restore_rounded,
    color: const Color(0xFF06B6D4),
    task: () => svc.restoreBackup(selectedPath!),
  );
  if (!context.mounted) return;

  if (success) {
    // كل الكنترولرز لسه فاكرة بيانات ما قبل الاستعادة في الذاكرة —
    // لازم نعيد تحميلها كلها من القاعدة المستعادة، وإلا التطبيق يفضل
    // يعرض الطلاب/المجموعات/الامتحانات القديمة (أو فاضية لو استعادة
    // على تثبيت جديد) رغم إن القاعدة اتغيّرت فعلاً.
    await _reloadAllControllers();
    if (!context.mounted) return;
    ToastHelper.success('تم استعادة النسخة الاحتياطية بنجاح');
    await Future.delayed(const Duration(milliseconds: 400));
    Get.offAllNamed(ROUTE_HOME);
  } else {
    ToastHelper.error('فشل الاستعادة — البيانات الأصلية لا تزال سليمة');
  }
}

Future<void> _reloadAllControllers() async {
  Future<void> tryReload(bool registered, Future<void> Function() fn) async {
    if (!registered) return;
    try {
      await fn();
    } catch (_) {}
  }

  // جلسة وضع الفريق (Supabase auth) متخزّنة في SharedPreferences —
  // النسخة الاحتياطية بترجّعها هناك، لكن أي عميل Supabase كان شغّال
  // بالفعل في التشغيلة دي (أو اتعمله تسجيل خروج) مش بيلاحظ التغيير
  // تلقائيًا؛ لازم نعيد حقنها يدويًا ثم نعيد تشغيل TeamModeService
  // من الأول عشان صلاحيات الفريق ومحرك المزامنة يرجعوا صح.
  try {
    final recovered = await AuthService().recoverPersistedSession();
    if (recovered) {
      await TeamModeService().init();
    }
  } catch (_) {}

  await tryReload(Get.isRegistered<SettingsController>(),
      () => Get.find<SettingsController>().reloadFromDatabase());
  await tryReload(Get.isRegistered<GroupController>(),
      () => Get.find<GroupController>().loadGroups());
  await tryReload(Get.isRegistered<StudentController>(),
      () => Get.find<StudentController>().loadAllStudents());
  await tryReload(Get.isRegistered<ExamController>(),
      () => Get.find<ExamController>().loadExams());
  await tryReload(Get.isRegistered<AttendanceController>(),
      () => Get.find<AttendanceController>().loadAttendance());
  await tryReload(Get.isRegistered<PaymentController>(),
      () => Get.find<PaymentController>().loadPayments());
  await tryReload(Get.isRegistered<HomeworkController>(),
      () => Get.find<HomeworkController>().loadHomework());
  await tryReload(Get.isRegistered<DashboardController>(),
      () async => Get.find<DashboardController>().refresh());
}

// ── Manage backups ────────────────────────────────────────────────────────
Future<void> _handleManageBackups(BuildContext context) async {
  final svc = BackupService();
  LoadingDialog.show(context, message: 'جاري تحميل النسخ...');
  final backups = await svc.getLocalBackups();
  if (!context.mounted) return;
  LoadingDialog.hide();

  if (backups.isEmpty) {
    ToastHelper.info(
        'لا توجد نسخ احتياطية محفوظة\nأنشئ نسخة أولاً من "نسخ احتياطي"');
    return;
  }

  await showDialog(
    context: context,
    builder: (ctx) => _ManageBackupsDialog(
      backups: backups,
      svc: svc,
      onChanged: () {
        Navigator.of(ctx).pop();
        _handleManageBackups(context);
      },
    ),
  );
}

// spec 037 — شيت النسخ السحابي (Google Drive): ربط/إلغاء ربط + رفع
// الآن + قائمة النسخ (استعادة/حذف لكل واحدة).
void _handleCloudBackup(BuildContext context) {
  final controller = Get.isRegistered<GoogleDriveBackupController>()
      ? Get.find<GoogleDriveBackupController>()
      : Get.put(GoogleDriveBackupController());
  // controller.onInit() بيجيب القائمة مرة واحدة بس (أول ما يتعمله put) —
  // من غير الاستدعاء ده، فتح الشيت تاني بعد قفله كان بيعرض بيانات قديمة
  // (مثلاً لو نسخة اتضافت/اتمسحت من جهاز تاني في الوقت ده).
  unawaited(controller.refreshLinkStatus());
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetCtx) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(sheetCtx).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D31) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Obx(() {
        final linked = controller.isLinked.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.cloud_rounded,
                      color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 8),
                  const Text('النسخ السحابي (Google Drive)',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
            const Divider(height: 16),
            if (!linked)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'اربط حساب Google بتاعك عشان نسخك الاحتياطية ترفع'
                      ' تلقائيًا على درايفك الشخصي — لو الجهاز ضاع أو'
                      ' اتعطّل، تقدر تسترجع بياناتك على جهاز جديد بسهولة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color:
                              isDark ? Colors.white70 : Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: controller.busy.value
                          ? null
                          : () async {
                              final ok = await controller.linkAccount();
                              if (!sheetCtx.mounted) return;
                              if (ok) {
                                ToastHelper.success('تم ربط حساب Google بنجاح');
                              } else {
                                ToastHelper.error('لم يتم الربط');
                              }
                            },
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('تفعيل النسخ السحابي'),
                    ),
                  ],
                ),
              )
            else ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'مربوط: ${controller.linkedEmail.value ?? ""}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: controller.busy.value
                          ? null
                          : () async {
                              await controller.unlinkAccount();
                              ToastHelper.info('تم إلغاء ربط الحساب');
                            },
                      child: const Text('إلغاء الربط',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: controller.busy.value
                        ? null
                        : () async {
                            debugPrint(
                                '[CloudBackup] upload-now button tapped');
                            final ok = await controller.uploadNow();
                            debugPrint('[CloudBackup] uploadNow returned $ok');
                            if (!sheetCtx.mounted) return;
                            if (ok) {
                              ToastHelper.success('تم رفع نسخة للسحابة');
                            } else {
                              ToastHelper.error('فشل الرفع');
                            }
                          },
                    icon: const Icon(Icons.cloud_upload_rounded),
                    label: const Text('رفع نسخة للسحابة الآن'),
                  ),
                ),
              ),
              const Divider(height: 16),
              Expanded(
                child: controller.cloudBackups.isEmpty
                    ? Center(
                        child: Text('لا توجد نسخ سحابية بعد',
                            style: TextStyle(
                                color: isDark
                                    ? Colors.white38
                                    : Colors.grey.shade600)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: controller.cloudBackups.length,
                        itemBuilder: (_, i) {
                          final entry = controller.cloudBackups[i];
                          return ListTile(
                            leading: const Icon(Icons.archive_rounded,
                                color: Color(0xFF10B981)),
                            title: Text(_fmtCloudBackupTime(entry.createdTime)),
                            subtitle: Text(entry.sizeLabel),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.restore_rounded,
                                      color: Color(0xFF06B6D4)),
                                  onPressed: () => _confirmCloudRestore(
                                      context, controller, entry),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  onPressed: () => ConfirmDeleteDialog.show(
                                    sheetCtx,
                                    title: 'حذف نسخة سحابية',
                                    message:
                                        'هل تريد حذف هذه النسخة من Google Drive؟',
                                    onConfirm: () async {
                                      final ok =
                                          await controller.deleteBackup(entry);
                                      if (ok) {
                                        ToastHelper.success('تم الحذف');
                                      } else {
                                        ToastHelper.error('فشل الحذف');
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ],
        );
      }),
    ),
  );
}

// تاريخ + وقت محلي مقروء للنسخة السحابية — createdTime من Google بيرجع
// UTC، لازم .toLocal() وإلا الوقت المعروض يفرق بساعتين/تلاتة عن وقت
// المستخدم الفعلي.
String _fmtCloudBackupTime(DateTime utc) {
  final t = utc.toLocal();
  final date =
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  final time =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  return '$date • $time';
}

// تحذير صريح قبل الاستعادة (FR-012) — يوضّح إن البيانات المحلية
// الحالية هتتستبدل، مع تاريخ النسخة.
void _confirmCloudRestore(BuildContext context,
    GoogleDriveBackupController controller, CloudBackupEntry entry) {
  Get.defaultDialog(
    title: 'استعادة نسخة سحابية',
    middleText:
        'هيتم استبدال كل بياناتك الحالية بنسخة ${_fmtCloudBackupTime(entry.createdTime)}. متأكد؟',
    textConfirm: 'استعادة الآن',
    confirmTextColor: Colors.white,
    buttonColor: Colors.red,
    textCancel: 'إلغاء',
    onConfirm: () async {
      Get.back();
      if (!context.mounted) return;
      final success = await ProgressDialog.run(
        context,
        title: 'جاري الاستعادة من السحابة...',
        icon: Icons.cloud_download_rounded,
        color: const Color(0xFF06B6D4),
        task: () => controller.restore(entry),
      );
      if (!context.mounted) return;
      if (success) {
        await _reloadAllControllers();
        if (!context.mounted) return;
        ToastHelper.success('تم استعادة النسخة السحابية بنجاح');
        await Future.delayed(const Duration(milliseconds: 400));
        Get.offAllNamed(ROUTE_HOME);
      } else {
        ToastHelper.error('فشل الاستعادة — البيانات الأصلية لا تزال سليمة');
      }
    },
  );
}

void _handleDeleteAll(
    BuildContext context, SettingsController settingsController) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    ConfirmDeleteDialog.show(
      context,
      title: 'حذف جميع البيانات',
      message:
          'هل أنت متأكد؟ سيتم حذف جميع البيانات بشكل نهائي ولا يمكن التراجع',
      onConfirm: () async {
        try {
          // لازم ناخد الملخص قبل الحذف — بعد الحذف كل الأعداد بتبقى صفر
          final summary = await DatabaseService().getDataSummary();
          // فسحة صغيرة عشان أنيميشن إغلاق حوار التأكيد يخلص الأول
          await Future.delayed(const Duration(milliseconds: 80));
          if (!context.mounted) return;
          await ProgressDialog.run(
            context,
            title: 'جاري حذف البيانات...',
            icon: Icons.delete_forever_rounded,
            color: Colors.red,
            task: settingsController.deleteAllData,
          );
          await Future.delayed(const Duration(milliseconds: 80));
          if (!context.mounted) return;
          SuccessDialog.show(
            context,
            title: 'تم الحذف',
            message: 'تم حذف جميع البيانات بنجاح',
            content: _DataSummaryList(summary: summary),
          );
        } catch (e) {
          if (!context.mounted) return;
          ErrorDialog.show(
            context,
            title: 'فشل الحذف',
            message: e.toString(),
          );
        }
      },
    );
  });
}
