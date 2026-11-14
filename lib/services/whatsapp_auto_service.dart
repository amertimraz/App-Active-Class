// lib/services/whatsapp_auto_service.dart
//
// spec 056 — الإرسال التلقائي لواتساب. التطبيق بيكتب "طلبات" في wa_outbox على
// Supabase بس؛ خدمة wa-worker على السيرفر هي اللي بتتحقق من الموافقة والحصة
// وبتبعت فعليًا. كل نداء هنا best-effort: أي فشل ما يعطّلش تسجيل الغياب.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/dashboard_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/utils/billing_day.dart';
import 'package:active_class/utils/billing_period.dart';
import 'package:active_class/utils/pricing_helper.dart';
import 'package:active_class/services/auth_service.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/whatsapp_auto_rules.dart';
import 'package:active_class/utils/support_contact.dart';

/// حالة موافقة ولي أمر طالب كما هي على السيرفر.
enum WaConsent { none, granted, stopped }

/// خطأ بسيط برسالة عربي تتعرض للمدرس.
/// حالة تفعيل الخدمة (قفل افتراضي: الأدمن هو اللي يفتحها).
class WaActivation {
  final bool activated;
  final bool paused;
  final DateTime? requestedAt;
  const WaActivation(
      {required this.activated, required this.paused, this.requestedAt});

  /// الإرسال فعليًا مسموح من ناحية الإدارة.
  bool get allowed => activated && !paused;
}

class WaAutoException implements Exception {
  final String message;
  const WaAutoException(this.message);
  @override
  String toString() => message;
}

class WhatsAppAutoService {
  WhatsAppAutoService._();
  static final WhatsAppAutoService instance = WhatsAppAutoService._();

