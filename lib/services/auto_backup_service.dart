// lib/services/auto_backup_service.dart
// حفظ تلقائي للبيانات بعد كل تغيير (debounced 20 ثانية)

import 'dart:async';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:active_class/services/backup_service.dart';

class AutoBackupService {
  static final AutoBackupService _instance = AutoBackupService._internal();
  factory AutoBackupService() => _instance;
  AutoBackupService._internal();

  static const String _keyEnabled        = 'auto_backup_enabled';
  static const String _keyLastBackup     = 'auto_backup_last_time';
  static const String _keyExternalFiles  = 'auto_backup_external_files';
  static const int    _keepExternalCount = 5;

  /// هل الحفظ التلقائي مفعّل؟ — مفعّل افتراضيًا (المستخدم يقدر يوقفه يدويًا)
  final RxBool enabled = true.obs;

  /// وقت آخر نسخة احتياطية تلقائية
  final Rxn<DateTime> lastBackupTime = Rxn<DateTime>();

  /// نص وقت آخر حفظ — "الساعة HH:mm" أو "لم يتم الحفظ بعد"
  String get lastBackupLabel {
    final t = lastBackupTime.value;
    if (t == null) return 'لم يتم الحفظ بعد';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tDate = DateTime(t.year, t.month, t.day);
    final timeStr = DateFormat('HH:mm').format(t);
    if (tDate == today) return 'آخر حفظ اليوم الساعة $timeStr';
    return 'آخر حفظ ${DateFormat('MM/dd').format(t)} الساعة $timeStr';
  }

  Timer? _debounce;
  bool   _running = false;

  // ─── تهيئة ───────────────────────────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool(_keyEnabled) ?? true;
    final saved = prefs.getString(_keyLastBackup);
    if (saved != null) {
      lastBackupTime.value = DateTime.tryParse(saved);
    }
  }

  // ─── تغيير حالة التفعيل ─────────────────────────────────────────
  Future<void> setEnabled(bool v) async {
    enabled.value = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, v);
  }

  // ─── استدعاء بعد كل عملية تغيير على DB ─────────────────────────
  void onDataChanged() {
    if (!enabled.value) return;
    // debounce: انتظر 20 ثانية من آخر تغيير قبل الحفظ
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 20), _runBackup);
  }

  // ─── تشغيل الحفظ الفعلي ─────────────────────────────────────────
  Future<void> _runBackup() async {
    if (_running) return;
    _running = true;
    try {
      final result = await BackupService().createBackup();
      if (result.success) {
        // نظّف النسخ الداخلية الزائدة عن سقف الاحتفاظ الافتراضي (5) —
        // بدون ده النسخ الداخلية (Documents/backups) كانت بتتراكم من
        // غير حد أقصى، لأن cleanOldBackups() قبل كده مكنتش بتتنادى
        // إلا يدويًا من زرار في شاشة الإعدادات.
        await BackupService().cleanOldBackups();

        // احفظ نسخة كمان في Downloads (تخزين خارجي) عشان تفضل موجودة
        // حتى لو التطبيق اتلغى تثبيته — النسخة الداخلية في Documents
        // بتتمسح مع التطبيق، الخارجية لأ.
        final uri = await BackupService()
            .saveToDownloads(result.localPath!, result.fileName!);
        if (uri != null) {
          await _cleanOldExternalBackups(result.fileName!);
        }

        lastBackupTime.value = DateTime.now();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            _keyLastBackup, lastBackupTime.value!.toIso8601String());
      }
    } catch (_) {
      // فشل صامت — لا نزعج المستخدم بـ toast في الخلفية
    } finally {
      _running = false;
    }
  }

  // ─── تنظيف نسخ Downloads القديمة ─────────────────────────────────
  // مفيش API في media_store_plus لسرد ملفات مجلد خارجي، فبنسجّل أسماء
  // الملفات اللي إحنا نفسنا حفظناها في SharedPreferences، وبنمسح
  // الأقدم لما العدد يتعدى [_keepExternalCount]. النسخ اليدوي (زرار
  // "حفظ في Downloads" في الإعدادات) مش داخل في العد ده — بيتمسح إحنا
  // بس اللي بنحفظه تلقائيًا.
  // (النسخ الداخلية في Documents/backups بتتنظف بنفس المنطق، بس عبر
  // BackupService().cleanOldBackups() المستدعاة فوق في _runBackup —
  // مفيش داعي لآلية تتبّع منفصلة زي دي لأن getLocalBackups() بيسرد
  // الملفات مباشرة من نظام الملفات المحلي.)
  Future<void> _cleanOldExternalBackups(String newFileName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyExternalFiles) ?? <String>[];
      list.add(newFileName);

      while (list.length > _keepExternalCount) {
        final oldest = list.removeAt(0);
        try {
          await MediaStore.ensureInitialized();
          MediaStore.appFolder = 'ActiveClass';
          await MediaStore().deleteFile(
            fileName: oldest,
            dirType: DirType.download,
            dirName: DirName.download,
          );
        } catch (_) {}
      }

      await prefs.setStringList(_keyExternalFiles, list);
    } catch (_) {}
  }

  // ─── تنظيف ───────────────────────────────────────────────────────
  void dispose() {
    _debounce?.cancel();
  }
}
