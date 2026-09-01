// lib/controllers/license_controller.dart
import 'dart:async';
import 'dart:io';
import 'package:android_id/android_id.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// ── حالة الترخيص ──────────────────────────────────────────────────────────────
enum LicenseState {
  loading, // جاري التحقق
  trial, // تجربة مجانية نشطة
  trialExpired, // انتهت التجربة بدون ترخيص
  active, // ترخيص ساري
  suspended, // ترخيص موقوف
  expired, // ترخيص منتهي الصلاحية
}

// ── باقات التطبيق ──────────────────────────────────────────────────────────────
enum AppPlan { trial, basic, pro, lifetime }

extension AppPlanExt on AppPlan {
  String get nameAr {
    switch (this) {
      case AppPlan.trial:
        return 'تجريبي';
      case AppPlan.basic:
        return 'أساسي';
      case AppPlan.pro:
        return 'احترافي';
      case AppPlan.lifetime:
        return 'مدى الحياة';
    }
  }

  int get maxGroups => <AppPlan, int>{
        AppPlan.trial: 2,
        AppPlan.basic: 5,
        AppPlan.pro: -1,
        AppPlan.lifetime: -1
      }[this]!;
  int get maxStudents => <AppPlan, int>{
        AppPlan.trial: 15,
        AppPlan.basic: 30,
        AppPlan.pro: -1,
        AppPlan.lifetime: -1
      }[this]!;
  bool get canBackup => this != AppPlan.trial;
  bool get canExport => this != AppPlan.trial;
  bool get canWhatsApp => this == AppPlan.pro || this == AppPlan.lifetime;
  bool get canBooking => this == AppPlan.pro || this == AppPlan.lifetime;
}

// ── الحدود حسب الباقة ─────────────────────────────────────────────────────────
class _Limits {
  final int maxGroups; // -1 = غير محدود
  final int maxStudents;
  final bool canBackup;
  final bool canExport;
  final bool canWhatsApp;
  final bool canBooking;

  const _Limits({
    required this.maxGroups,
    required this.maxStudents,
    required this.canBackup,
    required this.canExport,
    required this.canWhatsApp,
    required this.canBooking,
  });

  static const trial = _Limits(
      maxGroups: 2,
      maxStudents: 15,
      canBackup: false,
      canExport: false,
      canWhatsApp: false,
      canBooking: false);
  static const basic = _Limits(
      maxGroups: 5,
      maxStudents: 30,
      canBackup: true,
      canExport: true,
      canWhatsApp: false,
      canBooking: false);
  static const pro = _Limits(
      maxGroups: -1,
      maxStudents: -1,
      canBackup: true,
      canExport: true,
      canWhatsApp: true,
      canBooking: true);
  static const lifetime = _Limits(
      maxGroups: -1,
      maxStudents: -1,
      canBackup: true,
      canExport: true,
      canWhatsApp: true,
      canBooking: true);
}

// ── المتحكم الرئيسي ───────────────────────────────────────────────────────────
class LicenseController extends GetxController {
  static LicenseController get to => Get.find();

  // Observable state
  final state = LicenseState.loading.obs;
  final plan = AppPlan.trial.obs;
  final trialDaysLeft = 7.obs;
  final deviceId = ''.obs;
  final deviceName = ''.obs;
  /// إضافة مدفوعة منفصلة عن الباقة — بوابة متابعة أولياء الأمور.
  /// تتحدّث من نفس مستند الترخيص، الأدمن بيفعّلها/يلغيها لوحدها.
  final parentPortalEnabled = false.obs;
  /// تاريخ انتهاء مستقل لبوابة أولياء الأمور بس (منفصل تمامًا عن
  /// [expiresAt] بتاع الترخيص الأساسي) — null يعني مدى الحياة.
  /// الأدمن بيضبطه يدويًا وقت ما المدرس يدفع رسوم الإضافة دي.
  final parentPortalExpiresAt = Rxn<DateTime>();
  /// عداد داخلي بيتحدّث كل 5 دقايق (راجع الفحص الدوري في onInit) —
  /// مقصود يكون Rx *منفصل* عن parentPortalEnabled/parentPortalExpiresAt
  /// عمدًا: أي Obx في الواجهة بيحتاج يعيد تقييم parentPortalActiveNow
  /// دوريًا لازم يقرأ العداد ده كمان (حتى لو مش مستخدم قيمته)، بدل ما
  /// نعمل .refresh() على parentPortalEnabled نفسه — ده كان هيشغّل أي
  /// ever()/everAll() متسجّل عليه (زي مراقبة إعادة النشر في
  /// ParentPortalService) كل 5 دقايق لكل مستخدمين التطبيق، حتى اللي
  /// معندهمش بوابة أولياء أمور خالص.
  final parentPortalRecheckTick = 0.obs;

