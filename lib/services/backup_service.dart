// lib/services/backup_service.dart
// نظام Backup & Restore كامل وموثوق

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/services/database_service.dart';

// ══════════════════════════════════════════════════════════════════
//  BackupResult — نتيجة عملية النسخ
// ══════════════════════════════════════════════════════════════════
class BackupResult {
  final bool success;
  final String? localPath;   // مسار داخل Documents (للاستعادة لاحقاً)
  final String? downloadsUri; // URI في Downloads (للمشاركة)
  final String? error;
  final String? fileSize;

  BackupResult.success({
    required this.localPath,
    this.downloadsUri,
    this.fileSize,
  })  : success = true,
        error = null;

  BackupResult.failure(this.error)
      : success = false,
        localPath = null,
        downloadsUri = null,
        fileSize = null;
}

// ══════════════════════════════════════════════════════════════════
//  BackupInfo — معلومات ملف نسخة احتياطية
// ══════════════════════════════════════════════════════════════════
class BackupInfo {
  final String path;
  final String name;
  final DateTime date;
  final int sizeBytes;

  BackupInfo({
    required this.path,
    required this.name,
    required this.date,
    required this.sizeBytes,
  });

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes بايت';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} كيلوبايت';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} ميجابايت';
  }

  String get dateLabel =>
      DateFormat('yyyy-MM-dd  HH:mm', 'ar').format(date);
}

