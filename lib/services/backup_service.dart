// lib/services/backup_service.dart
// نظام Backup & Restore كامل وموثوق

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/services/database_service.dart';

// نفس مفتاح teacher_avatar_path في SettingsController — البادج ده لازم
// يفضل متطابق مع _keyTeacherAvatar هناك (القيمة نفسها، مش الاستيراد،
// عشان نفضل نقدر نقرا/نكتب الإعداد من غير اعتماد BackupService على
// GetX/SettingsController).
const String _kTeacherAvatarSettingKey = 'teacher_avatar_path';

// ══════════════════════════════════════════════════════════════════
//  BackupResult — نتيجة عملية النسخ
// ══════════════════════════════════════════════════════════════════
class BackupResult {
  final bool success;
  final String? localPath;   // مسار داخل Documents (للاستعادة لاحقاً)
  final String? fileName;    // اسم الملف (لعملية حفظ Downloads اللاحقة)
  final String? error;
  final String? fileSize;

  BackupResult.success({
    required this.localPath,
    required this.fileName,
    this.fileSize,
  })  : success = true,
        error = null;

  BackupResult.failure(this.error)
      : success = false,
        localPath = null,
        fileName = null,
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
  //  createBackup — إنشاء نسخة احتياطية داخل Documents (دائمة)
  //  عملية نسخ ملف محلي سريعة فقط — الحفظ الإضافي في Downloads
  //  منفصل في saveToDownloads() عشان ميجمّدش الواجهة (شوف تعليقها).
  // ──────────────────────────────────────────────────────────────
  //  النسخة بقت ملف .zip (بدل .db خام) عشان تشمل كمان:
  //  - shared_prefs.json: كل مفاتيح SharedPreferences (فيها جلسة تسجيل
  //    دخول وضع الفريق — Supabase بيخزّنها هناك مش في قاعدة البيانات،
  //    فمن غيرها المستخدم لازم يسجّل دخول تاني بعد أي استعادة).
  //  - avatar.<ext>: بايتات صورة المعلم الفعلية (مش مجرد مسار — المسار
  //    القديم كان بيشاور على كاش الجاليري اللي ممكن يتمسح في أي وقت).
  //  ملفات .db القديمة (من نسخ سابقة قبل التعديل ده) لسه مدعومة في
  //  restoreBackup تحت — بلا كسر توافق رجعي.
  Future<BackupResult> createBackup() async {
    try {
      final dbPath = await getDatabasesPath();
      final dbFile = File(p.join(dbPath, DATABASE_NAME));
      if (!dbFile.existsSync()) {
        return BackupResult.failure('قاعدة البيانات غير موجودة');
      }

      // تفريغ أي كتابات معلّقة في الـ WAL جوّه ملف القاعدة الرئيسي قبل
      // النسخ — من غير كده لو القاعدة في وضع WAL، آخر التعديلات (مثلاً
      // امتحان أو درجات اتسجّلت للتو) بتفضل في active_class.db-wal
      // والنسخة بتطلع ناقصاها. لا ضرر في وضع journal العادي.
      try {
        final db = await DatabaseService().database;
        await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      } catch (_) {}

      final archive = Archive();
      final dbBytes = await dbFile.readAsBytes();
      archive.addFile(ArchiveFile(DATABASE_NAME, dbBytes.length, dbBytes));

      try {
        final prefs = await SharedPreferences.getInstance();
        final dump = <String, dynamic>{
          for (final k in prefs.getKeys()) k: prefs.get(k),
        };
        final prefsBytes = utf8.encode(jsonEncode(dump));
        archive.addFile(
            ArchiveFile('shared_prefs.json', prefsBytes.length, prefsBytes));
      } catch (_) {
        // فشل قراءة SharedPreferences مايوقفش النسخة الاحتياطية بالكامل
        // — الـDB أهم جزء وهي نجحت بالفعل فوق.
      }

      try {
        final avatarPath = await DatabaseService().getSetting(_kTeacherAvatarSettingKey);
        if (avatarPath != null && avatarPath.isNotEmpty) {
          final avatarFile = File(avatarPath);
          if (avatarFile.existsSync()) {
            final avatarBytes = await avatarFile.readAsBytes();
            final ext = p.extension(avatarPath);
            archive.addFile(ArchiveFile('avatar$ext', avatarBytes.length, avatarBytes));
          }
        }
      } catch (_) {}

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        return BackupResult.failure('فشل ضغط النسخة الاحتياطية');
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName  = 'active_class_backup_$timestamp.zip';

      final docsDir  = await _backupsDir;
      final localPath = p.join(docsDir.path, fileName);
      await File(localPath).writeAsBytes(zipBytes);

      final sizeBytes = File(localPath).lengthSync();
      final sizeLabel = _sizeLabel(sizeBytes);

      return BackupResult.success(
        localPath: localPath,
        fileName:  fileName,
        fileSize:  sizeLabel,
      );
    } catch (e) {
      return BackupResult.failure('فشل إنشاء النسخة: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  saveToDownloads — نسخ اختياري لملف Downloads/ActiveClass عبر
  //  MediaStore. على بعض أجهزة MIUI/Xiaomi، استعلامات MediaStore
  //  بتاخد ثواني على الـ main thread وتجمّد الواجهة بالكامل (بما
  //  فيها شاشة "جاري التحميل") — لذلك بننفذها بعد إغلاق شاشة
  //  التحميل وعرض النجاح، مش جوه createBackup() نفسها.
  // ──────────────────────────────────────────────────────────────
  Future<String?> saveToDownloads(String localPath, String fileName) async {
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
      try { File(tmpPath).deleteSync(); } catch (_) {}
      return saveInfo?.uri.toString();
    } catch (_) {
      return null;
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
          .where((f) => f.path.endsWith('.zip') || f.path.endsWith('.db'))
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
  //  pickBackupFile — اختيار ملف نسخة احتياطية (.zip أو .db قديم) من أي مكان
  // ──────────────────────────────────────────────────────────────
  Future<String?> pickBackupFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,           // نوع مخصص
        dialogTitle: 'اختر ملف النسخة الاحتياطية (.zip أو .db)',
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.first;
      final ext = file.extension?.toLowerCase();
      // .zip = الصيغة الحالية (db + إعدادات + صورة المعلم)، .db = نسخة
      // قديمة قبل التعديل ده — لسه مقبولة (توافق رجعي، راجع restoreBackup).
      if (ext != 'zip' && ext != 'db') return 'INVALID_EXT';
      return file.path;
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  restoreBackup — استعادة من مسار ملف
  //  يقبل الصيغتين: .zip (db + shared_prefs.json + avatar.*، الحالية)
  //  أو .db خام (نسخة قديمة قبل التعديل — توافق رجعي).
  // ──────────────────────────────────────────────────────────────
  Future<bool> restoreBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      if (!backupFile.existsSync()) {
        throw Exception('الملف غير موجود: $backupPath');
      }

      final header = await backupFile.openRead(0, 16).first;
      final isZip = header.length >= 2 && header[0] == 0x50 && header[1] == 0x4B; // 'PK'
      final isSqlite = String.fromCharCodes(header.take(6)).startsWith('SQLite');
      if (!isZip && !isSqlite) {
        throw Exception('الملف مش نسخة احتياطية صالحة (.zip أو .db)');
      }

      Uint8List dbBytes;
      Map<String, dynamic>? prefsDump;
      MapEntry<String, Uint8List>? avatarEntry; // (اسم الملف بامتداده، البايتات)

      if (isZip) {
        final archive = ZipDecoder().decodeBytes(await backupFile.readAsBytes());
        ArchiveFile? dbEntry, prefsFile, avatarFile;
        for (final f in archive.files) {
          if (!f.isFile) continue;
          if (f.name == DATABASE_NAME) {
            dbEntry = f;
          } else if (f.name == 'shared_prefs.json') {
            prefsFile = f;
          } else if (f.name == 'avatar' || f.name.startsWith('avatar.')) {
            avatarFile = f;
          }
        }
        if (dbEntry == null) {
          throw Exception('النسخة الاحتياطية مالهاش قاعدة بيانات صالحة');
        }
        dbBytes = dbEntry.content as Uint8List;

        if (prefsFile != null) {
          try {
            final jsonStr = utf8.decode(prefsFile.content as List<int>);
            prefsDump = (jsonDecode(jsonStr) as Map).cast<String, dynamic>();
          } catch (_) {}
        }

        if (avatarFile != null) {
          avatarEntry = MapEntry(avatarFile.name, avatarFile.content as Uint8List);
        }
      } else {
        dbBytes = await backupFile.readAsBytes();
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
      await File(targetPath).writeAsBytes(dbBytes);

      // مهم: امسح ملفات SQLite الجانبية (journal/WAL) القديمة — لو فضلت
      // موجودة، SQLite عند إعادة الفتح ممكن يعمل rollback بيها فوق
      // القاعدة المستعادة (journal ساخن) أو يطبّق كتابات قديمة (WAL) —
      // فتظهر بيانات ناقصة/غلط رغم إن الاستعادة نجحت.
      for (final ext in const ['-journal', '-wal', '-shm']) {
        try {
          final side = File('$targetPath$ext');
          if (side.existsSync()) side.deleteSync();
        } catch (_) {}
      }

      // استرجاع SharedPreferences (جلسة تسجيل دخول وضع الفريق أساسًا) —
      // بيكتب فوق كل المفاتيح الحالية بقيم النسخة الاحتياطية، زي ما
      // المستخدم يتوقّع من "استعادة" فعلية.
      if (prefsDump != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          for (final entry in prefsDump.entries) {
            final v = entry.value;
            if (v is String) {
              await prefs.setString(entry.key, v);
            } else if (v is bool) {
              await prefs.setBool(entry.key, v);
            } else if (v is int) {
              await prefs.setInt(entry.key, v);
            } else if (v is double) {
              await prefs.setDouble(entry.key, v);
            } else if (v is List) {
              await prefs.setStringList(entry.key, v.cast<String>());
            }
          }
        } catch (_) {}
      }

      // استرجاع صورة المعلم — بيتكتب في نفس المسار المحفوظ في الـDB
      // اللي رجعناها فوق (avatarPath الجديد/القديم بعد الاستعادة).
      if (avatarEntry != null) {
        try {
          final avatarPath = await DatabaseService().getSetting(_kTeacherAvatarSettingKey);
          if (avatarPath != null && avatarPath.isNotEmpty) {
            final f = File(avatarPath);
            await f.parent.create(recursive: true);
            await f.writeAsBytes(avatarEntry.value);
          }
        } catch (_) {}
      }

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