  Future<SupabaseClient?> _client() async {
    try {
      final c = await AuthService().ensureClient();
      if (c == null) return null;
      var session = c.auth.currentSession;
      // توكن منتهي (التطبيق ساب فترة): نجدّده قبل النداء بدل ما الطلب يفشل.
      if (session != null && session.isExpired) {
        try {
          session = (await c.auth.refreshSession()).session;
        } catch (e) {
          debugPrint('wa refreshSession: $e');
        }
      }
      return c.auth.currentUser == null ? null : c;
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
        'kinds': {
          'absence': s.waAutoAbsence.value,
          'late_payment': s.waAutoLate.value,
          'receipt': s.waAutoReceipt.value,
        },
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'owner_id');
      return true;
    } catch (e) {
      debugPrint('wa syncSettings: $e');
      return false;
    }
  }

  /// حالة تفعيل الخدمة عند الإدارة: مفتوحة؟ موقوفة؟ ومتى اتطلب التفعيل.
  /// null لو مفيش اتصال/تسجيل دخول. مفيش صف = لسه ما اتفعّلتش.
  Future<WaActivation?> loadActivation() async {
    // المساعد: التفعيل والرصيد عند المدرس (صاحب الحساب) مش عنده.
    if (TeamModeService().isAssistant) return null;
    final c = await _client();
    if (c == null) return null;
    try {
      final row = await c
          .from('wa_teacher_settings')
          .select('admin_activated,paused_by_admin,activation_requested_at')
          .eq('owner_id', c.auth.currentUser!.id)
          .maybeSingle();
      final act = WaActivation(
        activated: row?['admin_activated'] == true,
        paused: row?['paused_by_admin'] == true,
        requestedAt: row?['activation_requested_at'] == null
            ? null
            : DateTime.tryParse('${row!['activation_requested_at']}'),
      );
      unawaited(_saveActivationCache(act));
      return act;
    } catch (e) {
      debugPrint('wa loadActivation: $e');
      return null;
    }
  }

  // آخر حالة معروفة (ok/locked/paused) عشان الشاشات تعرضها فورًا من غير وميض
  // لحد ما الرد من السيرفر يوصل، وتفضل صح لو مفيش نت.
  static const _kActCache = 'wa_activation_cache';

  Future<void> _saveActivationCache(WaActivation a) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _kActCache, a.paused ? 'paused' : (a.activated ? 'ok' : 'locked'));
    } catch (_) {}
  }

  Future<WaActivation?> cachedActivation() async {
    try {
      final p = await SharedPreferences.getInstance();
      return switch (p.getString(_kActCache)) {
        'ok' => const WaActivation(activated: true, paused: false),
        'locked' => const WaActivation(activated: false, paused: false),
        'paused' => const WaActivation(activated: true, paused: true),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  /// بيسجّل إن المدرس طلب التفعيل (الأدمن يشوفه في اللوحة) ويفتح واتساب
  /// برسالة جاهزة على رقم الإدارة. بيرجع true لو اتفتح واتساب.
  Future<bool> requestActivation() async {
    if (TeamModeService().isAssistant) return false;
    final c = await _client();
    final s =
        Get.isRegistered<SettingsController>() ? Get.find<SettingsController>() : null;
    final user = c?.auth.currentUser;
    if (c != null && user != null) {
      try {
        await c.from('wa_teacher_settings').upsert({
          'owner_id': user.id,
          'activation_requested_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'owner_id');
      } catch (e) {
        debugPrint('wa requestActivation mark: $e');
      }
    }
    final account = (user?.phone?.isNotEmpty ?? false) ? user!.phone : user?.email;
    return openWaActivationRequest(
      teacherName: s?.teacherFullName.value,
      teacherPhone: s == null
          ? null
          : waTeacherPhoneText(s.teacherPhone.value, s.countryDial.value),
      account: account,
    );
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
          teacherPhone:
              waTeacherPhoneText(s.teacherPhone.value, s.countryDial.value),
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

  /// رصيد الرسايل الشهري: المتبقي (مجاني + إضافي)، الحد المجاني، المستهلك،
  /// الرصيد الإضافي. لو مفيش صف للشهر لسه بنقرا الحد الفعلي (إعداد المدرس أو
  /// الافتراضي) عشان العرض يبقى صح من أول مرة.
  Future<({int remaining, int limit, int used, int extra})?> loadQuota() async {
    final c = await _client();
    if (c == null) {
      throw const WaAutoException(
          'الجهاز ده مش مسجّل دخول بحساب. ادخل من «الحساب والفريق» بنفس رقم الترخيص وبعدين اضغط إعادة المحاولة');
    }
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final row = await c
        .from('wa_quota')
        .select('free_limit,used,extra_balance')
        .eq('month', first.toIso8601String().substring(0, 10))
        .maybeSingle();
    int limit;
    var used = 0;
    var extra = 0;
    if (row != null) {
      limit = row['free_limit'] as int;
      used = row['used'] as int;
      extra = row['extra_balance'] as int;
    } else {
      final ov = await c
          .from('wa_teacher_settings')
          .select('free_limit_override')
          .eq('owner_id', c.auth.currentUser!.id)
          .maybeSingle();
      final def = await c
          .from('wa_config')
          .select('value')
          .eq('key', 'default_free_limit')
          .maybeSingle();
      limit = (ov?['free_limit_override'] as int?) ??
          int.tryParse('${def?['value']}') ??
          100;
    }
    return (
      remaining: (limit - used).clamp(0, limit) + extra,
      limit: limit,
      used: used,
      extra: extra,
    );
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

  // ───────────────── إيصال الدفعة ─────────────────
  /// يحط طلب «إيصال دفعة» بعد تسجيل تحصيل فعلي (مش إسقاط مديونية).
  /// المتبقي = المديونية المتراكمة لحد شهر التحصيل الحالي بعد الدفعة دي.
  Future<bool> enqueueReceipt(Payment p) async {
    try {
      if (!_featureOn) return false;
      final s = Get.find<SettingsController>();
      if (!s.waAutoReceipt.value || !p.isCollection || p.amount <= 0) {
        return false;
      }
      if (TeamModeService().isAssistant) return false;
      final c = await _client();
      if (c == null) return false;

      final db = DatabaseService();
      final students = await db.getAllStudents();
      final student = students.firstWhereOrNull((x) => x.id == p.studentId);
      if (student == null || student.isArchived) return false;
      final phone = waRecipientPhone(student.guardianPhone, s.countryDial.value);
      if (phone == null) return false;

      final groups = await db.getAllGroups();
      final group = groups.firstWhereOrNull((g) => g.id == student.groupId);
      final payments = (await db.getAllPayments())
          .where((x) => x.studentId == p.studentId)
          .toList();
      final attendance = (await db.getAllAttendance())
          .where((a) => a.studentId == p.studentId)
          .toList();
      final remaining = PricingHelper.accumulatedDebtThrough(
        student: student,
        group: group,
        allAttendance: attendance,
        payments: payments,
        month: defaultCollectionMonth(),
        siblingGroupMembers: students,
      );

      final ownerId = c.auth.currentUser!.id;
      await c.from('wa_outbox').upsert({
        'owner_id': ownerId,
        'student_local_id': p.studentId,
        'student_name': student.name,
        'to_phone': phone,
        'kind': 'receipt',
        'vars': waReceiptVars(
          amount: p.amount,
          studentName: student.name,
          monthLabel: DateFormat('MMMM yyyy', 'ar').format(p.date),
          remaining: remaining,
          teacherName: s.teacherFullName.value,
          teacherPhone:
              waTeacherPhoneText(s.teacherPhone.value, s.countryDial.value),
        ),
        'dedupe_key': waReceiptDedupeKey(ownerId, p.studentId, p.date, p.amount),
      }, onConflict: 'dedupe_key', ignoreDuplicates: true);
      return true;
    } catch (e) {
      debugPrint('wa enqueueReceipt: $e');
      return false;
    }
  }

  // ───────────────── تذكير تأخر الدفع (أسبوعي) ─────────────────
  Timer? _timer;

  /// يبدأ الفحص الدوري (كل 6 ساعات) — آمن لو اتنادى أكتر من مرة، ومابيعملش
  /// حاجة لو الميزة مقفولة (بيتنادى تاني لما المدرس يفعّلها).
  void start() {
    if (!_featureOn) return;
    _timer ??= Timer.periodic(
        const Duration(hours: 6), (_) => unawaited(enqueueLatePaymentsIfDue()));
    Future<void>.delayed(const Duration(seconds: 25),
        () => unawaited(enqueueLatePaymentsIfDue()));
  }

  /// مرة في اليوم بالكتير: يحط تذكير لكل طالب متأخر عن شهر التحصيل الحالي
  /// (نفس قايمة كارت «دفعات» في الرئيسية). منع التكرار بالأسبوع (ISO) فالطالب
  /// ما بيستلمش أكتر من تذكير في الأسبوع. جهاز المالك بس.
  Future<int> enqueueLatePaymentsIfDue({bool force = false}) async {
    try {
      if (!_featureOn) return 0;
      final s = Get.find<SettingsController>();
      if (!s.waAutoLate.value || TeamModeService().isAssistant) return 0;
      final db = DatabaseService();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (!force &&
          await db.getSetting(SETTING_WA_AUTO_LATE_LAST_RUN) == today) {
        return 0;
      }
      final c = await _client();
      if (c == null) return 0; // مفيش اتصال/تسجيل دخول: نحاول تاني بعدين
      final ownerId = c.auth.currentUser!.id;

      final students =
          (await db.getAllStudents()).where((x) => !x.isArchived).toList();
      final groups = await db.getAllGroups();
      final payments = await db.getAllPayments();
      final attendance = await db.getAllAttendance();
      final paymentsByStudent = <int, List<Payment>>{};
      for (final p in payments) {
        paymentsByStudent.putIfAbsent(p.studentId, () => []).add(p);
      }
      final month = defaultCollectionMonth();
      final breakdown = computeMonthlyBreakdown(
        students: students,
        paymentsByStudent: paymentsByStudent,
        groupById: <int?, Group>{for (final g in groups) g.id: g},
        allAttendance: attendance,
        month: month,
        prevMonth: DateTime(month.year, month.month - 1, 1),
        monthLanded: PricingHelper.billingArrears ||
            monthHasLanded(
              month: month,
              now: DateTime.now(),
              arrears: false,
              billingDay: PricingHelper.billingDay,
            ),
      );

      final teacherPhone =
          waTeacherPhoneText(s.teacherPhone.value, s.countryDial.value);
      final rows = <Map<String, dynamic>>[];
      for (final e in breakdown.unpaidEntries) {
        final phone =
            waRecipientPhone(e.student.guardianPhone, s.countryDial.value);
        if (phone == null || e.student.id == null) continue;
        rows.add({
          'owner_id': ownerId,
          'student_local_id': e.student.id,
          'student_name': e.student.name,
          'to_phone': phone,
          'kind': 'late_payment',
          'vars': waLateVars(
            studentName: e.student.name,
            amount: e.amountDue,
            teacherName: s.teacherFullName.value,
            teacherPhone: teacherPhone,
          ),
          'dedupe_key': waLateDedupeKey(ownerId, e.student.id!, DateTime.now()),
        });
      }
      if (rows.isNotEmpty) {
        await c.from('wa_outbox').upsert(rows,
            onConflict: 'dedupe_key', ignoreDuplicates: true);
      }
      await db.setSetting(SETTING_WA_AUTO_LATE_LAST_RUN, today);
      return rows.length;
    } catch (e) {
      debugPrint('wa enqueueLatePayments: $e');
      return 0;
    }
  }
}
