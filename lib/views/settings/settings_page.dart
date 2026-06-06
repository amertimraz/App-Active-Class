// lib/views/settings/settings_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/theme_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/widgets/custom_dialogs.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/backup_service.dart';
import 'package:active_class/models/student_model.dart';

import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:async';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // Helper method to build section titles with consistent styling
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.find();
    final SettingsController settingsController = Get.find();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(PADDING_NORMAL),
        children: [
            // Appearance Section
            Text(
              'المظهر',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: SPACING_NORMAL),
            Card(
              child: ListTile(
                leading: const Icon(Icons.dark_mode),
                title: const Text('الوضع الليلي'),
                trailing: Obx(
                  () => Switch(
                    value: themeController.isDarkMode.value,
                    onChanged: (value) {
                      themeController.setTheme(value);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: SPACING_LARGE),

            // Notifications Section
            Text(
              'الإشعارات',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: SPACING_NORMAL),
            Card(
              child: ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('إعدادات الإشعارات'),
                subtitle: const Text('تخصيص إشعارات التذكير'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Get.toNamed(ROUTE_NOTIFICATION_SETTINGS),
              ),
            ),
            const SizedBox(height: SPACING_LARGE),

            // Currency Section
            Text(
              'العملة',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: SPACING_NORMAL),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: PADDING_NORMAL, vertical: PADDING_NORMAL),
                child: Row(
                  children: [
                    const Icon(Icons.attach_money),
                    const SizedBox(width: SPACING_NORMAL),
                    Expanded(
                      child: Obx(() {
                        final items = SettingsController.supported;
                        return DropdownButtonFormField<String>(
                          initialValue: settingsController.currencyCode.value,
                          decoration: const InputDecoration(labelText: 'اختر العملة'),
                          items: items
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.code,
                                  child: Text('${c.nameAr} (${c.symbol})'),
                                ),
                              )
                              .toList(),
                          onChanged: (code) {
                            if (code != null) settingsController.setCurrency(code);
                            ToastHelper.success('تم تعيين العملة إلى: ${settingsController.currentCurrency.nameAr}', title: 'تم التغيير');
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: SPACING_LARGE),

            // Time format Section
            _buildSectionTitle(context, 'التوقيت'),
            const SizedBox(height: SPACING_NORMAL),
            Card(
              child: Obx(() => ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('نظام الساعة'),
                subtitle: Text(settingsController.use24hFormat.value ? '24 ساعة' : '12 ساعة'),
                trailing: Switch(
                  value: settingsController.use24hFormat.value,
                  onChanged: (v) async {
                    await settingsController.setUse24hFormat(v);
                  },
                ),
              )),
            ),
            const SizedBox(height: SPACING_LARGE),

            // Country dial Section
                        _buildSectionTitle(context, 'رمز الدولة للواتساب'),
            const SizedBox(height: SPACING_NORMAL),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: PADDING_NORMAL, vertical: PADDING_NORMAL),
                child: Row(
                  children: [
                    const Icon(Icons.flag),
                    const SizedBox(width: SPACING_NORMAL),
                    Expanded(
                      child: Obx(() {
                        final items = SettingsController.arabCountryDials;
                        return DropdownButtonFormField<String>(
                          initialValue: settingsController.countryDial.value,
                          decoration: const InputDecoration(labelText: 'اختر الدولة'),
                          items: items
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.dial,
                                  child: Text('${c.nameAr} (+${c.dial})'),
                                ),
                              )
                              .toList(),
                          onChanged: (dial) async {
                            if (dial != null) await settingsController.setCountryDial(dial);
                            ToastHelper.success('تم تعيين رمز الدولة: +${settingsController.countryDial.value}', title: 'تم التغيير');
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: SPACING_LARGE),

            // Teacher Info Section
                        _buildSectionTitle(context, 'معلومات المعلم'),
            const SizedBox(height: SPACING_NORMAL),
            Obx(() {
              final fullName = settingsController.teacherFullName.value.trim();
              final avatarPath = settingsController.teacherAvatarPath.value.trim();
              String initial() {
                if (fullName.isNotEmpty) return fullName.characters.first.toUpperCase();
                return 'م';
              }
              ImageProvider? avatarImage;
              if (avatarPath.isNotEmpty) {
                final f = File(avatarPath);
                if (f.existsSync()) {
                  avatarImage = FileImage(f);
                }
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(PADDING_NORMAL),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final picker = ImagePicker();
                              final x = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
                              if (x != null) {
                                settingsController.setTeacherAvatarPath(x.path);
                                await settingsController.saveTeacherInfo();
                              }
                            },
                            child: CircleAvatar(
                              radius: 32,
                              backgroundImage: avatarImage,
                              backgroundColor: AppTheme.primaryColor,
                              child: avatarImage == null
                                  ? Text(
                                      initial(),
                                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: SPACING_NORMAL),
                          Expanded(
                            child: Column(
                              children: [
                                TextFormField(
                                  initialValue: settingsController.teacherFullName.value,
                                  decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                                  onChanged: settingsController.setTeacherFullName,
                                  textDirection: ui.TextDirection.rtl,
                                ),
                                const SizedBox(height: SPACING_SMALL),
                                TextFormField(
                                  initialValue: settingsController.teacherSpecialization.value,
                                  decoration: const InputDecoration(labelText: 'التخصص'),
                                  onChanged: settingsController.setTeacherSpecialization,
                                  textDirection: ui.TextDirection.rtl,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: SPACING_NORMAL),
                      TextFormField(
                        initialValue: settingsController.teacherPhone.value,
                        decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                        keyboardType: TextInputType.phone,
                        onChanged: settingsController.setTeacherPhone,
                        textDirection: ui.TextDirection.rtl,
                      ),
                      const SizedBox(height: SPACING_SMALL),
                      TextFormField(
                        initialValue: settingsController.teacherEmail.value,
                        decoration: const InputDecoration(labelText: 'البريد الإلكتروني (اختياري)'),
                        keyboardType: TextInputType.emailAddress,
                        onChanged: settingsController.setTeacherEmail,
                        textDirection: ui.TextDirection.rtl,
                      ),
                      const SizedBox(height: SPACING_SMALL),
                      TextFormField(
                        initialValue: settingsController.teacherSchool.value,
                        decoration: const InputDecoration(labelText: 'المدرسة / المركز (اختياري)'),
                        onChanged: settingsController.setTeacherSchool,
                        textDirection: ui.TextDirection.rtl,
                      ),
                      const SizedBox(height: SPACING_SMALL),
                      TextFormField(
                        initialValue: settingsController.teacherAvatarPath.value,
                        decoration: const InputDecoration(labelText: 'رابط/مسار الصورة (اختياري)'),
                        onChanged: settingsController.setTeacherAvatarPath,
                        textDirection: ui.TextDirection.ltr,
                      ),
                      const SizedBox(height: SPACING_NORMAL),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await settingsController.saveTeacherInfo();
                            ToastHelper.success('تم حفظ معلومات المعلم');
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('حفظ'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: SPACING_LARGE),


            // Data Management Section
                        _buildSectionTitle(context, 'إدارة البيانات'),
            const SizedBox(height: SPACING_NORMAL),
            Card(
              child: ListTile(
                leading: const Icon(Icons.backup),
                title: const Text('النسخ الاحتياطي'),
                subtitle: const Text('حفظ البيانات في ملف JSON'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _handleBackup(context, settingsController),
              ),
            ),
            const SizedBox(height: SPACING_SMALL),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_upload),
                title: const Text('نسخ احتياطي محسّن'),
                subtitle: const Text('نسخ كامل لقاعدة البيانات'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _handleEnhancedBackup(context),
              ),
            ),
            const SizedBox(height: SPACING_SMALL),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_download),
                title: const Text('استعادة نسخة احتياطية'),
                subtitle: const Text('استعادة من نسخة محفوظة'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _handleRestoreBackup(context),
              ),
            ),
            const SizedBox(height: SPACING_SMALL),
            Card(
              child: ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('إدارة النسخ الاحتياطية'),
                subtitle: const Text('عرض وحذف النسخ القديمة'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _handleManageBackups(context),
              ),
            ),
            const SizedBox(height: SPACING_SMALL),
            Card(
              child: ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('حذف جميع البيانات'),
                subtitle: const Text('حذف نهائي - لا يمكن التراجع'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _handleDeleteAll(context, settingsController),
              ),
            ),
            const SizedBox(height: SPACING_LARGE),

            // About Section
                        _buildSectionTitle(context, 'عن التطبيق'),
            const SizedBox(height: SPACING_NORMAL),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('الإصدار'),
                    trailing: const Text('1.0.0'),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.build),
                    title: const Text('آخر تحديث'),
                    trailing: const Text('2025/01/15'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SPACING_LARGE),

            // Support Section
            Card(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: ListTile(
                leading: Icon(
                  Icons.help_outline,
                  color: AppTheme.primaryColor,
                ),
                title: const Text('المساعدة والدعم'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('جار العمل على قسم المساعدة')),
                  );
                },
              ),
            ),
            const SizedBox(height: SPACING_LARGE),

            // WhatsApp semi-automatic send
            Card(
              child: ListTile(
                leading: Icon(Icons.chat, color: Colors.green),
                title: const Text('إرسال تقارير الشهر عبر واتساب (شبه تلقائي)')
,
                subtitle: const Text('يفتح محادثة لكل ولي أمر بالنص، ثم اضغط إرسال'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _startWhatsappBatchSend(context, settingsController),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleBackup(BuildContext context, SettingsController settingsController) async {
    if (!context.mounted) return;
    LoadingDialog.show(context, message: 'جاري إنشاء النسخة الاحتياطية...');
    try {
      final path = await settingsController.backupData();
      if (!context.mounted) return;
      LoadingDialog.hide();
      SuccessDialog.show(
        context,
        title: 'تم النسخ الاحتياطي',
        message: 'تم حفظ الملف بنجاح:\n$path',
      );
    } catch (e) {
      LoadingDialog.hide();
      if (!context.mounted) return;
      ErrorDialog.show(
        context,
        title: 'فشل النسخ الاحتياطي',
        message: e.toString(),
      );
    }
  }

  void _handleDeleteAll(BuildContext context, SettingsController settingsController) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      ConfirmDeleteDialog.show(
        context,
        title: 'حذف جميع البيانات',
        message: 'هل أنت متأكد؟ سيتم حذف جميع البيانات بشكل نهائي ولا يمكن التراجع',
        onConfirm: () async {
          LoadingDialog.show(context, message: 'جاري الحذف...');
          try {
            await settingsController.deleteAllData();
            if (!context.mounted) return;
            LoadingDialog.hide();
            SuccessDialog.show(
              context,
              title: 'تم الحذف',
              message: 'تم حذف جميع البيانات بنجاح',
            );
          } catch (e) {
            LoadingDialog.hide();
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

  Future<void> _startWhatsappBatchSend(BuildContext context, SettingsController settings) async {
    final db = DatabaseService();
    LoadingDialog.show(context, message: 'تحضير الرسائل...');
    try {
      final students = await db.getAllStudents();
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1);
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      final end = nextMonth.subtract(const Duration(days: 1));



      final valid = students.where((s) => (s.guardianPhone ?? '').trim().isNotEmpty).toList();
      if (valid.isEmpty) {
        LoadingDialog.hide();
        ToastHelper.info('لا يوجد أولياء أمور بأرقام مسجلة');
        return;
      }

      LoadingDialog.hide();
      if (!context.mounted) return;
      final selected = await _pickRecipients(context, valid);
      if (selected == null || selected.isEmpty) return;

      String normalize(String input, String defaultDial) {
        var p = input.replaceAll(RegExp(r'[^0-9+]'), '');
        if (p.startsWith('+')) p = p.substring(1);
        if (p.startsWith('00')) p = p.substring(2);
        if (p.startsWith(defaultDial)) return p;
        if (RegExp(r'^[1-9][0-9]{6,}$').hasMatch(p)) return p;
        p = p.replaceFirst(RegExp(r'^0+'), '');
        return defaultDial + p;
      }

      for (int i = 0; i < selected.length; i++) {
        final s = selected[i];
        final rawPhone = s.guardianPhone!.trim();
        final phone = normalize(rawPhone, settings.countryDial.value);

        final monthLabel = DateFormat('MMMM yyyy', 'ar').format(start);
        final group = await db.getGroup(s.groupId);
        final groupName = group?.name ?? '-';

        final atts = await db.getAttendanceByStudent(s.id!);
        final pays = await db.getPaymentsByStudent(s.id!);

        final monthEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);
        final attsMonth = atts.where((a) => !a.date.isBefore(start) && !a.date.isAfter(monthEnd)).toList();
        final paysMonth = pays.where((p) => !p.date.isBefore(start) && !p.date.isAfter(monthEnd)).toList();

        final present = attsMonth.where((a) => a.status == ATTENDANCE_PRESENT).length;
        final absent = attsMonth.where((a) => a.status == ATTENDANCE_ABSENT).length;
        final total = present + absent;
        final percent = total == 0 ? 0.0 : (present / total) * 100.0;
        final totalPaid = paysMonth.fold<double>(0.0, (sum, p) => sum + p.amount);

        final attsSorted = List.of(attsMonth)..sort((a, b) => b.date.compareTo(a.date));
        final paysSorted = List.of(paysMonth)..sort((a, b) => b.date.compareTo(a.date));

        final buffer = StringBuffer()
          ..writeln('🧾 تقرير الشهر: $monthLabel')
          ..writeln('👤 الاسم: ${s.name}')
          ..writeln('🆔 الكود: ${s.code}')
          ..writeln('👥 المجموعة: $groupName')
          ..writeln('📅 بداية الحضور: ${FormatHelper.formatDate(s.attendanceStart ?? s.createdAt)}')
          ..writeln('')
          ..writeln('📊 الحضور: ✅ حاضر $present • ❌ غياب $absent • نسبة ${percent.toStringAsFixed(1)}%');

        if (attsSorted.isNotEmpty) {
          buffer.writeln('');
          buffer.writeln('📅 سجلات الحضور:');
          for (final a in attsSorted.take(10)) {
            final d = DateFormat('yyyy-MM-dd').format(a.date);
            final st = a.status == ATTENDANCE_PRESENT ? '✅ حاضر' : '❌ غياب';
            buffer.writeln('• $d — $st');
          }
          if (attsSorted.length > 10) buffer.writeln('• … ${attsSorted.length - 10} سجلات إضافية');
        }

        buffer
          ..writeln('')
          ..writeln('💰 المدفوعات: إجمالي ${FormatHelper.formatCurrency(totalPaid)}');

        if (paysSorted.isNotEmpty) {
          for (final p in paysSorted) {
            final d = DateFormat('yyyy-MM-dd').format(p.date);
            buffer.writeln('• $d — ${FormatHelper.formatCurrency(p.amount)}');
          }
        }

        final tName = settings.teacherFullName.value.trim();
        final tSpec = settings.teacherSpecialization.value.trim();
        if (tName.isNotEmpty || tSpec.isNotEmpty) {
          buffer
            ..writeln('')
            ..writeln('👨‍🏫 المعلم: ${tName.isNotEmpty ? tName : '-'}')
            ..writeln('📘 التخصص: ${tSpec.isNotEmpty ? tSpec : '-'}');
        }
        buffer
          ..writeln('')
          ..writeln('تم الإرسال من تطبيق Active Class');

        final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(buffer.toString())}');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        await _waitForResume();
      }
    } catch (e) {
      LoadingDialog.hide();
      ToastHelper.error('تعذر التحضير أو الإرسال');
    }
  }

  /// Enhanced backup: creates a full DB backup and offers sharing.
  Future<void> _handleEnhancedBackup(BuildContext context) async {
    final backupService = BackupService();
    LoadingDialog.show(context, message: 'جاري إنشاء النسخة الاحتياطية...');
    try {
      final backupPath = await backupService.createBackup();
      if (!context.mounted) return;
      LoadingDialog.hide();
      if (backupPath != null) {
        final fileSize = backupService.getBackupFileSize(backupPath);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تم إنشاء النسخة الاحتياطية'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المسار: $backupPath'),
                const SizedBox(height: 8),
                Text('الحجم: $fileSize'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('إغلاق'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  backupService.shareBackup(backupPath);
                  Navigator.of(ctx).pop();
                },
                icon: const Icon(Icons.share),
                label: const Text('مشاركة'),
              ),
            ],
          ),
        );
      } else {
        ToastHelper.error('فشل إنشاء النسخة الاحتياطية');
      }
    } catch (e) {
      LoadingDialog.hide();
      if (!context.mounted) return;
      ToastHelper.error('خطأ: ${e.toString()}');
    }
  }

  /// Restore from a selected backup file.
  Future<void> _handleRestoreBackup(BuildContext context) async {
    final backupService = BackupService();
    LoadingDialog.show(context, message: 'جاري تحميل النسخ الاحتياطية...');
    try {
      final backups = await backupService.getBackupFiles();
      if (!context.mounted) return;
      LoadingDialog.hide();

      if (backups.isEmpty) {
        ToastHelper.info('لا توجد نسخ احتياطية محفوظة');
        return;
      }

      // Show a simple selection dialog similar to manage backups but only for restore.
      final selected = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('اختر نسخة لاستعادة'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: backups.length,
              itemBuilder: (_, index) {
                final backup = backups[index];
                final fileName = backup.path.split('/').last;
                final fileSize = backupService.getBackupFileSize(backup.path);
                final modified = backup.statSync().modified;
                final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(modified);
                return ListTile(
                  title: Text(fileName),
                  subtitle: Text('$dateStr - $fileSize'),
                  onTap: () => Navigator.of(ctx).pop(backup.path),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      );

      if (selected == null) return;

      if (!context.mounted) return;
      LoadingDialog.show(context, message: 'جاري الاستعادة...');
      final success = await backupService.restoreBackup(selected);
      LoadingDialog.hide();
      if (success) {
        ToastHelper.success('تم استعادة النسخة الاحتياطية بنجاح');
        Get.offAllNamed(ROUTE_HOME);
      } else {
        ToastHelper.error('فشل استعادة النسخة الاحتياطية');
      }
    } catch (e) {
      LoadingDialog.hide();
      if (!context.mounted) return;
      ToastHelper.error('خطأ: ${e.toString()}');
    }
  }

  /// Manage backups (list, delete, restore) – unchanged logic retained.
  // Existing _handleManageBackups implementation remains as before.
  Future<void> _handleManageBackups(BuildContext context) async {
  final backupService = BackupService();
  LoadingDialog.show(context, message: 'جاري تحميل النسخ الاحتياطية...');
  try {
    final backups = await backupService.getBackupFiles();
    if (!context.mounted) return;
    LoadingDialog.hide();
    
    if (backups.isEmpty) {
      ToastHelper.info('لا توجد نسخ احتياطية محفوظة');
      return;
    }
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إدارة النسخ الاحتياطية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('عدد النسخ: ${backups.length}'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('حذف النسخ القديمة'),
                    content: const Text('هل تريد حذف النسخ الاحتياطية الأقدم من 30 يوم؟'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('إلغاء'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        child: const Text('حذف'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await backupService.cleanOldBackups();
                  if (!context.mounted) return;
                  Navigator.of(ctx).pop();
                  ToastHelper.success('تم حذف النسخ القديمة');
                  _handleManageBackups(context);
                }
              },
              icon: const Icon(Icons.cleaning_services),
              label: const Text('حذف النسخ القديمة (أكثر من 30 يوم)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  } catch (e) {
    LoadingDialog.hide();
    if (!context.mounted) return;
    ToastHelper.error('خطأ: ${e.toString()}');
  }
}
}

Future<List<Student>?> _pickRecipients(BuildContext context, List<Student> all) async {
  return await showDialog<List<Student>>(
    context: context,
    builder: (ctx) {
      List<Student> items = List.of(all)..sort((a, b) => a.name.compareTo(b.name));
      List<bool> sel = List<bool>.filled(items.length, true);
      bool selectAll = true;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('اختر أولياء الأمور'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  value: selectAll,
                  onChanged: (v) {
                    setState(() {
                      selectAll = v ?? false;
                      for (int i = 0; i < sel.length; i++) {
                        sel[i] = selectAll;
                      }
                    });
                  },
                  title: const Text('تحديد الكل'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const Divider(height: 0),
                SizedBox(
                  height: 360,
                  width: double.maxFinite,
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final s = items[i];
                      return CheckboxListTile(
                        value: sel[i],
                        onChanged: (v) => setState(() => sel[i] = v ?? false),
                        title: Text(s.name),
                        subtitle: Text(s.guardianPhone ?? '-'),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: sel.any((e) => e)
                  ? () {
                      final chosen = <Student>[];
                      for (int i = 0; i < items.length; i++) {
                        if (sel[i]) chosen.add(items[i]);
                      }
                      Navigator.of(ctx).pop(chosen);
                    }
                  : null,
              child: const Text('ابدأ الإرسال'),
            )
          ],
        ),
      );
    },
  );
}

class _ResumeObserver extends WidgetsBindingObserver {
  final void Function() onResume;
  _ResumeObserver(this.onResume);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume();
    }
  }
}

Future<void> _waitForResume() {
  final c = Completer<void>();
  late _ResumeObserver obs;
  obs = _ResumeObserver(() {
    WidgetsBinding.instance.removeObserver(obs);
    if (!c.isCompleted) c.complete();
  });
  WidgetsBinding.instance.addObserver(obs);
  return c.future;
}

// دالة عامة لاستدعاء الإرسال الحالي عند الحاجة (لا تغيّر منطق الإرسال)
Future<void> sendMonthlyReportsViaWhatsAppAuto(BuildContext context) async {
  final SettingsController settingsController = Get.find();
  await const SettingsPage()._startWhatsappBatchSend(context, settingsController);
}
