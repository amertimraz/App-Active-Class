// lib/controllers/license_controller.dart
import 'dart:async';
import 'dart:io';
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
  loading,       // جاري التحقق
  trial,         // تجربة مجانية نشطة
  trialExpired,  // انتهت التجربة بدون ترخيص
  active,        // ترخيص ساري
  suspended,     // ترخيص موقوف
  expired,       // ترخيص منتهي الصلاحية
}

// ── باقات التطبيق ──────────────────────────────────────────────────────────────
enum AppPlan { trial, basic, pro, lifetime }

extension AppPlanExt on AppPlan {
  String get nameAr {
    switch (this) {
      case AppPlan.trial:    return 'تجريبي';
      case AppPlan.basic:    return 'أساسي';
      case AppPlan.pro:      return 'احترافي';
      case AppPlan.lifetime: return 'مدى الحياة';
    }
  }

  int    get maxGroups          => <AppPlan,int>{AppPlan.trial: 2, AppPlan.basic: 5, AppPlan.pro: -1, AppPlan.lifetime: -1}[this]!;
  int    get maxStudents        => <AppPlan,int>{AppPlan.trial: 15, AppPlan.basic: 30, AppPlan.pro: -1, AppPlan.lifetime: -1}[this]!;
  bool   get canBackup          => this != AppPlan.trial;
  bool   get canExport          => this != AppPlan.trial;
  bool   get canWhatsApp        => this == AppPlan.pro || this == AppPlan.lifetime;
}

// ── الحدود حسب الباقة ─────────────────────────────────────────────────────────
class _Limits {
  final int maxGroups;        // -1 = غير محدود
  final int maxStudents;
  final bool canBackup;
  final bool canExport;
  final bool canWhatsApp;

  const _Limits({
    required this.maxGroups,
    required this.maxStudents,
    required this.canBackup,
    required this.canExport,
    required this.canWhatsApp,
  });

  static const trial    = _Limits(maxGroups: 2,  maxStudents: 15, canBackup: false, canExport: false, canWhatsApp: false);
  static const basic    = _Limits(maxGroups: 5,  maxStudents: 30, canBackup: true,  canExport: true,  canWhatsApp: false);
  static const pro      = _Limits(maxGroups: -1, maxStudents: -1, canBackup: true,  canExport: true,  canWhatsApp: true);
  static const lifetime = _Limits(maxGroups: -1, maxStudents: -1, canBackup: true,  canExport: true,  canWhatsApp: true);
}

// ── المتحكم الرئيسي ───────────────────────────────────────────────────────────
class LicenseController extends GetxController {
  static LicenseController get to => Get.find();

  // Observable state
  final state         = LicenseState.loading.obs;
  final plan          = AppPlan.trial.obs;
  final trialDaysLeft = 7.obs;
  final deviceId      = ''.obs;
  final licenseCode   = RxnString();
  final hasRequest    = false.obs; // هل عنده طلب ترقية pending
  final expiresAt     = Rxn<DateTime>(); // تاريخ انتهاء الترخيص

  // Firebase
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Real-time listener على الترخيص النشط
  StreamSubscription? _licenseSubscription;

  // SharedPreferences keys
  static const _kDeviceId     = 'lic_device_id';
  static const _kCode         = 'lic_code';
  static const _kFirstLaunch  = 'lic_first_launch';
  static const _kPlan         = 'lic_plan';
  static const _kHasRequest   = 'lic_has_request';
  static const _kTrialDays    = 7;
  // ignore: unused_field
  static const int _kGraceDays = 3; // grace period (offline use) — future use