  /// بيتزوّد كل مرة نقرأ فيها بيانات الترخيص من السيرفر بنجاح (تحقّق أولي
  /// أو تحديث realtime) — حتى لو القيم ما اتغيّرتش. ParentPortalService
  /// بيراقبه عشان يوفّق حالة البوابة العامة (active) مع الترخيص، بالذات
  /// لو الأدمن قفل البوابة والتطبيق كان مقفول (ساعتها parentPortalEnabled
  /// بيفضل false → false ومفيش أي everAll بيفير).
  final licenseVerifiedTick = 0.obs;

  /// "شغالة فعليًا دلوقتي" — مفعّلة أصلاً، ومدتها المستقلة (لو محددة)
  /// لسه ماعدّتش. مقارنة زمنية مباشرة بنفس نمط فحص انتهاء الترخيص
  /// الأساسي (راجع _validateLicense) — مش Rx، بيتقيّم عند كل استدعاء.
  bool get parentPortalActiveNow =>
      parentPortalEnabled.value &&
      (parentPortalExpiresAt.value == null ||
          parentPortalExpiresAt.value!.isAfter(DateTime.now()));

  /// يخزّن حالة بوابة أولياء الأمور محليًا بعد أي قراءة ناجحة من Firestore.
  Future<void> _persistParentPortal(SharedPreferences prefs) async {
    await prefs.setBool(_kParentPortalEnabled, parentPortalEnabled.value);
    final exp = parentPortalExpiresAt.value;
    if (exp != null) {
      await prefs.setInt(
          _kParentPortalExpiresAt, exp.millisecondsSinceEpoch);
    } else {
      await prefs.remove(_kParentPortalExpiresAt);
    }
  }

  /// يستعيد حالة بوابة أولياء الأمور من التخزين المحلي — يُستخدم في مسار
  /// الأوفلاين (grace period) عشان البوابة ما تختفيش بعد إعادة التثبيت.
  void _restoreParentPortal(SharedPreferences prefs) {
    parentPortalEnabled.value =
        prefs.getBool(_kParentPortalEnabled) ?? false;
    final ms = prefs.getInt(_kParentPortalExpiresAt);
    parentPortalExpiresAt.value =
        ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }
  final licenseCode = RxnString();
  final hasRequest = false.obs; // هل عنده طلب ترقية pending
  final expiresAt = Rxn<DateTime>(); // تاريخ انتهاء الترخيص

  /// طول الفترة التجريبية الفعلي — يبدأ بالقيمة الافتراضية [kTrialDays]
  /// وبيتحدّث لو فيه قيمة مختلفة على Firestore (app_config/limits).
  final trialDaysTotal = kTrialDays.obs;

  /// حدود الباقات — تبدأ بالقيم الافتراضية المدمجة في الكود، وبتتحدّث
  /// فورًا (بدون إعادة تشغيل التطبيق) لو الإدارة غيّرت المستند على
  /// Firestore. لو الجهاز أوفلاين أو المستند مش موجود، بتفضل القيم
  /// الافتراضية شغالة زي ما هي — التحكم المركزي ميزة إضافية مش شرط.
  final Map<AppPlan, _Limits> _remoteLimits = {
    AppPlan.trial: _Limits.trial,
    AppPlan.basic: _Limits.basic,
    AppPlan.pro: _Limits.pro,
    AppPlan.lifetime: _Limits.lifetime,
  };

  // Firebase — getters كسولة (مش final fields) عشان ما تتقيّمش عند بناء
  // الكلاس نفسه (Get.put في main.dart)؛ لو Firebase.initializeApp فشل،
  // أول لمسة فعلية بتحصل جوه try/catch في _init() بدل ما تكسر الإقلاع كله.
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  // Real-time listener على الترخيص النشط
  StreamSubscription? _licenseSubscription;

  // SharedPreferences keys
  static const _kDeviceId = 'lic_device_id';
  static const _kCode = 'lic_code';
  static const _kFirstLaunch = 'lic_first_launch';
  static const _kPlan = 'lic_plan';
  static const _kExpiresAt = 'lic_expires_at'; // مخزّنة عشان وضع الأوفلاين (grace period)
  static const _kHasRequest = 'lic_has_request';
  static const _kLastVerified = 'lic_last_verified'; // آخر تحقق ناجح من السيرفر
  // بوابة أولياء الأمور — مخزّنة محليًا زي الخطة/تاريخ الانتهاء، عشان بعد
  // إعادة تثبيت التطبيق (والبيانات لسه محفوظة) لو أول تحقق ترخيص حصل أوفلاين
  // أو النت بطيء، البوابة ما تختفيش لحد ما تحقق أونلاين ينجح. من غير ده كان
  // المدرس مضطر يقفلها/يفعّلها من لوحة الأدمن بعد كل تثبيت.
  static const _kParentPortalEnabled = 'lic_parent_portal_enabled';
  static const _kParentPortalExpiresAt = 'lic_parent_portal_expires_at';
  static const kTrialDays = 7;
  static const int _kGraceDays = 3; // مهلة الاستخدام أوفلاين بعد آخر تحقق ناجح

