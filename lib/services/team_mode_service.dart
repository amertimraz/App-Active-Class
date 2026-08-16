// lib/services/team_mode_service.dart
//
// "وضع الفريق" — يبني فوق نظام تسجيل الدخول المستقل (Supabase)
// وSyncEngine. المدرس (owner) بيفعّله وبيبعت كود دعوة، والمساعد
// بيسجّل حسابه الخاص (نفس شاشات الدخول الموجودة) وينضم بالكود.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/services/auth_service.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/sync_engine.dart';
import 'package:active_class/utils/helpers.dart';

class TeamModeService {
  static final TeamModeService _instance = TeamModeService._internal();
  factory TeamModeService() => _instance;
  TeamModeService._internal();

  final AuthService _auth = AuthService();
  final DatabaseService _db = DatabaseService();
  SyncEngine? _engine;
  Worker? _licenseWorker;
  Worker? _profileWorker;

  final isEnabled = false.obs;
  final teamId = RxnString();
  final isOwner = false.obs;
  final canDeleteAttendance = false.obs;
  final canDeletePayments = false.obs;
  final canDeleteStudents = false.obs;
  final canManageMembers = false.obs;
  final loading = false.obs;
  /// بس عند المساعد — اسم/جنس المدرس صاحب الفريق (عشان شاشات زي
  /// الترحيب توضّح إنه مساعد لدى مين، مش تعرض بروفايله المحلي هو
  /// وكأنه المدرس نفسه).
  final ownerTeacherName = RxnString();
  final ownerTeacherGender = RxnString();

  /// استعادة صامتة عند فتح التطبيق — بس لو الميزة كانت مفعّلة فعلاً
  /// قبل كده وفيه جلسة دخول شغالة. صفر تأثير على غير مستخدمي الميزة.
  Future<void> init() async {
    final enabledFlag = await _db.getSetting(SETTING_TEAM_MODE_ENABLED);
    if (enabledFlag != 'true') return;
    final storedTeamId = await _db.getSetting(SETTING_TEAM_ID);
    if (storedTeamId == null) return;

    final client = await _auth.ensureClient();
    if (client == null || client.auth.currentUser == null) return;

    teamId.value = storedTeamId;
    await _refreshMyPermissions(client, storedTeamId);
    _startEngine(client, storedTeamId);
    LicenseController.to.teamModeBypassLimits = true;
    isEnabled.value = true;
  }

  Future<String?> enableAsOwner() async {
    final client = await _auth.ensureClient();
    if (client == null || client.auth.currentUser == null) {
      return 'لازم تسجّل دخول الأول من شاشة الحساب';
    }
    loading.value = true;
    try {
      final settings = Get.isRegistered<SettingsController>()
          ? Get.find<SettingsController>()
          : null;
      final newTeamId = await client.rpc('create_team', params: {
        '_license_code': LicenseController.to.licenseCode.value,
        '_teacher_name': settings?.teacherFullName.value,
        '_teacher_gender': settings?.teacherGender.value,
      }) as String;
      teamId.value = newTeamId;
      isOwner.value = true;
      canDeleteAttendance.value = true;
      canDeletePayments.value = true;
      canDeleteStudents.value = true;
      canManageMembers.value = true;

      await _db.setSetting(SETTING_TEAM_MODE_ENABLED, 'true');
      await _db.setSetting(SETTING_TEAM_ID, newTeamId);

      _startEngine(client, newTeamId);
      await _engine!.enqueueAllExistingLocalRows();
      LicenseController.to.teamModeBypassLimits = true;
      isEnabled.value = true;
      return null;
    } catch (e) {
      debugPrint('TeamModeService: فشل تفعيل وضع الفريق — $e');
      return 'تعذر تفعيل وضع الفريق — تأكد من الإنترنت وحاول تاني';
    } finally {
      loading.value = false;
    }
  }

