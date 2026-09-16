// lib/services/google_drive_backup_service.dart
//
// نسخ احتياطي سحابي (spec 037) — Google Drive شخصي لكل مدرّس، مستقل
// تمامًا عن Supabase/وضع الفريق. بيعيد استخدام BackupService().createBackup()
// لبناء نفس ملف الـ.zip المحلي بالظبط، وبيرفعه/يسترجعه عبر Google Drive
// API v3 مباشرة (dio) بنطاق drive.file بس (راجع specs/037-cloud-backup/research.md).
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/services/backup_service.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/cloud_backup_retry_policy.dart';

class CloudBackupEntry {
  final String id;
  final String name;
  final DateTime createdTime;
  final int sizeBytes;

  const CloudBackupEntry({
    required this.id,
    required this.name,
    required this.createdTime,
    required this.sizeBytes,
  });

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes بايت';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} كيلوبايت';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} ميجابايت';
  }
}

class GoogleDriveBackupService {
  static final GoogleDriveBackupService _instance =
      GoogleDriveBackupService._internal();
  factory GoogleDriveBackupService() => _instance;
  GoogleDriveBackupService._internal();

  static const _scopes = <String>['https://www.googleapis.com/auth/drive.file'];
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  static const _filesUrl = 'https://www.googleapis.com/drive/v3/files';
  static const _uploadUrl =
      'https://www.googleapis.com/upload/drive/v3/files';

  // ── حالة الربط (مقروءة من DB — نفس نمط أي إعداد تاني) ──────────────
  Future<bool> isLinked() async {
    final email = await linkedEmail();
    return email != null && email.isNotEmpty;
  }

  Future<String?> linkedEmail() =>
      DatabaseService().getSetting(SETTING_CLOUD_BACKUP_LINKED_EMAIL);

