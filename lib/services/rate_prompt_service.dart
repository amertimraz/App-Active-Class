// lib/services/rate_prompt_service.dart
//
// حالة نافذة التقييم (SharedPreferences) + تنفيذ الإجراءات. كل فشل صامت.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:active_class/utils/rate_prompt.dart';

class RatePromptService {
  RatePromptService._();
  static final RatePromptService instance = RatePromptService._();

  static const _kFirst = 'rate_first_seen';
  static const _kLaunches = 'rate_launches';
  static const _kLast = 'rate_last_shown';
  static const _kLater = 'rate_later';
  static const _kDone = 'rate_done';

  bool _countedThisProcess = false;

  DateTime? _ms(int? v) =>
      v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);

  Future<RatePromptState> load() async {
    final p = await SharedPreferences.getInstance();
    return RatePromptState(
      firstSeen: _ms(p.getInt(_kFirst)),
      launches: p.getInt(_kLaunches) ?? 0,
      lastShown: _ms(p.getInt(_kLast)),
      laterCount: p.getInt(_kLater) ?? 0,
      done: p.getBool(_kDone) ?? false,
    );
  }

  /// مرة لكل تشغيل للتطبيق.
  Future<void> registerLaunch({DateTime? now}) async {
    if (_countedThisProcess) return;
    _countedThisProcess = true;
    try {
      final p = await SharedPreferences.getInstance();
      if (!p.containsKey(_kFirst)) {
        await p.setInt(_kFirst, (now ?? DateTime.now()).millisecondsSinceEpoch);
      }
      await p.setInt(_kLaunches, (p.getInt(_kLaunches) ?? 0) + 1);
    } catch (e) {
      debugPrint('RatePromptService.registerLaunch: $e');
    }
  }

  Future<bool> shouldShow({DateTime? now}) async {
    try {
      return shouldShowRatePrompt(await load(), now ?? DateTime.now());
    } catch (_) {
      return false;
    }
  }

  Future<void> markShown({DateTime? now}) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_kLast, (now ?? DateTime.now()).millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> markLater() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_kLater, (p.getInt(_kLater) ?? 0) + 1);
    } catch (_) {}
  }

  /// "قيّم الآن": بنعتبره خلص (مش بنقدر نعرف لو فعلًا قيّم) ونفتح Google Play.
  Future<void> rateNow() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kDone, true);
    } catch (_) {}
    try {
      if (!await launchUrl(playMarketUri(),
          mode: LaunchMode.externalApplication)) {
        await launchUrl(playWebUri(), mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(playWebUri(), mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('RatePromptService.rateNow: $e');
      }
    }
  }
}
