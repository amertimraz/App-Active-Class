// lib/services/team_settings_service.dart
//
// الإعدادات المشتركة بين المدرس والمساعدين (جدول team_settings على Supabase):
//   - المدرس (المالك): أي تغيير في إعداد مشترك بيترفع تلقائيًا (دفعة صغيرة
//     بعد ثانية)، وبيترفع كله مرة عند بدء المزامنة.
//   - المساعد: بيسحب القيم مع كل catchUpPull ويطبّقها محليًا، وما يقدرش
//     يعدّلها (الواجهة بتقفلها، و_dbSet في SettingsController شبكة أمان).
// المفاتيح المشتركة في utils/team_shared_settings.dart. قيمة null = الافتراضي.
import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:active_class/controllers/dashboard_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/team_shared_settings.dart';

const Duration _kSettingsNetworkTimeout = Duration(seconds: 15);

class TeamSettingsService {
  static final TeamSettingsService _instance = TeamSettingsService._internal();
  factory TeamSettingsService() => _instance;
  TeamSettingsService._internal();

  SupabaseClient? _client;
  String? _teamId;
  bool _owner = false;
  final Map<String, String?> _pending = {};
  Timer? _flushTimer;
  bool _busy = false;

  /// هل الإعداد ده مقفول على الجهاز ده (مساعد في فريق + إعداد مشترك)؟
  static bool isLocked(String key) =>
      !kIsWeb && TeamModeService().isAssistant && isSharedSettingKey(key);

  /// رسالة موحّدة لما المساعد يحاول يغيّر إعداد مقفول.
  static void notifyLocked() =>
      ToastHelper.info('الإعداد ده بيتحكم فيه المدرس من جهازه');

  void attach(SupabaseClient client, String teamId, {required bool isOwner}) {
    _client = client;
    _teamId = teamId;
    _owner = isOwner;
    _pending.clear();
    if (isOwner) {
      unawaited(pushAll());
    } else {
      unawaited(pullAndApply());
    }
  }

  void detach() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _pending.clear();
    _client = null;
    _teamId = null;
    _owner = false;
  }

  /// بيتنادى مع كل catchUpPull: المدرس يرفع الباقي، والمساعد يسحب.
  Future<void> sync() async {
    if (_client == null) return;
    if (_owner) {
      await flush();
    } else {
      await pullAndApply();
    }
  }

  // ── المدرس: رفع ─────────────────────────────────────────────
  /// بيتنادى من SettingsController بعد كل كتابة محلية.
  void onLocalWrite(String key, String? value) {
    if (_client == null || !_owner || !isSharedSettingKey(key)) return;
    _pending[key] = value;
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(seconds: 1), () => unawaited(flush()));
  }

  Future<void> flush() async {
    final client = _client;
    final teamId = _teamId;
    if (client == null || teamId == null || !_owner || _pending.isEmpty) return;
    final batch = Map<String, String?>.of(_pending);
    try {
      await client.from('team_settings').upsert([
        for (final e in batch.entries)
          {'team_id': teamId, 'key': e.key, 'value': e.value},
      ], onConflict: 'team_id,key').timeout(_kSettingsNetworkTimeout);
      // ما نمسحش اللي اتغيّر أثناء الإرسال.
      batch.forEach((k, v) {
        if (_pending[k] == v) _pending.remove(k);
      });
    } catch (e) {
      debugPrint('TeamSettingsService.flush failed — $e');
      // هيتعاد مع أقرب sync().
    }
  }

  /// كل المفاتيح المشتركة بقيمها الحالية (null = افتراضي) — عشان المساعد
  /// يتطابق تمامًا حتى لو المدرس ما غيّرش إعداد معيّن قبل كده.
  Future<void> pushAll() async {
    if (_client == null || !_owner) return;
    final db = DatabaseService();
    for (final k in kTeamSharedSettingKeys) {
      try {
        _pending[k] = await db.getSetting(k);
      } catch (_) {}
    }
    await flush();
  }

  // ── المساعد: سحب وتطبيق ─────────────────────────────────────
  Future<void> pullAndApply() async {
    final client = _client;
    final teamId = _teamId;
    if (client == null || teamId == null || _owner || _busy) return;
    _busy = true;
    try {
      final rows = await client
          .from('team_settings')
          .select('key, value')
          .eq('team_id', teamId)
          .timeout(_kSettingsNetworkTimeout);
      final remote = <String, String?>{
        for (final r in rows as List) r['key'] as String: r['value'] as String?,
      };
      if (remote.isEmpty) return;
      final db = DatabaseService();
      final local = <String, String?>{
        for (final k in remote.keys) k: await db.getSetting(k),
      };
      final changes = sharedSettingsToApply(remote: remote, local: local);
      if (changes.isEmpty) return;
      for (final e in changes.entries) {
        if (e.value == null) {
          await db.clearSetting(e.key);
          // SettingsController بيرحّل القيمة القديمة من SharedPreferences لو
          // مفتاحها مش في القاعدة — لو سبناها كانت هترجع في أول تحميل
          // وتختلف عن المدرس تاني (تحديث متكرر + إشعار كل دقيقة).
          try {
            (await SharedPreferences.getInstance()).remove(e.key);
          } catch (_) {}
        } else {
          await db.setSetting(e.key, e.value!);
        }
      }
      if (Get.isRegistered<SettingsController>()) {
        await Get.find<SettingsController>().reloadFromDatabase();
      }
      if (Get.isRegistered<DashboardController>()) {
        unawaited(Get.find<DashboardController>().loadDashboardData());
      }
      ToastHelper.info('الإعدادات اتحدّثت من المدرس');
    } catch (e) {
      debugPrint('TeamSettingsService.pullAndApply failed — $e');
    } finally {
      _busy = false;
    }
  }
}