  // ── US1: ربط/إلغاء ربط الحساب ───────────────────────────────────────
  Future<bool> linkAccount() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return false; // المستخدم ألغى الاختيار
      await DatabaseService()
          .setSetting(SETTING_CLOUD_BACKUP_LINKED_EMAIL, account.email);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> unlinkAccount() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    // بلا لمس أي ملف على Drive نفسه — بس الحالة المحلية.
    await DatabaseService().setSetting(SETTING_CLOUD_BACKUP_LINKED_EMAIL, '');
  }

  /// توكن صالح لطلب حالي — signInSilently بيجدّد تلقائيًا لو لازم
  /// (research.md #5). null لو مفيش حساب مربوط أو فشل التجديد (مثلاً
  /// المستخدم سحب الصلاحية من برّه التطبيق).
  Future<String?> _accessToken() async {
    try {
      var account = _googleSignIn.currentUser;
      debugPrint('[CloudBackup] currentUser=${account?.email}');
      account ??= await _googleSignIn.signInSilently();
      debugPrint('[CloudBackup] after signInSilently: ${account?.email}');
      if (account == null) return null;
      final auth = await account.authentication;
      debugPrint('[CloudBackup] got auth, accessToken null=${auth.accessToken == null}');
      return auth.accessToken;
    } catch (e, st) {
      debugPrint('[CloudBackup] _accessToken FAILED: $e\n$st');
      return null;
    }
  }

  // ── US2: رفع نسخة سحابية ────────────────────────────────────────────
  /// بيبني نسخة محلية جديدة عبر BackupService().createBackup() ويرفعها.
  /// isAutomatic بيفرّق فعليًا هنا: حد إعادة المحاولة (research.md #4)
  /// الهدف منه إنه يمنع محاولات تلقائية لا نهائية في الخلفية تستهلك
  /// بطارية/بيانات لو الحساب مفصول فعليًا؛ ضغطة "رفع الآن" يدوية صريحة
  /// من المستخدم لازم تفضل تحاول دايمًا — وإلا فشل تلقائي قديم (حتى لو
  /// السبب اتصلّح، زي جلسة Google رجعت تاني) بيقفل الرفع اليدوي للأبد
  /// بصمت من غير أي طريقة يرجّعه المستخدم غير إلغاء الربط وإعادته.
  Future<bool> uploadBackup({required bool isAutomatic}) async {
    debugPrint('[CloudBackup] uploadBackup start (isAutomatic=$isAutomatic)');
    if (!await isLinked()) {
      debugPrint('[CloudBackup] not linked — abort');
      return false; // FR-005: بلا أي طلب دخول مفاجئ
    }

    final pendingRetries = int.tryParse(
            await DatabaseService()
                    .getSetting(SETTING_CLOUD_BACKUP_PENDING_RETRIES) ??
                '0') ??
        0;
    debugPrint('[CloudBackup] pendingRetries=$pendingRetries');
    if (isAutomatic && !shouldAttemptCloudUpload(pendingRetries: pendingRetries)) {
      debugPrint('[CloudBackup] retry limit reached — abort (automatic only)');
      return false; // تجاوزنا حد المحاولات — نستنى النسخة الدورية الجاية
    }

    await DatabaseService().setSetting(
        SETTING_CLOUD_BACKUP_LAST_ATTEMPT_AT,
        DateTime.now().toIso8601String());

    debugPrint('[CloudBackup] getting access token...');
    final token = await _accessToken();
    debugPrint('[CloudBackup] token=${token == null ? "null" : "${token.substring(0, 12)}..."}');
    if (token == null) {
      await _recordFailure(pendingRetries);
      debugPrint('[CloudBackup] no token — abort');
      return false;
    }

    debugPrint('[CloudBackup] creating local backup file...');
    final backupResult = await BackupService().createBackup();
    debugPrint('[CloudBackup] createBackup success=${backupResult.success} path=${backupResult.localPath}');
    if (!backupResult.success || backupResult.localPath == null) {
      await _recordFailure(pendingRetries);
      return false;
    }

    String? createdFileId;
    try {
      final file = File(backupResult.localPath!);
      final bytes = await file.readAsBytes();
      debugPrint('[CloudBackup] read ${bytes.length} bytes, posting metadata...');

      // خطوتين بسيطتين (metadata ثم محتوى) بدل multipart/related يدوي —
      // راجع research.md/plan.md. فشل الخطوة الثانية بيمسح الملف الفاضي
      // اللي اتعمل في الخطوة الأولى (عشان ميظهرش كنسخة "فاضية" في القائمة).
      final createResp = await _dio.post(
        _filesUrl,
        data: {'name': backupResult.fileName},
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        }),
      );
      debugPrint('[CloudBackup] metadata response: ${createResp.statusCode} ${createResp.data}');
      createdFileId = createResp.data['id'] as String?;
      if (createdFileId == null) throw Exception('مفيش id في رد إنشاء الملف');
      debugPrint('[CloudBackup] created file id=$createdFileId, uploading content...');

      final uploadResp = await _dio.patch(
        '$_uploadUrl/$createdFileId',
        queryParameters: {'uploadType': 'media'},
        data: Stream.fromIterable([bytes]),
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/zip',
          Headers.contentLengthHeader: bytes.length,
        }),
      );
      debugPrint('[CloudBackup] upload content response: ${uploadResp.statusCode}');

      await DatabaseService()
          .setSetting(SETTING_CLOUD_BACKUP_PENDING_RETRIES, '0');
      await _cleanupOldCloudBackups(token);
      debugPrint('[CloudBackup] upload SUCCESS');
      return true;
    } catch (e, st) {
      debugPrint('[CloudBackup] upload FAILED: $e');
      if (e is DioException) {
        debugPrint('[CloudBackup] DioException type=${e.type} response=${e.response?.statusCode} ${e.response?.data}');
      }
      debugPrint('[CloudBackup] stack: $st');
      if (createdFileId != null) {
        try {
          await _dio.delete('$_filesUrl/$createdFileId',
              options: Options(
                  headers: {'Authorization': 'Bearer $token'}));
        } catch (_) {}
      }
      await _recordFailure(pendingRetries);
      return false;
    }
  }

  Future<void> _recordFailure(int previousRetries) =>
      DatabaseService().setSetting(
          SETTING_CLOUD_BACKUP_PENDING_RETRIES, (previousRetries + 1).toString());

  // ── US3: قائمة النسخ + الاستعادة ─────────────────────────────────────
  Future<List<CloudBackupEntry>> listCloudBackups() async {
    final token = await _accessToken();
    if (token == null) return [];
    try {
      final resp = await _dio.get(_filesUrl,
          queryParameters: {
            'q': "name contains 'active_class_backup_' and trashed = false",
            'fields': 'files(id,name,createdTime,size)',
            'orderBy': 'createdTime desc',
            'spaces': 'drive',
          },
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      final files = (resp.data['files'] as List? ?? []);
      return files
          .map((f) => CloudBackupEntry(
                id: f['id'] as String,
                name: f['name'] as String,
                createdTime: DateTime.parse(f['createdTime'] as String),
                sizeBytes: int.tryParse('${f['size']}') ?? 0,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// بيحمّل الملف لمسار مؤقت وينادي BackupService().restoreBackup(...)
  /// الموجودة بالفعل — بلا تكرار منطق فك الـzip (عقد #5).
  Future<bool> restoreFromCloud(String fileId, String fileName) async {
    final token = await _accessToken();
    if (token == null) return false;

    final tmpDir = await getTemporaryDirectory();
    final tmpPath = p.join(tmpDir.path, fileName);
    try {
      final resp = await _dio.get<List<int>>(
        '$_filesUrl/$fileId',
        queryParameters: {'alt': 'media'},
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          responseType: ResponseType.bytes,
        ),
      );
      final bytes = resp.data;
      if (bytes == null) return false;
      await File(tmpPath).writeAsBytes(bytes);
      return await BackupService().restoreBackup(tmpPath);
    } catch (_) {
      return false;
    } finally {
      try {
        final f = File(tmpPath);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  // ── US4: حذف نسخة يدويًا ─────────────────────────────────────────────
  Future<bool> deleteCloudBackup(String fileId) async {
    final token = await _accessToken();
    if (token == null) return false;
    try {
      await _dio.delete('$_filesUrl/$fileId',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── FR-011: حد 5 نسخ كحد أقصى — تنظيف الأقدم عند تجاوزه ─────────────
  Future<void> _cleanupOldCloudBackups(String token) async {
    try {
      final resp = await _dio.get(_filesUrl,
          queryParameters: {
            'q': "name contains 'active_class_backup_' and trashed = false",
            'fields': 'files(id,createdTime)',
            'orderBy': 'createdTime desc',
            'spaces': 'drive',
          },
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      final files = (resp.data['files'] as List? ?? []);
      if (files.length <= 5) return;
      final toDelete = files.skip(5);
      for (final f in toDelete) {
        try {
          await _dio.delete('$_filesUrl/${f['id']}',
              options: Options(headers: {'Authorization': 'Bearer $token'}));
        } catch (_) {}
      }
    } catch (_) {}
  }
}
