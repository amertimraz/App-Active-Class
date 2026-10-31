// lib/controllers/announcement_controller.dart
//
// spec 054 — حالة الإعلانات في التطبيق: بيحمّل الكاش فورًا، بيشترك في Firestore،
// بيختار الإعلان المناسب لكل مكان بحسب باقة العميل، وبيدير الإغلاق/المرة
// الواحدة (نافذة + إشعار). كل الفشل صامت.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/models/announcement_model.dart';
import 'package:active_class/services/announcement_service.dart';
import 'package:active_class/services/notification_service.dart';
import 'package:active_class/utils/announcement_logic.dart';

class AnnouncementController extends GetxController {
  AnnouncementController({
    AnnouncementService? service,
    DateTime Function()? clock,
    String Function()? planKey,
    bool listenRemote = true,
  })  : _service = service ?? AnnouncementService.instance,
        _clock = clock ?? DateTime.now,
        _planKeyOverride = planKey,
        _listenRemote = listenRemote;

  final AnnouncementService _service;
  final DateTime Function() _clock;
  final String Function()? _planKeyOverride;
  final bool _listenRemote;

  final items = <Announcement>[].obs;

  /// مفاتيح "اتقفل" لكل مكان (home/plans) — محلية، في الذاكرة + SharedPreferences.
  final dismissed = <String, String>{}.obs;

  /// بيتغيّر كل 30 ثانية وعند انتهاء عدّاد، عشان الـObx يعيد الاختيار
  /// (بداية/انتهاء إعلان من غير أي تحديث من السيرفر).
  final _tick = 0.obs;

  StreamSubscription<List<Announcement>>? _sub;
  Timer? _timer;
  Worker? _planWorker;

  String get planKey {
    final o = _planKeyOverride;
    if (o != null) return o();
    if (Get.isRegistered<LicenseController>()) {
      return Get.find<LicenseController>().plan.value.name;
    }
    return 'trial';
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final p in [AnnouncementPlacement.home, AnnouncementPlacement.plans]) {
        final v = prefs.getString(annDismissKey(p));
        if (v != null) dismissed[p.name] = v;
      }
    } catch (_) {}
    items.assignAll(await _service.loadCache());

    // باقة العميل تتحفظ للمهمة الخلفية (اللي مالهاش وصول للـController).
    if (_planKeyOverride == null && Get.isRegistered<LicenseController>()) {
      final lc = Get.find<LicenseController>();
      unawaited(_savePlan(lc.plan.value.name));
      _planWorker = ever(lc.plan, (p) => unawaited(_savePlan(p.name)));
    }

    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick.value++);

    if (_listenRemote) {
      try {
        _sub = _service.watch().listen((list) {
          items.assignAll(list);
          unawaited(_service.saveCache(list));
          unawaited(maybeNotify());
        }, onError: (e) => debugPrint('AnnouncementController.watch: $e'));
      } catch (e) {
        debugPrint('AnnouncementController: تعذّر الاشتراك — $e');
      }
    }
    unawaited(maybeNotify());
  }

  Future<void> _savePlan(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kAnnPlanKey, key);
    } catch (_) {}
  }

  /// الإعلان الظاهر في [placement] دلوقتي (بعد الاستبعاد لو اتقفل)، أو null.
  /// بتقرا Rx داخلها فتصلح داخل Obx.
  Announcement? forPlacement(AnnouncementPlacement placement) {
    _tick.value; // اشتراك في التحديث الدوري
    final a = pickAnnouncement(items,
        now: _clock(), planKey: planKey, placement: placement);
    if (a == null) return null;
    if (dismissed[placement.name] == a.displayKey) return null;
    return a;
  }

  Future<void> dismiss(AnnouncementPlacement placement, Announcement a) async {
    dismissed[placement.name] = a.displayKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(annDismissKey(placement), a.displayKey);
    } catch (_) {}
  }

  /// تنبيه من عدّاد البنر إنه خلص → إعادة اختيار.
  void reevaluate() => _tick.value++;

  /// النافذة المنبثقة: بترجّع الإعلان المطلوب عرضه (مرة واحدة لكل إصدار) وبتحجز
  /// المفتاح قبل ما ترجع عشان مفيش تكرار. null لو مفيش.
  Future<Announcement?> takePopup() async {
    final a = pickAnnouncement(items,
        now: _clock(), planKey: planKey, placement: AnnouncementPlacement.popup);
    if (a == null) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!shouldShowOnce(prefs.getString(kAnnPopupSeenKey), a.displayKey)) {
        return null;
      }
      await prefs.setString(kAnnPopupSeenKey, a.displayKey);
      return a;
    } catch (_) {
      return null;
    }
  }

  /// إشعار نظام مرة واحدة لكل إصدار (المقدمة). بيعيد قراءة المفتاح قبل الإظهار
  /// عشان تسابق المهمة الخلفية.
  Future<void> maybeNotify() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final n = notificationToSend(items,
          now: _clock(),
          planKey: planKey,
          lastNotifiedKey: prefs.getString(kAnnNotifiedKey));
      if (n == null) return;
      await prefs.setString(kAnnNotifiedKey, n.key);
      await NotificationService().showAnnouncement(n.announcement,
          title: n.title, body: n.body);
    } catch (e) {
      debugPrint('AnnouncementController.maybeNotify فشل: $e');
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    _timer?.cancel();
    _planWorker?.dispose();
    super.onClose();
  }
}
