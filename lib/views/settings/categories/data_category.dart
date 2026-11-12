part of '../settings_page.dart';

// spec 051 — فئة «البيانات والنسخ الاحتياطي» بتصميم السبورة والكروت:
// سبورة بحالة النسخ، كارت الحفظ التلقائي، كروت إجراءات، ومنطقة خطر واضحة.

class _DataCategoryPage extends StatelessWidget {
  const _DataCategoryPage({this.highlightId});

  /// معرّف عنصر من نتيجة بحث (spec 051) — بيتميّز بشريط في أول الصفحة.
  final String? highlightId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _tk(isDark);
    const indigo = Color(0xFF4F46E5);
    const gap = SizedBox(height: AppSpace.lg);
    return _CategoryScaffold(
      title: 'البيانات والنسخ الاحتياطي',
      highlightId: highlightId,
      children: [
        // ── السبورة: حالة النسخ الاحتياطي ──
        Obx(() {
          final svc = AutoBackupService();
          final on = svc.enabled.value;
          final last = svc.lastBackupTime.value;
          return _boardSummary(
            t,
            icon: Icons.storage_rounded,
            title: 'البيانات والنسخ الاحتياطي',
            subtitle: 'احمي بياناتك بنسخة محفوظة',
            stats: [
              (label: 'الحفظ التلقائي', value: on ? 'شغّال' : 'مقفول'),
              (
                label: 'آخر نسخة',
                value: last != null ? svc.lastBackupLabel : 'لسه مفيش'
              ),
            ],
          );
        }),
        gap,
        // ── حفظ تلقائي ──
        Obx(() {
          final svc = AutoBackupService();
          return _toggleCard(
            t,
            rx: svc.enabled,
            icon: Icons.cloud_sync_rounded,
            color: indigo,
            title: 'الحفظ التلقائي',
            onHint: svc.lastBackupTime.value != null
                ? svc.lastBackupLabel
                : 'يحفظ تلقائياً بعد كل تغيير',
            offHint: 'يحفظ نسخة بعد كل تغيير',
            set: (v) async => await svc.setEnabled(v),
          );
        }),
        gap,
        // ── إجراءات النسخ: كروت ──
        _plainSectionBlock(
          t,
          'النسخ الاحتياطي',
          Icons.storage_rounded,
          indigo,
          _cardGrid([
            _actionCard(
              t,
              icon: Icons.backup_rounded,
              color: indigo,
              title: 'إنشاء نسخة احتياطية',
              hint: 'نسخ كامل لقاعدة البيانات مع خيار المشاركة',
              onTap: () {
                if (!requireLicenseFeature(
                    context,
                    Get.find<LicenseController>().canBackup,
                    'النسخ الاحتياطي غير متاح في الفترة التجريبية — قم بالترقية')) {
                  return;
                }
                _handleEnhancedBackup(context);
              },
            ),
            _actionCard(
              t,
              icon: Icons.restore_rounded,
              color: const Color(0xFF06B6D4),
              title: 'استعادة نسخة احتياطية',
              hint: 'استعادة البيانات من نسخة محفوظة',
              onTap: () {
                if (!requireLicenseFeature(
                    context,
                    Get.find<LicenseController>().canBackup,
                    'استعادة النسخ الاحتياطية غير متاحة في الفترة التجريبية — قم بالترقية')) {
                  return;
                }
                if (!requireTeamOwnerIfTeamMode(context)) return;
                _handleRestoreBackup(context);
              },
            ),
            _actionCard(
              t,
              icon: Icons.folder_open_rounded,
              color: const Color(0xFFF59E0B),
              title: 'إدارة النسخ الاحتياطية',
              hint: 'عرض وحذف النسخ القديمة',
              onTap: () => _handleManageBackups(context),
            ),
            // spec 037 — نسخ احتياطي سحابي (Google Drive شخصي)
            _actionCard(
              t,
              icon: Icons.cloud_rounded,
              color: const Color(0xFF10B981),
              title: 'النسخ السحابي (Google Drive)',
              hint: 'رفع تلقائي لنسخة على درايفك الشخصي',
              onTap: () => _handleCloudBackup(context),
            ),
          ]),
        ),
        // spec 052 — صحة البيانات (اكتشاف ودمج المكرّر): للمالك/المدرس
        // فقط — المساعد في وضع الفريق ما يشوفهاش.
        Obx(() {
          final team = TeamModeService();
          if (team.isEnabled.value && !team.isOwner.value) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: _settingsCard(
              t,
              _buildNavTile(
                context,
                isDark,
                icon: Icons.health_and_safety_rounded,
                iconColor: const Color(0xFF0EA5E9),
                title: 'صحة البيانات',
                subtitle: 'اكتشاف ودمج الطلاب والمجموعات المكرّرة',
                onTap: () => Get.to(() => const DataHealthPage()),
              ),
            ),
          );
        }),
        gap,
        // ── منطقة الخطر: خلفية حمراء فاتحة وحد أحمر ──
        _plainSectionBlock(
          t,
          'منطقة الخطر',
          Icons.warning_amber_rounded,
          const Color(0xFFEF4444),
          Material(
            color: t.dangerSoft,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.panel),
              side: BorderSide(color: t.danger.withValues(alpha: 0.5)),
            ),
            child: Column(children: [
              _buildNavTile(
                context,
                isDark,
                icon: Icons.auto_delete_outlined,
                iconColor: const Color(0xFFF59E0B),
                title: 'حذف سجلّات بمدى تواريخ',
                subtitle:
                    'احذف حضور/دفعات/امتحانات فترة معيّنة — مع نسخة احتياطية إجبارية',
                onTap: () => Get.to(() => const DeleteRecordsPage()),
              ),
              _buildDivider(isDark),
              _buildNavTile(
                context,
                isDark,
                icon: Icons.delete_forever_rounded,
                iconColor: const Color(0xFFEF4444),
                title: 'حذف جميع البيانات',
                subtitle:
                    'اختار الأقسام اللي تحذفها (أو الكل) — مع نسخة احتياطية إجبارية',
                titleColor: t.danger,
                onTap: () {
                  if (!requireTeamOwnerIfTeamMode(context)) return;
                  Get.to(() => const WipeDataPage());
                },
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
