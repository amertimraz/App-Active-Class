// lib/services/backup_service.dart

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/services/database_service.dart';

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  /// إنشاء نسخة احتياطية من قاعدة البيانات
  Future<String?> createBackup() async {
    try {
      // الحصول على مسار قاعدة البيانات الأصلية
      final dbPath = await getDatabasesPath();
      final originalDbPath = p.join(dbPath, DATABASE_NAME);
      
      // التحقق من وجود قاعدة البيانات
      final originalFile = File(originalDbPath);
      if (!originalFile.existsSync()) {
        throw Exception('قاعدة البيانات غير موجودة');
      }

      // الحصول على مجلد التطبيق الخارجي لحفظ النسخة الاحتياطية
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception('لا يمكن الوصول إلى التخزين الخارجي');
      }

      // إنشاء مجلد للنسخ الاحتياطية
      final backupDir = Directory(p.join(directory.path, 'backups'));
      if (!backupDir.existsSync()) {
        await backupDir.create(recursive: true);
      }

      // إنشاء اسم ملف النسخة الاحتياطية بالتاريخ والوقت
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupFileName = 'active_class_backup_$timestamp.db';
      final backupPath = p.join(backupDir.path, backupFileName);

      // نسخ قاعدة البيانات
      await originalFile.copy(backupPath);

      return backupPath;
    } catch (e) {
      print('Error creating backup: $e');
      return null;
    }
  }

  /// استعادة النسخة الاحتياطية
  Future<bool> restoreBackup(String backupPath) async {
    try {
      // Ensure database file is unlocked before replacing it.
      await DatabaseService().close();

      // الحصول على مسار قاعدة البيانات الأصلية
      final dbPath = await getDatabasesPath();
      final originalDbPath = p.join(dbPath, DATABASE_NAME);

      // التحقق من وجود الملف الاحتياطي
      final backupFile = File(backupPath);
      if (!backupFile.existsSync()) {
        throw Exception('ملف النسخة الاحتياطية غير موجود');
      }

      // نسخ النسخة الاحتياطية محل قاعدة البيانات الأصلية
      await backupFile.copy(originalDbPath);

      return true;
    } catch (e) {
      print('Error restoring backup: $e');
      return false;
    }
  }

  /// مشاركة النسخة الاحتياطية
  Future<void> shareBackup(String backupPath) async {
    try {
      final file = File(backupPath);
      if (file.existsSync()) {
        await Share.shareXFiles(
          [XFile(backupPath)],
          text: 'نسخة احتياطية من تطبيق Active Class',
        );
      }
    } catch (e) {
      print('Error sharing backup: $e');
    }
  }

  /// الحصول على قائمة النسخ الاحتياطية المتاحة
  Future<List<FileSystemEntity>> getBackupFiles() async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) return [];

      final backupDir = Directory(p.join(directory.path, 'backups'));
      if (!backupDir.existsSync()) return [];

      final files = backupDir.listSync();
      // ترتيب الملفات حسب تاريخ التعديل (الأحدث أولاً)
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      return files.where((file) => file.path.endsWith('.db')).toList();
    } catch (e) {
      print('Error getting backup files: $e');
      return [];
    }
  }

  /// حذف نسخة احتياطية
  Future<bool> deleteBackup(String backupPath) async {
    try {
      final file = File(backupPath);
      if (file.existsSync()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting backup: $e');
      return false;
    }
  }

  /// حذف جميع النسخ الاحتياطية القديمة (أكثر من 30 يوم)
  Future<void> cleanOldBackups({int daysToKeep = 30}) async {
    try {
      final files = await getBackupFiles();
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      for (final file in files) {
        final stat = file.statSync();
        if (stat.modified.isBefore(cutoffDate)) {
          await file.delete();
        }
      }
    } catch (e) {
      print('Error cleaning old backups: $e');
    }
  }

  /// الحصول على حجم ملف النسخة الاحتياطية
  String getBackupFileSize(String backupPath) {
    try {
      final file = File(backupPath);
      final bytes = file.lengthSync();
      
      if (bytes < 1024) {
        return '$bytes بايت';
      } else if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(2)} كيلوبايت';
      } else {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} ميجابايت';
      }
    } catch (e) {
      return 'غير معروف';
    }
  }
}