  // فحص دوري خفيف (بدون أي طلب شبكة) لإعادة تقييم parentPortalActiveNow —
  // من غيره، لو التطبيق فاضل مفتوح بالظبط وقت انتهاء مدة بوابة أولياء
  // الأمور، الواجهة مش هتعرف إلا لو حصل حدث Firestore جديد أو المستخدم
  // قفل التطبيق وفتحه تاني (راجع research.md قرار 3).
  Timer? _parentPortalRecheckTimer;
  static const Duration _kParentPortalRecheckInterval = Duration(minutes: 5);

  // ── init ──────────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _init();
    // إعادة تقييم دورية لـ parentPortalActiveNow — زيادة عداد منفصل
    // (مش .refresh() على parentPortalEnabled نفسه، عشان منشغّلش أي
    // ever()/everAll() متسجّل عليه بالغلط — راجع تعليق parentPortalRecheckTick)
    // بتبلّغ أي Obx بيقرا العداد ده إنه يعيد البناء، فيعيد حساب
    // parentPortalActiveNow بالوقت الحالي حتى لو مفيش تغيير فعلي في القيمة.
    _parentPortalRecheckTimer =
        Timer.periodic(_kParentPortalRecheckInterval, (_) {
      parentPortalRecheckTick.value++;
    });
  }

  Future<void> _init() async {
    try {
      // 1. تسجيل دخول مجهول (anonymous) للوصول لـ Firestore
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }
    } catch (_) {
      // offline — سنكمل بالـ cache
    }

    try {
      await _initDeviceId();
      final prefs = await SharedPreferences.getInstance();

      // تحميل حالة الطلب من الـ cache لتجنب الوميض عند إعادة التشغيل
      hasRequest.value = prefs.getBool(_kHasRequest) ?? false;

      final storedCode = prefs.getString(_kCode);

      if (storedCode != null) {
        await _validateLicense(storedCode, prefs);
      } else {
        await _checkTrial(prefs);
      }

      // تسجيل الجهاز في الخلفية
      _registerDevice();
      // فحص هل عنده طلب ترقية pending (real-time)
      _checkUpgradeRequest();
      // تحميل حدود الباقات من مكان مركزي (real-time) — مستقل تمامًا عن
      // حالة الترخيص، عشان يشتغل حتى في وضع التجربة.
      _watchRemoteConfig();
    } catch (e) {
      _loadCachedState();
    }
  }

  // ── Remote Config (حدود الباقات + مدة التجربة) ───────────────────────────
  StreamSubscription? _configSubscription;

  void _watchRemoteConfig() {
    _configSubscription?.cancel();
    _configSubscription =
        _db.collection('app_config').doc('limits').snapshots().listen((doc) {
      if (!doc.exists) return;
      final data = doc.data();
      if (data == null) return;
      try {
        final days = data['trialDays'];
        if (days is num && days > 0) trialDaysTotal.value = days.toInt();

        for (final entry in {
          'trial': AppPlan.trial,
          'basic': AppPlan.basic,
          'pro': AppPlan.pro,
          'lifetime': AppPlan.lifetime,
        }.entries) {
          final m = data[entry.key];
          if (m is! Map) continue;
          final current = _remoteLimits[entry.value]!;
          _remoteLimits[entry.value] = _Limits(
            maxGroups: (m['maxGroups'] as num?)?.toInt() ?? current.maxGroups,
            maxStudents:
                (m['maxStudents'] as num?)?.toInt() ?? current.maxStudents,
            canBackup: m['canBackup'] as bool? ?? current.canBackup,
            canExport: m['canExport'] as bool? ?? current.canExport,
            canWhatsApp: m['canWhatsApp'] as bool? ?? current.canWhatsApp,
            canBooking: m['canBooking'] as bool? ?? current.canBooking,
          );
        }
        // أعِد حساب الأيام المتبقية لو لسه في فترة تجريبية، عشان
        // التغيير في trialDays ينعكس فورًا من غير إعادة تشغيل.
        if (state.value == LicenseState.trial) {
          SharedPreferences.getInstance().then((prefs) => _checkTrial(prefs));
        }
      } catch (_) {}
    }, onError: (_) {});
  }

  // معرّف صالح إما hex عشوائي (ANDROID_ID، طوله عادةً 16) أو UUID v4
  // (شكل 8-4-4-4-12 بفواصل). أي شكل تاني (فيه نقطة، أو حروف كابيتال،
  // أو رقم موديل تجاري) بيعتبر قديم/غلط.
  static final _hexIdPattern = RegExp(r'^[0-9a-f]{8,32}$', caseSensitive: false);
  static final _uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false);

  bool _isValidGeneratedDeviceId(String id) {
    return _hexIdPattern.hasMatch(id) || _uuidPattern.hasMatch(id);
  }

  // ── Device ID ─────────────────────────────────────────────────────────────
  Future<void> _initDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kDeviceId);
    // القيم القديمة (قبل إصلاح Build.ID) شكلها متنوع حسب الشركة المصنّعة —
    // مش بس فيرموير Build.ID العادي (زي "BP2A.250605.031.A3")، لقينا كمان
    // موديلات هواوي/هونر بترجّع رقم الموديل التجاري بدل معرّف حقيقي (زي
    // "HONORABR-L32") — وكل الحالتين مشتركين بين آلاف الأجهزة بنفس الموديل،
    // مش فريدين. بدل ما نحاول نلاحق كل شكل قديم ممكن، بنتحقق إن القيمة
    // المحفوظة شكلها فعلاً معرّف حقيقي (hex عشوائي من ANDROID_ID، أو UUID
    // من الـ fallback) — أي حاجة تانية (فيها نقطة، شرطة، حروف كابيتال..)
    // بنعتبرها قديمة وغلط ونعيد حسابها.
    if (id != null && !_isValidGeneratedDeviceId(id)) {
      id = null;
    }
    if (id == null || id.isEmpty) {
      try {
        final plugin = DeviceInfoPlugin();
        if (!kIsWeb && Platform.isWindows) {
          final info = await plugin.windowsInfo;
          id = info.deviceId;
        } else if (!kIsWeb && Platform.isAndroid) {
          // ملحوظة: info.id (Build.ID) رقم إصدار الفيرموير مش معرّف فريد
          // للجهاز — أي جهازين بنفس الموديل والتحديث بياخدوا نفس القيمة.
          // ANDROID_ID (عبر حزمة android_id) فريد فعليًا لكل جهاز/تثبيت.
          id = await const AndroidId().getId() ?? const Uuid().v4();
        } else {
          id = const Uuid().v4();
        }
      } catch (_) {
        id = const Uuid().v4();
      }
      await prefs.setString(_kDeviceId, id);
    }
    deviceId.value = id;
  }

  // ── Trial Check ───────────────────────────────────────────────────────────
  Future<void> _checkTrial(SharedPreferences prefs) async {
    var firstLaunchMs = prefs.getInt(_kFirstLaunch);

    if (firstLaunchMs == null) {
      // أول تشغيل — نحاول نجيب التاريخ من Firestore (anti-reset cheat)
      try {
        final doc = await _db
            .collection('devices')
            .doc(deviceId.value)
            .get()
            .timeout(const Duration(seconds: 5));
        if (doc.exists) {
          final ts = doc.data()?['firstLaunchAt'] as Timestamp?;
          if (ts != null) {
            firstLaunchMs = ts.toDate().millisecondsSinceEpoch;
          }
        }
      } catch (_) {}
      firstLaunchMs ??= DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_kFirstLaunch, firstLaunchMs);
    }

    final firstLaunch = DateTime.fromMillisecondsSinceEpoch(firstLaunchMs);
    final elapsed = DateTime.now().difference(firstLaunch).inDays;
    final daysLeft = trialDaysTotal.value - elapsed;

    if (daysLeft > 0) {
      trialDaysLeft.value = daysLeft;
      plan.value = AppPlan.trial;
      state.value = LicenseState.trial;
    } else {
      trialDaysLeft.value = 0;
      state.value = LicenseState.trialExpired;
    }
  }

  // ── License Validation ────────────────────────────────────────────────────
  /// بيتحدّث لـ true لو آخر محاولة تحقق فشلت بسبب مشكلة اتصال قبل أي
  /// تحقق ناجح من السيرفر — يُستخدم في activateCode() عشان الرسالة
  /// تكون "تعذر الاتصال" مش "كود غير صالح" (الكود ممكن يكون سليم فعلاً).
  bool _lastValidationOffline = false;

  Future<void> _validateLicense(String code, SharedPreferences prefs) async {
    _lastValidationOffline = false;
    try {
      final doc = await _db
          .collection('licenses')
          .doc(code)
          .get()
          .timeout(const Duration(seconds: 6));

      if (!doc.exists) {
        // كود غير موجود — نرجع للتجربة
        await prefs.remove(_kCode);
        await _checkTrial(prefs);
        return;
      }

      // وصلنا للسيرفر فعلياً وقرأنا بيانات معتمدة — سجّل وقت التحقق
      // الناجح ده عشان يبدأ منه حساب مهلة الاستخدام أوفلاين لاحقاً.
      await prefs.setInt(_kLastVerified, DateTime.now().millisecondsSinceEpoch);

      final data = doc.data()!;
      final status = data['status'] as String? ?? 'active';
      final planStr = data['plan'] as String? ?? 'basic';
      final durationDays = (data['durationDays'] as num?)?.toInt();
      DateTime? effectiveExpiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      final boundDev = data['deviceId'] as String?;
      parentPortalEnabled.value = data['parentPortalEnabled'] as bool? ?? false;
      parentPortalExpiresAt.value =
          (data['parentPortalExpiresAt'] as Timestamp?)?.toDate();

      // الجهاز مربوط بجهاز آخر — الترخيص مش بتاع الجهاز ده، امسح أي كاش
      // لبوابة أولياء الأمور عشان مسار الأوفلاين ما يرجّعهاش.
      if (boundDev != null && boundDev != deviceId.value) {
        parentPortalEnabled.value = false;
        parentPortalExpiresAt.value = null;
        await prefs.remove(_kCode);
        await prefs.remove(_kParentPortalEnabled);
        await prefs.remove(_kParentPortalExpiresAt);
        state.value = LicenseState.trialExpired;
        return;
      }
      await _persistParentPortal(prefs);
      licenseVerifiedTick.value++;

      // ربط الجهاز إذا لم يكن مرتبطاً — أول تفعيل فعلي للكود.
      // العداد يبدأ من هنا بالظبط (مش من وقت إنشاء الكود في لوحة
      // الأدمن)، عشان المدرس ياخد مدة اشتراكه كاملة زي ما هي
      // (durationDays) بغض النظر عن تأخير التفعيل.
      if (boundDev == null) {
        try {
          final updateData = <String, dynamic>{
            'deviceId': deviceId.value,
            'activatedAt': Timestamp.now(),
          };
          if (durationDays != null && effectiveExpiresAt == null) {
            effectiveExpiresAt = DateTime.now().add(Duration(days: durationDays));
            updateData['expiresAt'] = Timestamp.fromDate(effectiveExpiresAt);
          }
          await _db.collection('licenses').doc(code).update(updateData);
        } catch (_) {}
      }

      // تحقق من الحالة
      if (status == 'suspended') {
        licenseCode.value = code;
        state.value = LicenseState.suspended;
        return;
      }

      if (effectiveExpiresAt != null &&
          effectiveExpiresAt.isBefore(DateTime.now())) {
        plan.value = _parsePlan(planStr);
        licenseCode.value = code;
        expiresAt.value = effectiveExpiresAt;
        state.value = LicenseState.expired;
        return;
      }

      // ✅ ترخيص سليم
      plan.value = _parsePlan(planStr);
      licenseCode.value = code;
      expiresAt.value = effectiveExpiresAt; // null = مدى الحياة
      state.value = LicenseState.active;
      await prefs.setString(_kPlan, planStr);
      if (effectiveExpiresAt != null) {
        await prefs.setInt(_kExpiresAt, effectiveExpiresAt.millisecondsSinceEpoch);
      } else {
        await prefs.remove(_kExpiresAt);
      }

      // ابدأ الاستماع للتغييرات في real-time
      _watchLicense(code, prefs);
    } catch (e) {
      // Offline أو فشل تحقق — نسمح باستخدام محدود (grace period) بدل
      // ثقة دائمة في آخر حالة معروفة، عشان تعليق/إلغاء ترخيص من لوحة
      // الإدارة ينعكس فعلياً حتى لو تعطّلت القراءة لفترة طويلة.
      debugPrint('LicenseController: تحقق الترخيص فشل — $e');
      final cachedPlan = prefs.getString(_kPlan) ?? 'basic';
      final lastVerified = prefs.getInt(_kLastVerified);

      if (lastVerified == null) {
        // أول محاولة تحقق للكود ده وفشلت — منقدرش نأكد إن الكود ده
        // موجود فعلاً على السيرفر، فمنمنحش وصول كامل بناءً على مجرد
        // صيغة صحيحة. نرجع لحالة التجربة (لو لسه سارية) والكود يفضل
        // محفوظ محلياً عشان يتحقق تلقائياً أول ما النت يرجع.
        _lastValidationOffline = true;
        await _checkTrial(prefs);
        return;
      }

      final daysSinceVerified = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(lastVerified))
          .inDays;

      if (daysSinceVerified <= _kGraceDays) {
        plan.value = _parsePlan(cachedPlan);
        licenseCode.value = code;
        final cachedExpiresMs = prefs.getInt(_kExpiresAt);
        expiresAt.value = cachedExpiresMs != null
            ? DateTime.fromMillisecondsSinceEpoch(cachedExpiresMs)
            : null;
        // استعِد حالة بوابة أولياء الأمور من الكاش — من غير ده كانت
        // بتختفي بعد كل إعادة تثبيت لحد ما يحصل تحقق أونلاين ناجح.
        _restoreParentPortal(prefs);
        state.value = LicenseState.active;
      } else {
        // انتهت مهلة الاستخدام بدون اتصال — لازم يتأكد من السيرفر تاني
        licenseCode.value = code;
        state.value = LicenseState.expired;
      }
    }
  }

  // ── Real-time License Watcher ─────────────────────────────────────────────
  void _watchLicense(String code, SharedPreferences prefs) {
    _licenseSubscription?.cancel();
    _licenseSubscription = _db
        .collection('licenses')
        .doc(code)
        .snapshots()
        .skip(1) // تخطي أول emission (محمّلة بالفعل في _validateLicense)
        .listen((doc) async {
      if (!doc.exists) {
        // ✅ الترخيص اتحذف من الـ admin
        await prefs.remove(_kCode);
        await prefs.remove(_kPlan);
        await prefs.remove(_kExpiresAt);
        await prefs.remove(_kParentPortalEnabled);
        await prefs.remove(_kParentPortalExpiresAt);
        licenseCode.value = null;
        expiresAt.value = null;
        parentPortalEnabled.value = false;
        parentPortalExpiresAt.value = null;
        await _checkTrial(prefs);
        return;
      }

      // كل رسالة real-time وصلت فعلاً = اتصال شغال بالسيرفر
      await prefs.setInt(_kLastVerified, DateTime.now().millisecondsSinceEpoch);

      final data = doc.data()!;
      final status = data['status'] as String? ?? 'active';
      final planStr = data['plan'] as String? ?? 'basic';
      final exp = (data['expiresAt'] as Timestamp?)?.toDate();
      parentPortalEnabled.value = data['parentPortalEnabled'] as bool? ?? false;
      parentPortalExpiresAt.value =
          (data['parentPortalExpiresAt'] as Timestamp?)?.toDate();
      await _persistParentPortal(prefs);
      licenseVerifiedTick.value++;

      if (status == 'suspended') {
        state.value = LicenseState.suspended;
      } else if (exp != null && exp.isBefore(DateTime.now())) {
        expiresAt.value = exp;
        state.value = LicenseState.expired;
      } else {
        plan.value = _parsePlan(planStr);
        expiresAt.value = exp;
        state.value = LicenseState.active;
        await prefs.setString(_kPlan, planStr);
        if (exp != null) {
          await prefs.setInt(_kExpiresAt, exp.millisecondsSinceEpoch);
        } else {
          await prefs.remove(_kExpiresAt);
        }
      }
    }, onError: (e) {
      // القراءة اتقطعت (مثلاً صلاحيات Firestore اتغيّرت) — سجّل الخطأ
      // بدل ما يتبلع بصمت؛ الحالة المخزّنة تفضل زي ما هي لحد ما
      // مهلة الـ grace period تنتهي في المحاولة الجاية لـ _validateLicense.
      debugPrint('LicenseController: انقطع الاستماع للترخيص — $e');
    });
  }

  @override
  void onClose() {
    _licenseSubscription?.cancel();
    _configSubscription?.cancel();
    _parentPortalRecheckTimer?.cancel();
    super.onClose();
  }

  void _loadCachedState() {
    // fallback if everything fails
    state.value = LicenseState.trial;
    trialDaysLeft.value = 1;
  }

  // ── Register Device ───────────────────────────────────────────────────────
  Future<void> _registerDevice() async {
    if (deviceId.value.isEmpty) return;
    try {
      String deviceName = 'Unknown Device';
      try {
        final plugin = DeviceInfoPlugin();
        if (!kIsWeb && Platform.isWindows) {
          final info = await plugin.windowsInfo;
          deviceName = '${info.computerName} / Windows';
        } else if (!kIsWeb && Platform.isAndroid) {
          final info = await plugin.androidInfo;
          deviceName = '${info.brand} ${info.model}';
        }
      } catch (_) {}
      this.deviceName.value = deviceName;

      // مهم: firstLaunchAt لازم يتكتب مرة واحدة بس (أول تسجيل للجهاز)،
      // وإلا كل فتح عادي للتطبيق كان بيدهسه بالوقت الحالي — يعني وقت
      // ما المستخدم يمسح التطبيق ويعيد تثبيته، القيمة المحفوظة على
      // Firestore (اللي المفروض تحمي من تصفير التجربة) تبقى "دلوقتي"
      // مش تاريخ أول تشغيل الحقيقي، فالتجربة كانت بترجع تتجدد فعليًا.
      final docRef = _db.collection('devices').doc(deviceId.value);
      final existing = await docRef.get();
      final hasFirstLaunch =
          existing.exists && existing.data()?['firstLaunchAt'] != null;

      final payload = <String, dynamic>{
        'deviceId': deviceId.value,
        'deviceName': deviceName,
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        'lastSeenAt': FieldValue.serverTimestamp(),
        'licenseState': state.value.name,
      };
      // ما نكتبش licenseCode فاضي — عند مساعد وضع الفريق (اللي معاهوش
      // ترخيص محلي) ده كان بيدهس كود ترخيص المدرس اللي TeamModeService
      // كاتبه على نفس المستند (سباق race condition بين الاتنين وقت فتح
      // التطبيق)، فيختفي الجهاز من تفاصيل الترخيص في لوحة الأدمن.
      if ((licenseCode.value ?? '').isNotEmpty) {
        payload['licenseCode'] = licenseCode.value;
      }
      if (!hasFirstLaunch) {
        payload['firstLaunchAt'] = FieldValue.serverTimestamp();
      }

      await docRef.set(payload, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Check Upgrade Request (real-time) ────────────────────────────────────
  void _checkUpgradeRequest() {
    if (deviceId.value.isEmpty) return;
    _db
        .collection('upgrade_requests')
        .where('deviceId', isEqualTo: deviceId.value)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) async {
      final prefs = await SharedPreferences.getInstance();

      if (snap.docs.isEmpty) {
        hasRequest.value = false;
        await prefs.setBool(_kHasRequest, false);
        return;
      }
      final doc = snap.docs.first;
      final status = (doc['status'] as String?) ?? '';

      if (status == 'pending') {
        // طلب قيد المراجعة — احفظ في SharedPreferences
        hasRequest.value = true;
        await prefs.setBool(_kHasRequest, true);
      } else if (status == 'approved') {
        // ✅ الـ admin وافق — فعّل الترخيص أوتوماتيك
        final code = (doc['licenseCode'] as String?) ?? '';
        if (code.isNotEmpty && state.value != LicenseState.active) {
          hasRequest.value = false;
          await prefs.setBool(_kHasRequest, false);
          await prefs.setString(_kCode, code);
          await _validateLicense(code, prefs);
        }
      } else {
        // مرفوض أو غير معروف
        hasRequest.value = false;
        await prefs.setBool(_kHasRequest, false);
      }
    }, onError: (e) {
      debugPrint('LicenseController: فشل متابعة طلب الترقية — $e');
    });
  }

  // ── Public: Activate Code ─────────────────────────────────────────────────
  Future<String?> activateCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (!RegExp(r'^ACTV-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$').hasMatch(code)) {
      return 'صيغة الكود غير صحيحة — يجب أن يكون ACTV-XXXX-XXXX-XXXX';
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCode, code);
    await _validateLicense(code, prefs);
    if (state.value == LicenseState.active) return null; // success
    if (_lastValidationOffline) {
      return 'تعذر التحقق من الكود — تأكد من الاتصال بالإنترنت وحاول تاني. '
          'سيتم التحقق تلقائياً بمجرد توفر الاتصال.';
    }
    return _stateErrorMsg();
  }

  // ── Public: Submit Upgrade Request ───────────────────────────────────────
  Future<String?> submitUpgradeRequest({
    required String name,
    required String phone,
    required String planId,
    String? message,
    String? paymentMethod, // نقدي / Vodafone Cash / InstaPay
    XFile? receiptImage, // صورة الإيصال (اختياري)
  }) async {
    if (name.trim().isEmpty) return 'أدخل اسمك';
    if (phone.trim().isEmpty) return 'أدخل رقم هاتفك';
    if (deviceId.value.isEmpty) return 'لم يتم التعرف على الجهاز';

    try {
      // تأكد من وجود anonymous auth
      if (_auth.currentUser == null) {
        try {
          await _auth.signInAnonymously();
        } catch (authErr) {
          return 'خطأ في المصادقة: تأكد من الاتصال بالإنترنت ($authErr)';
        }
      }

      // تحقق من وجود طلب pending بالفعل
      final existing = await _db
          .collection('upgrade_requests')
          .where('deviceId', isEqualTo: deviceId.value)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        return 'لديك طلب قيد المراجعة بالفعل — انتظر الرد';
      }

      // رفع صورة الإيصال إن وُجدت
      String receiptUrl = '';
      if (receiptImage != null) {
        try {
          final ref = FirebaseStorage.instance.ref().child(
              'receipts/${deviceId.value}_${DateTime.now().millisecondsSinceEpoch}.jpg');
          if (kIsWeb) {
            final bytes = await receiptImage.readAsBytes();
            await ref.putData(
                bytes, SettableMetadata(contentType: 'image/jpeg'));
          } else {
            await ref.putFile(File(receiptImage.path));
          }
          receiptUrl = await ref.getDownloadURL();
        } catch (_) {
          // فشل رفع الصورة — نكمل بدونها
        }
      }

      // نجيب اسم الجهاز
      String deviceName = 'Unknown';
      try {
        final plugin = DeviceInfoPlugin();
        if (!kIsWeb && Platform.isWindows) {
          deviceName = (await plugin.windowsInfo).computerName;
        } else if (!kIsWeb && Platform.isAndroid) {
          final i = await plugin.androidInfo;
          deviceName = '${i.brand} ${i.model}';
        }
      } catch (_) {}

      await _db.collection('upgrade_requests').add({
        'ownerUid': _auth.currentUser!.uid,
        'deviceId': deviceId.value,
        'deviceName': deviceName,
        'ownerName': name.trim(),
        'ownerPhone': phone.trim(),
        'requestedPlan': planId,
        'message': message?.trim() ?? '',
        'paymentMethod': paymentMethod ?? '',
        'receiptUrl': receiptUrl,
        'status': 'pending',
        'createdAt': Timestamp.now(),
        'adminNote': '',
        'licenseCode': '',
      });

      hasRequest.value = true;
      // احفظ في SharedPreferences فوراً
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kHasRequest, true);

      return null; // success
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('permission-denied') ||
          msg.contains('PERMISSION_DENIED')) {
        return 'خطأ: صلاحيات قاعدة البيانات — تأكد من تفعيل Anonymous Auth في Firebase';
      }
      if (msg.contains('network') || msg.contains('unavailable')) {
        return 'فشل الإرسال: تحقق من الاتصال بالإنترنت';
      }
      return 'فشل الإرسال: $msg';
    }
  }

  // ── Feature Gates ─────────────────────────────────────────────────────────
  _Limits get _limits => _remoteLimits[plan.value]!;

  /// لو الجهاز ده مساعد (أو مدرس) في فريق مفعّل ومتحقق منه فعليًا من
  /// السيرفر (teamModeBypassLimits)، حالة ترخيصه الشخصي (تجربة منتهية
  /// مثلاً) متبقاش مهمة — ترخيص المدرس صاحب الفريق هو المرجع الحقيقي،
  /// والفحص ده اتعمل خلاص على مستوى السيرفر (Supabase RLS) وقت
  /// الانضمام/الاستعادة، مش مجرد علم محلي اختياري.
  bool get isActive =>
      teamModeBypassLimits ||
      state.value == LicenseState.active ||
      state.value == LicenseState.trial;

  /// بتتحدد من TeamModeService لحظة تفعيل/الانضمام لوضع الفريق —
  /// الترخيص وقتها اتحقق منه خلاص على مستوى المدرس (صاحب الفريق)،
  /// فمساعد لسه في التجربة المجانية على جهازه مايتقفلش عن استخدام
  /// بيانات فريق أكبر من حدود تجربته الشخصية.
  bool teamModeBypassLimits = false;

  /// تحقق من إمكانية إنشاء مجموعة جديدة
  /// يُرجع رسالة الخطأ أو null إذا مسموح
  String? checkCanCreateGroup(int currentCount) {
    if (teamModeBypassLimits) return null;
    if (!isActive) return 'يجب تفعيل الترخيص أولاً';
    final max = _limits.maxGroups;
    if (max == -1) return null;
    if (currentCount >= max) {
      return 'وصلت للحد الأقصى ($max مجموعات) — قم بترقية الخطة';
    }
    return null;
  }

  /// تحقق من إمكانية إضافة طالب جديد في مجموعة
  String? checkCanAddStudent(int currentStudentCount) {
    if (teamModeBypassLimits) return null;
    if (!isActive) return 'يجب تفعيل الترخيص أولاً';
    final max = _limits.maxStudents;
    if (max == -1) return null;
    if (currentStudentCount >= max) {
      return 'وصلت للحد الأقصى ($max طلاب/مجموعة) — قم بترقية الخطة';
    }
    return null;
  }

  // ملحوظة: _limits بيتحدد بباقة الجهاز الشخصية (plan.value)، وده صح
  // للمدرس نفسه، لكن غلط للمساعد — لأن باقته الشخصية (تجربة منتهية
  // غالبًا) مالهاش علاقة بباقة المدرس صاحب الفريق الحقيقية. لو
  // teamModeBypassLimits مفعّلة (يعني اتحقق من السيرفر إن الجهاز ده
  // فعلاً جزء من فريق مرخّص)، بنعتبر كل الميزات متاحة بدل ما نطبّق
  // حدود باقة شخصية مالهاش معنى هنا.
  bool get canBackup => isActive && (teamModeBypassLimits || _limits.canBackup);
  bool get canExport => isActive && (teamModeBypassLimits || _limits.canExport);
  bool get canWhatsApp => isActive && (teamModeBypassLimits || _limits.canWhatsApp);
  bool get canBooking => isActive && (teamModeBypassLimits || _limits.canBooking);

  int get maxGroupsAllowed => _limits.maxGroups;
  int get maxStudentsAllowed => _limits.maxStudents;

  // ── Helpers ───────────────────────────────────────────────────────────────
  AppPlan _parsePlan(String s) {
    switch (s) {
      case 'basic':
        return AppPlan.basic;
      case 'pro':
        return AppPlan.pro;
      case 'lifetime':
        return AppPlan.lifetime;
      default:
        return AppPlan.trial;
    }
  }

  String _stateErrorMsg() {
    switch (state.value) {
      case LicenseState.suspended:
        return 'هذا الترخيص موقوف — تواصل مع الدعم';
      case LicenseState.expired:
        return 'انتهت صلاحية الترخيص — قم بالتجديد';
      case LicenseState.trialExpired:
        return 'انتهت التجربة المجانية';
      default:
        return 'كود غير صالح';
    }
  }

  /// تحديث يدوي لحالة الترخيص (مثلاً بعد رجوع المعلم من شاشة التفعيل)
  Future<void> refresh() async {
    state.value = LicenseState.loading;
    await _init();
  }
}