// ══════════════════════════════════════════════════════════════════
//  BackupService
// ══════════════════════════════════════════════════════════════════
class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  // مجلد النسخ داخل Documents — يبقى حتى بعد إعادة التشغيل
  Future<Directory> get _backupsDir async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'backups'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  // مجلد مؤقت لعمليات الـ MediaStore
  Future<Directory> get _tempDir async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory(p.join(tmp.path, 'backup_tmp'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  // ──────────────────────────────────────────────────────────────
  //  createBackup — إنشاء نسخة احتياطية
  //  تُحفظ في Documents (دائمة) + Downloads (للمشاركة)
  // ──────────────────────────────────────────────────────────────
  Future<BackupResult> createBackup() async {
    try {
      final dbPath = await getDatabasesPath();
      final dbFile = File(p.join(dbPath, DATABASE_NAME));
      if (!dbFile.existsSync()) {
        return BackupResult.failure('قاعدة البيانات غير موجودة');
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName  = 'active_class_backup_$timestamp.db';

      // 1️⃣ حفظ دائم في Documents
      final docsDir  = await _backupsDir;
      final localPath = p.join(docsDir.path, fileName);
      await dbFile.copy(localPath);

      final sizeBytes = File(localPath).lengthSync();
      final sizeLabel = _sizeLabel(sizeBytes);

      // 2️⃣ محاولة حفظ في Downloads (اختياري — لا يفشل الكل لو فشل هذا)
      String? downloadsUri;
      try {
        final tmpDir  = await _tempDir;
        final tmpPath = p.join(tmpDir.path, fileName);
        await File(localPath).copy(tmpPath);

        await MediaStore.ensureInitialized();
        MediaStore.appFolder = 'ActiveClass';
        final saveInfo = await MediaStore().saveFile(
          tempFilePath: tmpPath,
          dirType: DirType.download,
          dirName: DirName.download,
        );
        downloadsUri = saveInfo?.uri.toString();
        try { File(tmpPath).deleteSync(); } catch (_) {}
      } catch (_) {
        // فشل Downloads لا يُلغي العملية
      }

      return BackupResult.success(
        localPath: localPath,
        downloadsUri: downloadsUri,
        fileSize: sizeLabel,
      );
    } catch (e) {
      return BackupResult.failure('فشل إنشاء النسخة: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  getLocalBackups — قائمة النسخ المحفوظة في Documents
  // ──────────────────────────────────────────────────────────────
  Future<List<BackupInfo>> getLocalBackups() async {
    try {
      final dir   = await _backupsDir;
      final files = dir.listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.db'))
          .toList()
        ..sort((a, b) =>
            b.statSync().modified.compareTo(a.statSync().modified));

      return files.map((f) {
        final stat = f.statSync();
        return BackupInfo(
          path:      f.path,
          name:      p.basename(f.path),
          date:      stat.modified,
          sizeBytes: stat.size,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  pickBackupFile — اختيار ملف .db من أي مكان على الجهاز
  // ──────────────────────────────────────────────────────────────
  Future<String?> pickBackupFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,           // نوع مخصص
        dialogTitle: 'اختر ملف النسخة الاحتياطية (.db)',
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.first;
      // تحقق أن الامتداد .db
      if (file.extension?.toLowerCase() != 'db') return 'INVALID_EXT';
      return file.path;
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  restoreBackup — استعادة من مسار ملف
  //  يُغلق DB → ينسخ الملف → يُعيد فتح DB
  // ──────────────────────────────────────────────────────────────
  Future<bool> restoreBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      if (!backupFile.existsSync()) {
        throw Exception('الملف غير موجود: $backupPath');
      }

      // تحقق بسيط أن الملف SQLite صحيح
      final header = await backupFile.openRead(0, 16).first;
      final magic  = String.fromCharCodes(header.take(6));
      if (!magic.startsWith('SQLite')) {
        throw Exception('الملف ليس قاعدة بيانات SQLite صالحة');
      }

      // أغلق الاتصال الحالي
      await DatabaseService().close();

      final dbPath     = await getDatabasesPath();
      final targetPath = p.join(dbPath, DATABASE_NAME);

      // نسخ احتياطية مؤقتة من DB الحالية (احتياط)
      final currentDb = File(targetPath);
      if (currentDb.existsSync()) {
        await currentDb.copy('$targetPath.bak');
      }

      // استبدال قاعدة البيانات
      await backupFile.copy(targetPath);

      // حذف الـ .bak إذا نجح كل شيء
      try { File('$targetPath.bak').deleteSync(); } catch (_) {}

      return true;
    } catch (_) {
      // محاولة استعادة الـ .bak لو فشل
      try {
        final dbPath  = await getDatabasesPath();
        final bakFile = File(p.join(dbPath, '$DATABASE_NAME.bak'));
        if (bakFile.existsSync()) {
          await bakFile.copy(p.join(dbPath, DATABASE_NAME));
          await bakFile.delete();
        }
      } catch (_) {}
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  shareBackup — مشاركة ملف نسخة احتياطية
  // ──────────────────────────────────────────────────────────────
  Future<void> shareBackup(String localPath) async {
    try {
      final file = File(localPath);
      if (!file.existsSync()) return;
      await Share.shareXFiles(
        [XFile(localPath)],
        text: 'نسخة احتياطية من تطبيق Active Class\n${p.basename(localPath)}',
      );
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────────────────
  //  deleteBackup — حذف نسخة
  // ──────────────────────────────────────────────────────────────
  Future<bool> deleteBackup(String path) async {
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  cleanOldBackups — حذف النسخ القديمة
  // ──────────────────────────────────────────────────────────────
  Future<int> cleanOldBackups({int keepCount = 5}) async {
    try {
      final backups = await getLocalBackups();
      if (backups.length <= keepCount) return 0;
      final toDelete = backups.skip(keepCount).toList();
      for (final b in toDelete) {
        await deleteBackup(b.path);
      }
      return toDelete.length;
    } catch (_) {
      return 0;
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  Helpers
  // ──────────────────────────────────────────────────────────────
  static String _sizeLabel(int bytes) {
    if (bytes < 1024) return '$bytes بايت';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} كيلوبايت';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} ميجابايت';
  }

  // للتوافق مع الكود القديم
  String getBackupFileSize(String path) {
    try {
      return _sizeLabel(File(path).lengthSync());
    } catch (_) {
      return 'غير معروف';
    }
  }
}
