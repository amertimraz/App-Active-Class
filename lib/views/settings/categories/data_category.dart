part of '../settings_page.dart';

// spec 051 — فئة «البيانات والنسخ الاحتياطي»

class _DataCategoryPage extends StatelessWidget {
  const _DataCategoryPage({this.highlightId});

  /// معرّف عنصر من نتيجة بحث (spec 051) — بيتميّز بشريط في أول الصفحة.
  final String? highlightId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final SettingsController settings = Get.find();
    return _CategoryScaffold(
      title: 'البيانات والنسخ الاحتياطي',
      highlightId: highlightId,
      children: [
        _buildSection(
          context,
          isDark,
          title: 'النسخ الاحتياطي',
          icon: Icons.storage_rounded,
          color: const Color(0xFF4F46E5),
          children: [
            // ── حفظ تلقائي ─────────────────────────────
            Obx(() {
              final svc = AutoBackupService();
              return _buildSwitchTile(
                context,
                isDark,
                icon: Icons.cloud_sync_rounded,
                iconColor: const Color(0xFF4F46E5),
                title: 'الحفظ التلقائي',
                subtitle: svc.enabled.value
                    ? svc.lastBackupTime.value != null
                        ? svc.lastBackupLabel
                        : 'يحفظ تلقائياً بعد كل تغيير'
                    : 'يحفظ نسخة بعد كل تغيير',
                rxValue: svc.enabled,
                onChanged: (v) => svc.setEnabled(v),
              );
            }),
            _buildDivider(isDark),
            _buildNavTile(
              context,
              isDark,
              icon: Icons.backup_rounded,
              iconColor: const Color(0xFF4F46E5),
              title: 'إنشاء نسخة احتياطية',
              subtitle: 'نسخ كامل لقاعدة البيانات مع خيار المشاركة',
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
            _buildDivider(isDark),
            _buildNavTile(
              context,
              isDark,
              icon: Icons.restore_rounded,
              iconColor: const Color(0xFF06B6D4),
              title: 'استعادة نسخة احتياطية',
              subtitle: 'استعادة البيانات من نسخة محفوظة',
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
            _buildDivider(isDark),
            _buildNavTile(
              context,
              isDark,
              icon: Icons.folder_open_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: 'إدارة النسخ الاحتياطية',
              subtitle: 'عرض وحذف النسخ القديمة',
              onTap: () => _handleManageBackups(context),
            ),
            _buildDivider(isDark),
            // spec 037 — نسخ احتياطي سحابي (Google Drive شخصي)
            _buildNavTile(
              context,
              isDark,
              icon: Icons.cloud_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'النسخ السحابي (Google Drive)',
              subtitle: 'رفع تلقائي لنسخة احتياطية على درايفك الشخصي',
              onTap: () => _handleCloudBackup(context),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildSection(
          context,
          isDark,
          title: 'منطقة الخطر',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFEF4444),
          children: [
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
              subtitle: 'حذف نهائي — لا يمكن التراجع',
              titleColor: const Color(0xFFEF4444),
              onTap: () {
                if (!requireTeamOwnerIfTeamMode(context)) return;
                _handleDeleteAll(context, settings);
              },
            ),
          ],
        ),
      ],
    );
  }
}