  Future<String?> joinWithInvite(String code) async {
    final client = await _auth.ensureClient();
    if (client == null || client.auth.currentUser == null) {
      return 'لازم تسجّل دخول الأول من شاشة الحساب';
    }
    if (code.trim().isEmpty) return 'أدخل كود الدعوة';
    loading.value = true;
    try {
      final newTeamId = await client
          .rpc('redeem_invite', params: {'_code': code.trim()}) as String;
      teamId.value = newTeamId;

      await _db.setSetting(SETTING_TEAM_MODE_ENABLED, 'true');
      await _db.setSetting(SETTING_TEAM_ID, newTeamId);

      await _refreshMyPermissions(client, newTeamId);
      _startEngine(client, newTeamId);
      await _engine!.initialFullPull();
      LicenseController.to.teamModeBypassLimits = true;
      isEnabled.value = true;
      return null;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('invalid invite')) return 'كود الدعوة غير صحيح';
      if (msg.contains('expired')) return 'كود الدعوة منتهي الصلاحية';
      if (msg.contains('already used')) return 'كود الدعوة اتستخدم قبل كده';
      if (msg.contains('member limit')) {
        return 'الفريق وصل للحد الأقصى من المساعدين — تواصل مع الدعم لزيادة العدد';
      }
      debugPrint('TeamModeService: فشل الانضمام — $e');
      return 'تعذر الانضمام — تأكد من الإنترنت وحاول تاني';
    } finally {
      loading.value = false;
    }
  }

  /// تعطيل وضع الفريق على الجهاز ده بس — البيانات المحلية تفضل زي
  /// ما هي، وبيانات الفريق على السيرفر تفضل موجودة (مش بنحذف الفريق).
  Future<void> disable() async {
    await _engine?.stop();
    _engine = null;
    _licenseWorker?.dispose();
    _licenseWorker = null;
    _profileWorker?.dispose();
    _profileWorker = null;
    await _db.setSetting(SETTING_TEAM_MODE_ENABLED, 'false');
    LicenseController.to.teamModeBypassLimits = false;
    isEnabled.value = false;
    teamId.value = null;
    isOwner.value = false;
    ownerTeacherName.value = null;
    ownerTeacherGender.value = null;
  }

  /// بتتنادى لو المدرس شال العضو ده من الفريق (أو حذف الفريق نفسه) —
  /// نعطّل وضع الفريق على الجهاز ده تلقائيًا ونوضحله السبب، بدل ما
  /// يفضل شغال بصلاحيات bypass محلية من غير ما يعرف إنه اتشال فعليًا.
  Future<void> _handleRemovedFromTeam() async {
    await disable();
    ToastHelper.error('المدرس أزالك من الفريق — تم تعطيل وضع الفريق على جهازك');
  }

  /// بس للمساعد — لو ترخيص المدرس الحقيقي (Firebase) بقى موقوف/منتهي.
  Future<void> _handleLicenseInactive() async {
    await disable();
    ToastHelper.error('ترخيص المدرس متوقف حاليًا — تم تعطيل وضع الفريق على جهازك');
  }

  /// بتتنادى من AuthController عند تبديل الحساب (خروج/دخول) — الإعدادات
  /// المحلية (SETTING_TEAM_MODE_ENABLED/SETTING_TEAM_ID) مخزّنة على
  /// مستوى الجهاز مش الحساب، فلازم نصفّرها ونعيد التحقق من السيرفر
  /// لصاحب الحساب الجديد تحديدًا (مش نثق في القيمة المحفوظة اللي
  /// ممكن تكون خاصة بحساب سابق كان مسجّل دخول على نفس الجهاز).
  Future<void> resetForAccountSwitch() => disable();

  Future<void> restoreForCurrentUser() async {
    final client = await _auth.ensureClient();
    final uid = client?.auth.currentUser?.id;
    if (client == null || uid == null) return;
    try {
      final rows = await client
          .from('team_members')
          .select('team_id')
          .eq('user_id', uid)
          .limit(1);
      if (rows.isEmpty) return; // الحساب ده مش عضو في أي فريق
      final foundTeamId = rows.first['team_id'] as String;
      teamId.value = foundTeamId;
      await _db.setSetting(SETTING_TEAM_MODE_ENABLED, 'true');
      await _db.setSetting(SETTING_TEAM_ID, foundTeamId);
      await _refreshMyPermissions(client, foundTeamId);
      _startEngine(client, foundTeamId);
      LicenseController.to.teamModeBypassLimits = true;
      isEnabled.value = true;
    } catch (e) {
      debugPrint('TeamModeService: فشل استعادة الفريق للحساب الحالي — $e');
    }
  }

  void _startEngine(SupabaseClient client, String tId) {
    final deviceId = LicenseController.to.deviceId.value;
    _engine = SyncEngine(
      client: client,
      teamId: tId,
      deviceId: deviceId,
      onRemovedFromTeam: _handleRemovedFromTeam,
      // بس للمساعد — لو عملناها للمدرس نفسه هتقفل وضع الفريق عنده
      // (isOwner/teamId يترجعوا فاضيين محليًا) من غير أي طريقة يرجع بيها
      // تلقائيًا لما ترخيصه يترجّع، لأن enableAsOwner() بينشئ فريق
      // جديد بدل ما يستعيد القديم. المدرس أصلاً عنده متابعة مباشرة
      // ولحظية لحالة ترخيصه هو (LicenseController)، فمش محتاج الفحص ده.
      onLicenseInactive: isOwner.value ? null : _handleLicenseInactive,
    );
    _engine!.start();
    if (isOwner.value) {
      _watchOwnerLicense(client, tId);
      _watchOwnerProfile(client, tId);
      _tagDeviceAsTeamRole('owner', LicenseController.to.licenseCode.value);
    } else {
      _tagAssistantDevice(client, tId);
    }
  }

  /// بس على جهاز المدرس: كل ما يعدّل اسمه/جنسه في الإعدادات وهو مفعّل
  /// وضع الفريق، نبعت التحديث ده للفريق — عشان أجهزة المساعدين تفضل
  /// عارضة الاسم الصح في شاشة الترحيب.
  void _watchOwnerProfile(SupabaseClient client, String tId) {
    if (!Get.isRegistered<SettingsController>()) return;
    final settings = Get.find<SettingsController>();
    _profileWorker?.dispose();
    _profileWorker = everAll([settings.teacherFullName, settings.teacherGender], (_) {
      client.rpc('set_team_teacher_profile', params: {
        '_team_id': tId,
        '_name': settings.teacherFullName.value,
        '_gender': settings.teacherGender.value,
      }).catchError((e) {
        debugPrint('TeamModeService: فشل تحديث بروفايل المدرس للفريق — $e');
      });
    });
  }

  /// بس على جهاز المساعد: بنجيب كود ترخيص المدرس واسمه/جنسه (المخزّنين
  /// على الفريق) — الكود عشان نربط جهاز المساعد بيه في Firestore
  /// (يظهر في لوحة الأدمن تحت تفاصيل نفس الترخيص)، والاسم عشان شاشة
  /// الترحيب توضّح إنه مساعد لدى مين بدل ما تعرض بروفايله المحلي هو.
  Future<void> _tagAssistantDevice(SupabaseClient client, String tId) async {
    try {
      final row = await client
          .from('teams')
          .select('license_code, teacher_name, teacher_gender')
          .eq('id', tId)
          .single();
      final code = row['license_code'] as String?;
      ownerTeacherName.value = row['teacher_name'] as String?;
      ownerTeacherGender.value = row['teacher_gender'] as String?;
      await _tagDeviceAsTeamRole('assistant', code);
    } catch (e) {
      debugPrint('TeamModeService: فشل جلب بيانات الفريق — $e');
    }
  }

  /// بيسجّل دور الجهاز (مدرس/مساعد) وكود الترخيص المرتبط بيه في مستند
  /// devices/{deviceId} الموجود أصلاً (LicenseController._registerDevice) —
  /// عشان لوحة الأدمن تقدر تعرض أجهزة المساعدين تحت نفس الترخيص.
  Future<void> _tagDeviceAsTeamRole(String role, String? licenseCode) async {
    try {
      final deviceId = LicenseController.to.deviceId.value;
      if (deviceId.isEmpty) return;
      final payload = <String, dynamic>{
        'teamRole': role,
        'lastSeenAt': FieldValue.serverTimestamp(),
      };
      if (licenseCode != null && licenseCode.isNotEmpty) {
        payload['licenseCode'] = licenseCode;
      }
      await FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceId)
          .set(payload, SetOptions(merge: true));
    } catch (e) {
      debugPrint('TeamModeService: فشل ربط الجهاز بالترخيص — $e');
    }
  }

  /// بس على جهاز المدرس: كل ما حالة الترخيص الحقيقية (Firebase) تتغيّر
  /// محليًا، بنبعتها لسيرفر الفريق — عشان لو الترخيص خلص/اتوقف، كل
  /// أعضاء الفريق (المدرس والمساعدين) يتقفلوا مع بعض فورًا، مش بس
  /// جهاز المدرس. الحظر الفعلي بيحصل عن طريق RLS على السيرفر.
  void _watchOwnerLicense(SupabaseClient client, String tId) {
    _licenseWorker?.dispose();
    // لازم نراقب state وplan مع بعض (مش state بس) — تنزيل الباقة من
    // احترافي لأساسي مثلاً بيسيب state زي ما هو "active"، فمراقبة
    // state لوحدها كانت مش هتلاحظ التغيير ده خالص ومكانتش هتبعت تحديث.
    _licenseWorker = everAll(
      [LicenseController.to.state, LicenseController.to.plan],
      (_) => _pushLicenseStatus(client, tId, _hasRealPaidLicense),
    );
    _pushLicenseStatus(client, tId, _hasRealPaidLicense);
  }

  /// عمدًا مش بنستخدم LicenseController.isActive (بتتحقق صح لـ trial
  /// كمان) — وبنتأكد كمان من الباقة نفسها، لأن تفعيل وضع الفريق كمدرس
  /// أصلاً شرطه باقة احترافية/مدى الحياة حقيقية، مش أي حالة "قابلة
  /// للاستخدام". لو حصل احتمال نادر (الترخيص اتحذف والجهاز لسه مؤهل
  /// لتجربة جديدة، أو الباقة اتنزّلت لأساسي من غير ما الحالة تتغيّر)،
  /// الفريق المفروض يتقفل فورًا برضو.
  bool get _hasRealPaidLicense =>
      LicenseController.to.state.value == LicenseState.active &&
      (LicenseController.to.plan.value == AppPlan.pro ||
          LicenseController.to.plan.value == AppPlan.lifetime);

  Future<void> _pushLicenseStatus(
      SupabaseClient client, String tId, bool active) async {
    try {
      await client.rpc('set_team_license_active',
          params: {'_team_id': tId, '_active': active});
    } catch (e) {
      debugPrint('TeamModeService: فشل تحديث حالة الترخيص للفريق — $e');
    }
  }

  Future<void> _refreshMyPermissions(SupabaseClient client, String tId) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final rows = await client
          .from('team_members')
          .select()
          .eq('team_id', tId)
          .eq('user_id', uid);
      if (rows.isEmpty) return;
      final m = rows.first;
      isOwner.value = m['is_owner'] as bool? ?? false;
      canDeleteAttendance.value = m['can_delete_attendance'] as bool? ?? false;
      canDeletePayments.value = m['can_delete_payments'] as bool? ?? false;
      canDeleteStudents.value = m['can_delete_students'] as bool? ?? false;
      canManageMembers.value = m['can_manage_members'] as bool? ?? false;
    } catch (e) {
      debugPrint('TeamModeService: فشل تحميل الصلاحيات — $e');
    }
  }

  // ── إدارة الأعضاء (owner أو أي حد عنده can_manage_members) ────────
  /// بترجع (عدد المساعدين الحاليين, الحد الأقصى المسموح) — بتُستخدم
  /// عشان نمنع توليد كود دعوة جديد من الأساس لو الفريق وصل للحد،
  /// بدل ما نسيب المدرس يبعت كود للمساعد وبعدين يترفض وقت الانضمام.
  Future<(int, int)> getAssistantCapacity() async {
    final client = await _auth.ensureClient();
    if (client == null || teamId.value == null) return (0, 1);
    try {
      final members = await client
          .from('team_members')
          .select('is_owner')
          .eq('team_id', teamId.value as Object) as List;
      final current = members.where((m) => m['is_owner'] != true).length;
      final teamRow = await client
          .from('teams')
          .select('max_assistants')
          .eq('id', teamId.value as Object)
          .single();
      final max = (teamRow['max_assistants'] as num?)?.toInt() ?? 1;
      return (current, max);
    } catch (e) {
      debugPrint('TeamModeService: فشل تحميل سعة الفريق — $e');
      return (0, 1);
    }
  }

  /// بترجع (كود الدعوة, null) لو نجحت، أو (null, رسالة الخطأ) لو فشلت.
  Future<(String?, String?)> createInvite() async {
    final client = await _auth.ensureClient();
    if (client == null || teamId.value == null) {
      return (null, 'مفيش فريق مفعّل على الجهاز ده');
    }
    try {
      final code = await client
          .rpc('create_invite', params: {'_team_id': teamId.value}) as String;
      return (code, null);
    } catch (e) {
      debugPrint('TeamModeService: فشل توليد كود الدعوة — $e');
      final msg = e.toString().toLowerCase();
      if (msg.contains('not authorized')) {
        return (
          null,
          'الفريق المحفوظ على جهازك مش موجود على السيرفر — عطّل وضع الفريق وفعّله تاني'
        );
      }
      return (null, 'تعذر توليد كود الدعوة — تأكد من الإنترنت وحاول تاني');
    }
  }

  Future<List<Map<String, dynamic>>> listMembers() async {
    final client = await _auth.ensureClient();
    if (client == null || teamId.value == null) return [];
    try {
      final members = await client
          .from('team_members')
          .select()
          .eq('team_id', teamId.value as Object) as List;
      final userIds = members.map((m) => m['user_id'] as String).toList();
      if (userIds.isEmpty) return [];
      final profiles =
          await client.from('profiles').select().inFilter('id', userIds) as List;
      final profileMap = {
        for (final p in profiles) p['id'] as String: p as Map<String, dynamic>,
      };
      return members.map((m) {
        final map = m as Map<String, dynamic>;
        final p = profileMap[map['user_id']];
        return {
          ...map,
          'phone': p?['phone'],
          'display_name': p?['display_name'],
        };
      }).toList();
    } catch (e) {
      debugPrint('TeamModeService: فشل تحميل الأعضاء — $e');
      return [];
    }
  }

  /// بترجع رسالة خطأ بالعربي، أو null لو نجح التحديث.
  Future<String?> updateMemberPermission(
      String userId, String field, bool value) async {
    final client = await _auth.ensureClient();
    if (client == null || teamId.value == null) {
      return 'مفيش فريق مفعّل على الجهاز ده';
    }
    try {
      final res = await client
          .from('team_members')
          .update({field: value})
          .eq('team_id', teamId.value as Object)
          .eq('user_id', userId)
          .select();
      if ((res).isEmpty) {
        return 'تعذر التحديث — تأكد إن عندك صلاحية إدارة الأعضاء';
      }
      return null;
    } catch (e) {
      debugPrint('TeamModeService: فشل تحديث الصلاحية — $e');
      return 'تعذر التحديث — تأكد من الإنترنت وحاول تاني';
    }
  }

  /// بترجع رسالة خطأ بالعربي، أو null لو نجحت الإزالة.
  Future<String?> removeMember(String userId) async {
    final client = await _auth.ensureClient();
    if (client == null || teamId.value == null) {
      return 'مفيش فريق مفعّل على الجهاز ده';
    }
    try {
      final res = await client
          .from('team_members')
          .delete()
          .eq('team_id', teamId.value as Object)
          .eq('user_id', userId)
          .select();
      if ((res).isEmpty) {
        return 'تعذر إزالة العضو — تأكد إن عندك صلاحية إدارة الأعضاء';
      }
      return null;
    } catch (e) {
      debugPrint('TeamModeService: فشل إزالة العضو — $e');
      return 'تعذر إزالة العضو — تأكد من الإنترنت وحاول تاني';
    }
  }
}
