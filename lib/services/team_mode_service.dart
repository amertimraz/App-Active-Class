// lib/services/team_mode_service.dart
//
// "وضع الفريق" — يبني فوق نظام تسجيل الدخول المستقل (Supabase)
// وSyncEngine. المدرس (owner) بيفعّله وبيبعت كود دعوة، والمساعد
// بيسجّل حسابه الخاص (نفس شاشات الدخول الموجودة) وينضم بالكود.
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/services/auth_service.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/sync_engine.dart';

class TeamModeService {
  static final TeamModeService _instance = TeamModeService._internal();
  factory TeamModeService() => _instance;
  TeamModeService._internal();

  final AuthService _auth = AuthService();
  final DatabaseService _db = DatabaseService();
  SyncEngine? _engine;

  final isEnabled = false.obs;
  final teamId = RxnString();
  final isOwner = false.obs;
  final canDeleteAttendance = false.obs;
  final canDeletePayments = false.obs;
  final canDeleteStudents = false.obs;
  final canManageMembers = false.obs;
  final loading = false.obs;

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
      final newTeamId = await client.rpc('create_team') as String;
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
    await _db.setSetting(SETTING_TEAM_MODE_ENABLED, 'false');
    LicenseController.to.teamModeBypassLimits = false;
    isEnabled.value = false;
    teamId.value = null;
    isOwner.value = false;
  }

  void _startEngine(SupabaseClient client, String tId) {
    final deviceId = LicenseController.to.deviceId.value;
    _engine = SyncEngine(client: client, teamId: tId, deviceId: deviceId);
    _engine!.start();
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
  Future<String?> createInvite() async {
    final client = await _auth.ensureClient();
    if (client == null || teamId.value == null) return null;
    try {
      return await client
          .rpc('create_invite', params: {'_team_id': teamId.value}) as String;
    } catch (e) {
      debugPrint('TeamModeService: فشل توليد كود الدعوة — $e');
      return null;
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

  Future<void> updateMemberPermission(
      String userId, String field, bool value) async {
    final client = await _auth.ensureClient();
    if (client == null || teamId.value == null) return;
    await client
        .from('team_members')
        .update({field: value})
        .eq('team_id', teamId.value as Object)
        .eq('user_id', userId);
  }

  Future<void> removeMember(String userId) async {
    final client = await _auth.ensureClient();
    if (client == null || teamId.value == null) return;
    await client
        .from('team_members')
        .delete()
        .eq('team_id', teamId.value as Object)
        .eq('user_id', userId);
  }
}
