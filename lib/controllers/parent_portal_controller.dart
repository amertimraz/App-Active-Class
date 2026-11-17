// lib/controllers/parent_portal_controller.dart
//
// حالة قسم "بوابة أولياء الأمور" في تطبيق المدرس: الرابط (slug) وآخر نشر.
// بيلفّ ParentPortalService من غير ما يغيّر سلوكه — النشر والحماية والمسارات
// كلها لسه هناك.
import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'package:active_class/services/parent_portal_service.dart';
import 'package:active_class/utils/parent_portal_helper.dart';

class ParentPortalController extends GetxController
    with WidgetsBindingObserver {
  final RxnString slug = RxnString();
  final RxBool loading = true.obs;
  final RxBool publishing = false.obs;
  // تقدّم النشر الشامل (تم/الإجمالي) + «تم النشر» لثواني بعد النجاح.
  final RxInt publishDone = 0.obs;
  final RxInt publishTotal = 0.obs;
  final RxBool justPublished = false.obs;
  Timer? _justPublishedTimer;
  final Rxn<DateTime> lastPublishedAt = Rxn<DateTime>();
  final RxnInt lastPublishedCount = RxnInt();

  /// زيارات أولياء الأمور (معرّف مستند الطالب → عدّاد وآخر زيارة).
  final RxMap<String, PortalVisit> visits = <String, PortalVisit>{}.obs;
  final RxBool visitsLoaded = false.obs;

  /// رابط المتابعة، أو فاضي لحد ما الـslug يتحمّل.
  String get url => slug.value == null ? '' : portalUrl(slug.value!);

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _justPublishedTimer?.cancel();
    super.onClose();
  }

  // المدرس بيرجع للتطبيق بعد ما يجرّب الرابط → نحدّث «فتحوا الرابط» من غير ما
  // يضطر يقفل الشاشة ويفتحها.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // بنحدّث بس لو شاشة البوابة أو طلابها مفتوحة، وبفاصل دقيقة على الأقل — كل
    // تحميل بيقرا مستند لكل طالب (قراءات Firestore).
    if (state == AppLifecycleState.resumed &&
        slug.value != null &&
        screensOpen > 0 &&
        DateTime.now().difference(_visitsAt) > const Duration(minutes: 1)) {
      unawaited(loadVisits());
    }
  }

  Future<void> load() async {
    loading.value = true;
    try {
      slug.value = await ParentPortalService().ensureSlug();
      // ننشر بروفايل المدرس (اسمه) فورًا من غير ما ننتظر أول طالب — وإلا
      // صفحة المتابعة تفضل من غير اسم لحد ما تتنشر أول بيانات طالب.
      unawaited(ParentPortalService().publishProfile());
      unawaited(loadVisits());
    } catch (e) {
      debugPrint('ParentPortalController.load failed — $e');
    } finally {
      loading.value = false;
    }
  }

  /// يحمّل زيارات أولياء الأمور من السيرفر.
  /// عدد شاشات البوابة المفتوحة حاليًا (بتزوّده/تنقصه الشاشات نفسها).
  int screensOpen = 0;
  DateTime _visitsAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> loadVisits() async {
    _visitsAt = DateTime.now();
    final v = await ParentPortalService().loadVisits();
    visits.assignAll(v);
    visitsLoaded.value = true;
  }

  /// بينشر كل الطلاب ويرجّع عددهم. بيرمي الخطأ لصاحب الاستدعاء (الشاشة بتعرض
  /// رسالة واضحة) — Firestore بترفض الدفعة كلها لو صف واحد اترفض.
  Future<int> publishAll({bool force = false}) async {
    publishing.value = true;
    justPublished.value = false;
    publishDone.value = 0;
    publishTotal.value = 0;
    try {
      final n = await ParentPortalService().publishAllStudents(force: force, onProgress: (d, t) {
        publishDone.value = d;
        publishTotal.value = t;
      });
      lastPublishedAt.value = DateTime.now();
      lastPublishedCount.value = n;
      justPublished.value = true;
      unawaited(loadVisits());
      _justPublishedTimer?.cancel();
      _justPublishedTimer =
          Timer(const Duration(seconds: 5), () => justPublished.value = false);
      return n;
    } finally {
      publishing.value = false;
    }
  }
}
