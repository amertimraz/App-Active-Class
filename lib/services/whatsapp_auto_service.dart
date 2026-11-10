// lib/services/whatsapp_auto_service.dart
//
// spec 056 — الإرسال التلقائي لواتساب. التطبيق بيكتب "طلبات" في wa_outbox على
// Supabase بس؛ خدمة wa-worker على السيرفر هي اللي بتتحقق من الموافقة والحصة
// وبتبعت فعليًا. كل نداء هنا best-effort: أي فشل ما يعطّلش تسجيل الغياب.
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/services/auth_service.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/whatsapp_auto_rules.dart';

/// حالة موافقة ولي أمر طالب كما هي على السيرفر.
enum WaConsent { none, granted, stopped }

class WhatsAppAutoService {
  WhatsAppAutoService._();
  static final WhatsAppAutoService instance = WhatsAppAutoService._();

  Future<SupabaseClient?> _client() async {
    try {
      final c = await AuthService().ensureClient();
      return c?.auth.currentUser == null ? null : c;
    } catch (_) {
      return null;
    }
  }

  bool get _featureOn {
    if (!Get.isRegistered<SettingsController>()) return false;
    final s = Get.find<SettingsController>();
    return s.waAutoEnabled.value;
  }

  /// بيرفع حالة التفعيل والأنواع للسيرفر (الـ worker بيقرا من هناك).
  Future<bool> syncSettings() async {
    final c = await _client();
    if (c == null || !Get.isRegistered<SettingsController>()) return false;
    final s = Get.find<SettingsController>();
    try {
      await c.from('wa_teacher_settings').upsert({
        'owner_id': c.auth.currentUser!.id,
        'enabled': s.waAutoEnabled.value,
        'kinds': {'absence': s.waAutoAbsence.value},
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'owner_id');
      return true;
    } catch (e) {
      debugPrint('wa syncSettings: $e');
      return false;
    }
  }

  /// يحط طلب تنبيه غياب. بيرجع true لو اتبعت الطلب للسيرفر.
  /// جهاز المالك بس (المساعد ما يبعتش — منع الازدواج في وضع الفريق).
  Future<bool> enqueueAbsence(int studentId, DateTime day) async {
    try {
      if (!_featureOn) return false;
      final s = Get.find<SettingsController>();
      if (!s.waAutoAbsence.value) return false;
      if (TeamModeService().isAssistant) return false;
      final c = await _client();
      if (c == null) return false;

      final db = DatabaseService();
      final student =
          (await db.getAllStudents()).firstWhereOrNull((x) => x.id == studentId);
      if (student == null || student.isArchived) return false;
      final phone =
          waRecipientPhone(student.guardianPhone, s.countryDial.value);
      if (phone == null) return false;

      final groups = await db.getAllGroups();
      final group = groups.firstWhereOrNull((g) => g.id == student.groupId);
      final ownerId = c.auth.currentUser!.id;

      await c.from('wa_outbox').upsert({
        'owner_id': ownerId,
        'student_local_id': studentId,
        'student_name': student.name,
        'to_phone': phone,
        'kind': 'absence',
        'vars': waAbsenceVars(
          studentName: student.name,
          groupName: group?.name ?? '',
          day: day,
          teacherName: s.teacherFullName.value,
        ),
        'dedupe_key': waAbsenceDedupeKey(ownerId, studentId, day),
      }, onConflict: 'dedupe_key', ignoreDuplicates: true);
      return true;
    } catch (e) {
      debugPrint('wa enqueueAbsence: $e');
      return false;
    }
  }

  /// يلغي طلب غياب لسه pending (لو الغياب اتحوّل لحضور/اتمسح قبل الإرسال).
  Future<void> cancelAbsence(int studentId, DateTime day) async {
    try {
      final c = await _client();
      if (c == null) return;
      final ownerId = c.auth.currentUser!.id;
      await c
          .from('wa_outbox')
          .update({'status': 'blocked', 'fail_reason': 'cancelled'})
          .eq('dedupe_key', waAbsenceDedupeKey(ownerId, studentId, day))
          .eq('status', 'pending');
    } catch (e) {
      debugPrint('wa cancelAbsence: $e');
    }
  }

  /// موافقات المدرس: studentLocalId → الحالة.
  Future<Map<int, WaConsent>> loadConsents() async {
    final c = await _client();
    if (c == null) return {};
    final rows = await c.from('wa_consents').select('student_local_id,status');
    return {
      for (final r in rows)
        (r['student_local_id'] as int):
            r['status'] == 'stopped' ? WaConsent.stopped : WaConsent.granted,
    };
  }

  /// يسجّل موافقة لمجموعة طلاب (الغير صالح رقمهم بيتتخطّى). بيرجع عدد اللي اتسجّل.
  Future<int> grantConsent(List<({int studentId, String phone})> items,
      {String grantedBy = 'teacher'}) async {
    final c = await _client();
    if (c == null || items.isEmpty) return 0;
    final ownerId = c.auth.currentUser!.id;
    await c.from('wa_consents').upsert([
      for (final i in items)
        {
          'owner_id': ownerId,
          'student_local_id': i.studentId,
          'phone': i.phone,
          'status': 'granted',
          'granted_by': grantedBy,
        }
    ], onConflict: 'owner_id,student_local_id,phone', ignoreDuplicates: true);
    return items.length;
  }

  /// الحصة الشهرية: (المتبقي، الإجمالي) أو null لو مفيش اتصال/مفيش صف لسه.
  Future<({int remaining, int limit})?> loadQuota() async {
    final c = await _client();
    if (c == null) return null;
    final month = DateTime.now();
    final first = DateTime(month.year, month.month, 1);
    final row = await c
        .from('wa_quota')
        .select('free_limit,used,extra_balance')
        .eq('month', first.toIso8601String().substring(0, 10))
        .maybeSingle();
    if (row == null) return null;
    final limit = row['free_limit'] as int;
    final used = row['used'] as int;
    final extra = row['extra_balance'] as int;
    return (remaining: (limit - used).clamp(0, limit) + extra, limit: limit);
  }

  /// آخر الرسايل (للعرض فقط): النوع، اسم الطالب، الحالة، سبب الفشل، الوقت.
  Future<List<Map<String, dynamic>>> loadRecent({int limit = 20}) async {
    final c = await _client();
    if (c == null) return [];
    final rows = await c
        .from('wa_outbox')
        .select('kind,student_name,status,fail_reason,created_at')
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }
}