  // ── init ──────────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _init();
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
    } catch (e) {
      _loadCachedState();
    }
  }

  // ── Device ID ─────────────────────────────────────────────────────────────
  Future<void> _initDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kDeviceId);
    if (id == null || id.isEmpty) {
      try {
        final plugin = DeviceInfoPlugin();
        if (!kIsWeb && Platform.isWindows) {
          final info = await plugin.windowsInfo;
          id = info.deviceId;
        } else if (!kIsWeb && Platform.isAndroid) {
          final info = await plugin.androidInfo;
          id = info.id;
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
        final doc = await _db.collection('devices').doc(deviceId.value).get()
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
    final elapsed   = DateTime.now().difference(firstLaunch).inDays;
    final daysLeft  = _kTrialDays - elapsed;

    if (daysLeft > 0) {
      trialDaysLeft.value = daysLeft;
      plan.value  = AppPlan.trial;
      state.value = LicenseState.trial;
    } else {
      trialDaysLeft.value = 0;
      state.value = LicenseState.trialExpired;
    }
  }

  // ── License Validation ────────────────────────────────────────────────────
  Future<void> _validateLicense(String code, SharedPreferences prefs) async {
    try {
      final doc = await _db.collection('licenses').doc(code).get()
          .timeout(const Duration(seconds: 6));

      if (!doc.exists) {
        // كود غير موجود — نرجع للتجربة
        await prefs.remove(_kCode);
        await _checkTrial(prefs);
        return;
      }

      final data      = doc.data()!;
      final status    = data['status']   as String? ?? 'active';
      final planStr   = data['plan']     as String? ?? 'basic';
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      final boundDev  = data['deviceId'] as String?;

      // الجهاز مربوط بجهاز آخر
      if (boundDev != null && boundDev != deviceId.value) {
        await prefs.remove(_kCode);
        state.value = LicenseState.trialExpired;
        return;
      }

      // ربط الجهاز إذا لم يكن مرتبطاً
      if (boundDev == null) {
        try {
          await _db.collection('licenses').doc(code).update({
            'deviceId':    deviceId.value,
            'activatedAt': Timestamp.now(),
          });
        } catch (_) {}
      }

      // تحقق من الحالة
      if (status == 'suspended') {
        licenseCode.value = code;
        state.value = LicenseState.suspended;
        return;
      }

      if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
        plan.value            = _parsePlan(planStr);
        licenseCode.value     = code;
        this.expiresAt.value  = expiresAt;
        state.value           = LicenseState.expired;
        return;
      }

      // ✅ ترخيص سليم
      plan.value            = _parsePlan(planStr);
      licenseCode.value     = code;
      this.expiresAt.value  = expiresAt; // null = مدى الحياة
      state.value           = LicenseState.active;
      await prefs.setString(_kPlan, planStr);

      // ابدأ الاستماع للتغييرات في real-time
      _watchLicense(code, prefs);

    } catch (_) {
      // Offline — نستخدم الـ grace period
      final cachedPlan = prefs.getString(_kPlan) ?? 'basic';
      plan.value        = _parsePlan(cachedPlan);
      licenseCode.value = code;
      state.value       = LicenseState.active;
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
            licenseCode.value = null;
            expiresAt.value   = null;
            await _checkTrial(prefs);
            return;
          }

          final data   = doc.data()!;
          final status = data['status'] as String? ?? 'active';
          final planStr = data['plan']   as String? ?? 'basic';
          final exp     = (data['expiresAt'] as Timestamp?)?.toDate();

          if (status == 'suspended') {
            state.value = LicenseState.suspended;
          } else if (exp != null && exp.isBefore(DateTime.now())) {
            expiresAt.value = exp;
            state.value     = LicenseState.expired;
          } else {
            plan.value           = _parsePlan(planStr);
            expiresAt.value      = exp;
            state.value          = LicenseState.active;
            await prefs.setString(_kPlan, planStr);
          }
        }, onError: (_) {});
  }

  @override
  void onClose() {
    _licenseSubscription?.cancel();
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

      await _db.collection('devices').doc(deviceId.value).set({
        'deviceId':       deviceId.value,
        'deviceName':     deviceName,
        'platform':       kIsWeb ? 'web' : Platform.operatingSystem,
        'firstLaunchAt':  FieldValue.serverTimestamp(),
        'lastSeenAt':     FieldValue.serverTimestamp(),
        'licenseCode':    licenseCode.value,
        'licenseState':   state.value.name,
      }, SetOptions(merge: true));
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
          final doc    = snap.docs.first;
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
        }, onError: (_) {});
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
    return _stateErrorMsg();
  }

  // ── Public: Submit Upgrade Request ───────────────────────────────────────
  Future<String?> submitUpgradeRequest({
    required String name,
    required String phone,
    required String planId,
    String?  message,
    String?  paymentMethod, // نقدي / Vodafone Cash / InstaPay
    XFile?   receiptImage,  // صورة الإيصال (اختياري)
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
          final ref = FirebaseStorage.instance
              .ref()
              .child('receipts/${deviceId.value}_${DateTime.now().millisecondsSinceEpoch}.jpg');
          if (kIsWeb) {
            final bytes = await receiptImage.readAsBytes();
            await ref.putData(bytes,
                SettableMetadata(contentType: 'image/jpeg'));
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
        'deviceId':      deviceId.value,
        'deviceName':    deviceName,
        'ownerName':     name.trim(),
        'ownerPhone':    phone.trim(),
        'requestedPlan': planId,
        'message':       message?.trim() ?? '',
        'paymentMethod': paymentMethod ?? '',
        'receiptUrl':    receiptUrl,
        'status':        'pending',
        'createdAt':     Timestamp.now(),
        'adminNote':     '',
        'licenseCode':   '',
      });

      hasRequest.value = true;
      // احفظ في SharedPreferences فوراً
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kHasRequest, true);

      return null; // success
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('permission-denied') || msg.contains('PERMISSION_DENIED')) {
        return 'خطأ: صلاحيات قاعدة البيانات — تأكد من تفعيل Anonymous Auth في Firebase';
      }
      if (msg.contains('network') || msg.contains('unavailable')) {
        return 'فشل الإرسال: تحقق من الاتصال بالإنترنت';
      }
      return 'فشل الإرسال: $msg';
    }
  }

  // ── Feature Gates ─────────────────────────────────────────────────────────
  _Limits get _limits {
    switch (plan.value) {
      case AppPlan.trial:    return _Limits.trial;
      case AppPlan.basic:    return _Limits.basic;
      case AppPlan.pro:      return _Limits.pro;
      case AppPlan.lifetime: return _Limits.lifetime;
    }
  }

  bool get isActive =>
      state.value == LicenseState.active || state.value == LicenseState.trial;

  /// تحقق من إمكانية إنشاء مجموعة جديدة
  /// يُرجع رسالة الخطأ أو null إذا مسموح
  String? checkCanCreateGroup(int currentCount) {
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
    if (!isActive) return 'يجب تفعيل الترخيص أولاً';
    final max = _limits.maxStudents;
    if (max == -1) return null;
    if (currentStudentCount >= max) {
      return 'وصلت للحد الأقصى ($max طلاب/مجموعة) — قم بترقية الخطة';
    }
    return null;
  }

  bool get canBackup    => isActive && _limits.canBackup;
  bool get canExport    => isActive && _limits.canExport;
  bool get canWhatsApp  => isActive && _limits.canWhatsApp;

  int get maxGroupsAllowed   => _limits.maxGroups;
  int get maxStudentsAllowed => _limits.maxStudents;

  // ── Helpers ───────────────────────────────────────────────────────────────
  AppPlan _parsePlan(String s) {
    switch (s) {
      case 'basic':    return AppPlan.basic;
      case 'pro':      return AppPlan.pro;
      case 'lifetime': return AppPlan.lifetime;
      default:         return AppPlan.trial;
    }
  }

  String _stateErrorMsg() {
    switch (state.value) {
      case LicenseState.suspended:     return 'هذا الترخيص موقوف — تواصل مع الدعم';
      case LicenseState.expired:       return 'انتهت صلاحية الترخيص — قم بالتجديد';
      case LicenseState.trialExpired:  return 'انتهت التجربة المجانية';
      default:                         return 'كود غير صالح';
    }
  }

  /// تحديث يدوي لحالة الترخيص (مثلاً بعد رجوع المعلم من شاشة التفعيل)
  Future<void> refresh() async {
    state.value = LicenseState.loading;
    await _init();
  }
}
