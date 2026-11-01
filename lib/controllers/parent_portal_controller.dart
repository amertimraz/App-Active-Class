// lib/controllers/parent_portal_controller.dart
//
// حالة قسم "بوابة أولياء الأمور" في تطبيق المدرس: الرابط (slug) وآخر نشر.
// بيلفّ ParentPortalService من غير ما يغيّر سلوكه — النشر والحماية والمسارات
// كلها لسه هناك.
import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:get/get.dart';

import 'package:active_class/services/parent_portal_service.dart';
import 'package:active_class/utils/parent_portal_helper.dart';

class ParentPortalController extends GetxController {
  final RxnString slug = RxnString();
  final RxBool loading = true.obs;
  final RxBool publishing = false.obs;
  final Rxn<DateTime> lastPublishedAt = Rxn<DateTime>();
  final RxnInt lastPublishedCount = RxnInt();

  /// رابط المتابعة، أو فاضي لحد ما الـslug يتحمّل.
  String get url => slug.value == null ? '' : portalUrl(slug.value!);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    try {
      slug.value = await ParentPortalService().ensureSlug();
      // ننشر بروفايل المدرس (اسمه) فورًا من غير ما ننتظر أول طالب — وإلا
      // صفحة المتابعة تفضل من غير اسم لحد ما تتنشر أول بيانات طالب.
      unawaited(ParentPortalService().publishProfile());
    } catch (e) {
      debugPrint('ParentPortalController.load failed — $e');
    } finally {
      loading.value = false;
    }
  }

  /// بينشر كل الطلاب ويرجّع عددهم. بيرمي الخطأ لصاحب الاستدعاء (الشاشة بتعرض
  /// رسالة واضحة) — Firestore بترفض الدفعة كلها لو صف واحد اترفض.
  Future<int> publishAll() async {
    publishing.value = true;
    try {
      final n = await ParentPortalService().publishAllStudents();
      lastPublishedAt.value = DateTime.now();
      lastPublishedCount.value = n;
      return n;
    } finally {
      publishing.value = false;
    }
  }
}
