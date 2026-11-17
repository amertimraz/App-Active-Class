// lib/services/parent_portal_service.dart
//
// "بوابة متابعة أولياء الأمور" — إضافة مدفوعة منفصلة (parentPortalEnabled
// على مستند الترخيص، تتحكم فيها لوحة الأدمن). لو مفعّلة، بنبعت ملخص خفيف
// بس لكل طالب (نسبة حضور، مدفوعات) لـ Firestore — عشان صفحة عامة بسيطة
// على الموقع تقدر تعرضها لولي الأمر بعد ما يدخل كود الطالب + آخر 4 أرقام
// من رقم تليفونه (حماية من تخمين الأكواد المتسلسلة).
//
// الحماية الفعلية هنا مش قواعد Firestore معقّدة — هي إن الـ document ID
// نفسه مركّب من {code}_{last4} (زي رابط سرّي غير قابل للتخمين لمين
// معندوش الرقمين مع بعض)، فالقاعدة الأمنية بسيطة: قراءة عامة مسموحة،
// بس لازم تعرف الـ ID الصح الأول عشان توصله.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show WidgetsBinding, WidgetsBindingObserver, AppLifecycleState;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/utils/parent_portal_helper.dart';
import 'package:active_class/utils/firestore_usage.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/services/booking_service.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/notification_service.dart';
import 'package:active_class/models/booklet_model.dart';
import 'package:active_class/utils/booklet_portal.dart';
import 'package:active_class/utils/pricing_helper.dart';
import 'package:active_class/utils/session_guest.dart';
import 'package:active_class/utils/recitation.dart';
import 'package:active_class/utils/performance.dart';
import 'package:active_class/services/performance_service.dart';

class ParentPortalService {
  static final ParentPortalService _instance = ParentPortalService._internal();
  factory ParentPortalService() => _instance;
  ParentPortalService._internal();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final DatabaseService _dbService = DatabaseService();
  Worker? _profileWorker;
  Worker? _licenseWorker;

  static const String _kSlugKey = 'parent_portal_slug';

  /// الدخول بالكود فقط (بدون آخر 4 أرقام)؟ إعداد محلي من الإعدادات.
  bool get _codeOnly =>
      Get.isRegistered<SettingsController>() &&
      Get.find<SettingsController>().portalCodeOnly.value;

  /// بتتابع اسم/جنس المدرس وتعيد النشر أول ما يتغيّروا — من غيرها،
  /// البروفايل كان بينشر مرة واحدة بس أول ما شاشة الإعدادات تتفتح،
  /// فلو المدرس غيّر اسمه بعد كده، صفحة المتابعة تفضل باسمه القديم
  /// لحد ما يقفل الإعدادات ويفتحها تاني بالصدفة.
  Timer? _profileDebounce;

  void _watchProfileChanges() {
    if (_profileWorker != null) return;
    if (!Get.isRegistered<SettingsController>()) return;
    final settings = Get.find<SettingsController>();
    // التخصص بيتكتب حرف حرف في الإعدادات — نجمّع التغييرات (ثانية) بدل
    // كتابة على Firestore مع كل حرف.
    _profileWorker = everAll(
      [
        settings.teacherFullName,
        settings.teacherGender,
        settings.teacherSpecialization,
        settings.teacherAvatarPath,
      ],
      (_) {
        _profileDebounce?.cancel();
        _profileDebounce =
            Timer(const Duration(seconds: 1), () => publishProfile());
      },
    );
  }

  /// بتتابع تفعيل/تعديل مدة بوابة أولياء الأمور وتعيد نشر البروفايل
  /// (بتاريخ الانتهاء الجديد) فورًا عند أي تغيير — مهم بالذات لسيناريو
  /// "تجديد بعد انتهاء": من غيرها، صفحة /track العامة كانت هتفضل تعرض
  /// تاريخ الانتهاء القديم (المنتهي) لحد ما يحصل أي نشر عرضي تاني.
  /// مسجَّلة من غير أي شرط على الحالة الحالية (فعّالة/منتهية) عشان
  /// تلتقط التفعيل الأول والتجديد بعد الانتهاء على السواء.
  /// آخر حالة "شغّالة" شفناها — عشان نلقط انتقال false→true (تفعيل أو
  /// رجوع البوابة بعد تحديث التطبيق) فنعمل نشر جماعي لمّة لأي بيانات
  /// اتسجّلت والبوابة كانت "متلغية" (وقتها pushStudentSummary كان بيسكت).
  bool? _lastPortalActive;

  void _watchLicenseChanges() {
    if (_licenseWorker != null) return;
    if (!Get.isRegistered<LicenseController>()) return;
    final lic = LicenseController.to;
    _lastPortalActive ??= lic.parentPortalActiveNow;
    _licenseWorker = everAll(
      // licenseVerifiedTick كمان — عشان الـcallback يفير حتى لو الأدمن
      // قفل البوابة والتطبيق كان مقفول (ساعتها parentPortalEnabled بيفضل
      // false→false ومفيش تغيير)، فأول تحقق ترخيص بعد الفتح بيوفّق الحالة.
      [
        lic.parentPortalEnabled,
        lic.parentPortalExpiresAt,
        lic.licenseVerifiedTick
      ],
      (_) {
        // تنبيه قرب انتهاء الاشتراك — يتحدّث مع أي تغيّر (تجديد/إلغاء/أول تحقق).
        unawaited(NotificationService().schedulePortalExpiryReminders());
        final active = lic.parentPortalActiveNow;
        if (active) {
          publishProfile();
          // انتقال من "متلغية" لـ"شغّالة" → لمّة شاملة مرة واحدة لأي
          // حضور/دفعات اتسجّلت والبوابة كانت واقفة.
          if (_lastPortalActive == false) {
            unawaited(publishAllStudents().catchError((_) => 0));
          }
        } else {
          // لو البوابة اتعطّلت (شِيلت العلامة أو عدّى تاريخ الانتهاء)،
          // اكتب active:false على المستند العام عشان صفحة الأهالي تعرض
          // "غير متاحة" بدل ما تفضل عارضة بيانات متجمّدة للأبد.
          publishPortalClosed();
        }
        _lastPortalActive = active;
      },
    );
  }

  /// لازم تتنادى مرة واحدة عند إقلاع التطبيق (main.dart، بعد تسجيل
  /// LicenseController وSettingsController) — بتؤمّن إن أي تغيير لاحق
  /// في تفعيل/مدة بوابة أولياء الأمور (سواء من التطبيق نفسه، أو تعديل
  /// مباشر من الأدمن على مستند الترخيص في Firestore ووصل للتطبيق عبر
  /// الاستماع الفوري الموجود بالفعل) بينعكس فورًا على الصفحة العامة.
  ///
  /// من غير النداء ده، الـwatchers (`_watchLicenseChanges`/
  /// `_watchProfileChanges`) كانت بتتسجّل بس أول مرة publishProfile
  /// (أو pushStudentSummary/publishAllStudents) يتنادوا فعليًا — يعني
  /// لو المدرس فتح التطبيق وماعملش أي إجراء بيلمس بوابة أولياء الأمور
  /// (إضافة طالب، تسجيل حضور/دفعة، فتح شاشة الإعدادات)، والأدمن قصّر
  /// أو ألغى مدة البوابة في نفس الوقت، الصفحة العامة كانت بتفضل عارضة
  /// بيانات الطلاب زي ما هي — من غير أي قفل — لحد ما حاجة تانية
  /// تحصل بالصدفة تشغّل publishProfile لأول مرة. ده كان بيسيب البوابة
  /// "متفتحة" فترة غير محددة بعد ما المفروض تتقفل، رغم إن منطق القفل
  /// نفسه (في الصفحة العامة وفي parentPortalActiveNow) سليم.
  void init() {
    _watchLicenseChanges();
    _watchProfileChanges();
  }

  Future<void> _ensureAuth() async {
    if (_auth.currentUser == null) {
      try {
        await _auth.signInAnonymously();
      } catch (e) {
        debugPrint('ParentPortalService: signInAnonymously failed — $e');
      }
    }
  }

  static const _slugChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

  String _generateSlug() {
    final rnd = Random.secure();
    return List.generate(10, (_) => _slugChars[rnd.nextInt(36)]).join();
  }

  /// رابط مشتقّ حتميًا من كود الترخيص — نفس الكود يدّي نفس الرابط دايمًا،
  /// فإعادة تثبيت التطبيق (والمدرس بيعيد إدخال نفس الكود) مابتغيّرش رابط
  /// الأهالي. مش تشفير — السرّية في كود الترخيص نفسه؛ الغرض بس إنه ثابت
  /// وغير متسلسل/متوقّع. FNV-1a 64-بت موسّع لـ12 حرف base36.
  String _deterministicSlug(String seed) {
    final mask = (BigInt.one << 64) - BigInt.one;
    final prime = BigInt.from(1099511628211);
    var h = BigInt.parse('14695981039346656037'); // FNV-1a offset
    for (final b in utf8.encode(seed.trim())) {
      h = ((h ^ BigInt.from(b)) * prime) & mask;
    }
    h = ((h ^ (h >> 29)) * prime) & mask;
    h = (h ^ (h >> 17)) & mask;
    final base = BigInt.from(36);
    final buf = StringBuffer();
    for (var i = 0; i < 12; i++) {
      buf.write(_slugChars[(h % base).toInt()]);
      h = h ~/ base;
    }
    return buf.toString();
  }

  bool _migratingSlug = false;

  /// رابط المتابعة الثابت للمدرس. لو فيه كود ترخيص → مشتقّ منه حتميًا
  /// (ثابت عبر إعادة التثبيت). غير كده (تجربة/بدون ترخيص) → عشوائي محفوظ
  /// محليًا. لو الرابط اتغيّر من رابط قديم مخزّن، بنرفع كل الطلاب للرابط
  /// الجديد مرة واحدة عشان مايبقاش فاضي.
  ///
  /// spec 016 — ده كمان مصدر الـslug المشترك للامتحانات الإلكترونية
  /// (OnlineExamService بيستدعيها) عشان يفضل مصدر واحد لاشتقاق الرابط.
  Future<String> ensureSlug() async {
    final code = LicenseController.to.licenseCode.value?.trim();

    if (code == null || code.isEmpty) {
      var slug = await _dbService.getSetting(_kSlugKey);
      if (slug == null || slug.isEmpty) {
        slug = _generateSlug();
        await _dbService.setSetting(_kSlugKey, slug);
      }
      return slug;
    }

    final det = _deterministicSlug(code);
    final stored = await _dbService.getSetting(_kSlugKey);
    if (stored != det) {
      final hadOldLink = stored != null && stored.isNotEmpty;
      await _dbService.setSetting(_kSlugKey, det);
      if (hadOldLink &&
          !_migratingSlug &&
          LicenseController.to.parentPortalActiveNow) {
        _migratingSlug = true;
        unawaited(publishAllStudents()
            .catchError((_) => 0)
            .whenComplete(() => _migratingSlug = false));
      }
    }
    return det;
  }

  Future<String?> getSlugIfExists() => _dbService.getSetting(_kSlugKey);

  /// بتُكتب لما البوابة تتعطّل — بتحطّ `active: false` على المستند العام
  /// عشان صفحة `/track/{slug}` تعرض "غير متاحة" فورًا بدل بيانات متجمّدة.
  /// best-effort — لو مفيش رابط متولّد أصلاً أو فشلت الكتابة، بنتجاهل.
  Future<void> publishPortalClosed() async {
    try {
      // نفس الرابط اللي ensureSlug بترجّعه (المشتقّ من كود الترخيص) —
      // من غير آثار جانبية (مافيش migration ولا publishAllStudents).
      final code = LicenseController.to.licenseCode.value?.trim();
      final slug = (code != null && code.isNotEmpty)
          ? _deterministicSlug(code)
          : await getSlugIfExists();
      if (slug == null || slug.isEmpty) return;
      await _ensureAuth();
      await _db.collection('parent_portal').doc(slug).set({
        'active': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('ParentPortalService: publishPortalClosed failed — $e');
    }
  }

  /// معرّف مستند الطالب في parent_portal/{slug}/students (وفي visits كمان)، حسب
  /// طريقة الدخول الحالية. null لو الطالب مش ظاهر (بلا كود، أو بلا رقم في وضع
  /// كود + رقم).
  String? portalDocIdFor(Student student) {
    final code = student.code.trim().toUpperCase();
    if (code.isEmpty) return null;
    if (_codeOnly) return portalSafeId(code);
    final last4 = _last4(student.guardianPhone);
    return last4 == null ? null : '${portalSafeId(code)}_$last4';
  }

  /// زيارات أولياء الأمور لصفحة المتابعة: معرّف المستند → عدّاد وآخر وقت.
  /// فاضية لو مفيش رابط/نت أو الزيارات لسه ما اتسجّلتش. القراءة مسموحة لصاحب
  /// الرابط بس (قواعد Firestore).
  Future<Map<String, PortalVisit>> loadVisits() async {
    try {
      final slug = await getSlugIfExists();
      if (slug == null) return const {};
      await _ensureAuth();
      final snap = await _db
          .collection('parent_portal')
          .doc(slug)
          .collection('visits')
          .get();
      DateTime? ts(Object? v) => v is Timestamp ? v.toDate() : null;
      return {
        for (final d in snap.docs)
          d.id: PortalVisit(
            count: (d.data()['count'] as num?)?.toInt() ?? 0,
            firstAt: ts(d.data()['firstAt']),
            lastAt: ts(d.data()['lastAt']),
          ),
      };
    } catch (e) {
      debugPrint('ParentPortalService: loadVisits failed — $e');
      return const {};
    }
  }

  /// آخر 4 أرقام من رقم ولي الأمر — عمود الحماية الوحيد، فلو رقم
  /// التليفون فاضي أو أقل من 4 أرقام، الطالب ده مينفعش يتنشر خالص
  /// (بدل ما نضعّف الحماية).
  String? _last4(String? phone) => portalLast4(phone);

  /// نفس معرّف المستند {code}_{last4} المستخدَم في كل مكان (بوابة
  /// الأهالي، الامتحان الإلكتروني) — بمعنى `attemptKey()` في صفحة
  /// الامتحان بالضبط. null لو الطالب مالوش رقم ولي أمر صالح.
  String? attemptKeyFor(Student student) {
    final last4 = _last4(student.guardianPhone);
    if (last4 == null) return null;
    final code = student.code.trim().toUpperCase();
    if (code.isEmpty) return null;
    return '${portalSafeId(code)}_$last4';
  }

  /// بتُنشر لوحدها (مش مربوطة بنجاح نشر طالب) — لو مفيش أي طالب عنده
  /// رقم تليفون صحيح لسه، كان المستند ده مبيتعملش خالص، فصفحة المتابعة
  /// تفضل من غير اسم المدرس وكأنها رابط عام مش رابط المدرس ده تحديدًا.
  DateTime? _lastProfilePublishAttempt;
  bool _profilePublishInFlight = false;
  int _profilePublishFailStreak = 0;

  Future<void> publishProfile() async {
    _watchLicenseChanges();
    if (!LicenseController.to.parentPortalActiveNow) return;
    _watchProfileChanges();

    // منع الحلقة: لو فيه نداء شغّال، أو آخر نداء كان من ثوانٍ قليلة —
    // بلاش نكرر. بعد فشل متتالي (صلاحيات/شبكة) بنطوّل فترة الانتظار
    // تصاعديًا لحد دقيقة بدل ما نفضل نطق كل نص ثانية.
    if (_profilePublishInFlight) return;
    final now = DateTime.now();
    final backoff = Duration(
        seconds: _profilePublishFailStreak == 0
            ? 3
            : (5 * _profilePublishFailStreak).clamp(5, 60));
    if (_lastProfilePublishAttempt != null &&
        now.difference(_lastProfilePublishAttempt!) < backoff) {
      return;
    }
    _lastProfilePublishAttempt = now;
    _profilePublishInFlight = true;
    try {
      await _ensureAuth();
      final slug = await ensureSlug();
      await _publishProfile(slug);
      _profilePublishFailStreak = 0;
    } catch (e) {
      _profilePublishFailStreak++;
      // best-effort — بنسجّل بس عشان فشل صامت زي ده (mismatch في هوية
      // الجهاز/الحساب بعد إعادة تثبيت أو مسح بيانات، مثلاً) يبقى قابل
      // للتشخيص من لوج الجهاز بدل ما يفضل مخفي تمامًا (راجع
      // specs/003-parent-portal-expiry — الحادثة اللي اكتشفناها فيها).
      debugPrint('ParentPortalService: publishProfile failed '
          '(streak $_profilePublishFailStreak) — $e');
    } finally {
      _profilePublishInFlight = false;
    }
  }

  // صورة المعلم في صفحة المتابعة: بتترفع على نفس خدمة الرفع بتاعة الحجز
  // (VPS) تحت slug البوابة، ورابطها بيتنشر مع البروفايل. الرفع بيحصل بس لما
  // الصورة تتغيّر (توقيع حجم+وقت تعديل) — مش مع كل نشر.
  static const _kPhotoSigKey = 'portal_teacher_photo_sig';
  static const _kPhotoUrlKey = 'portal_teacher_photo_url';
  static const _kPhotoMaxBytes = 5 * 1024 * 1024; // حد الخادم

  Future<String?> _teacherPhotoUrl(String slug, String avatarPath) async {
    try {
      final cachedUrl = await _dbService.getSetting(_kPhotoUrlKey);
      final path = avatarPath.trim();
      if (path.isEmpty) {
        // اتشالت الصورة → امسح المرفوعة (best-effort) وصفّر الكاش.
        if (cachedUrl != null && cachedUrl.isNotEmpty) {
          await BookingService().deleteUploadedImage(slug);
          await _dbService.setSetting(_kPhotoUrlKey, '');
          await _dbService.setSetting(_kPhotoSigKey, '');
        }
        return null;
      }
      final file = File(path);
      if (!await file.exists()) {
        return (cachedUrl == null || cachedUrl.isEmpty) ? null : cachedUrl;
      }
      final stat = await file.stat();
      final sig = '$slug:${stat.size}:${stat.modified.millisecondsSinceEpoch}';
      if (await _dbService.getSetting(_kPhotoSigKey) == sig &&
          cachedUrl != null &&
          cachedUrl.isNotEmpty) {
        return cachedUrl; // نفس الصورة — مفيش رفع جديد
      }
      if (stat.size > _kPhotoMaxBytes) return null;
      final url = await BookingService().uploadPhoto(slug, file);
      if (url != null && url.isNotEmpty) {
        await _dbService.setSetting(_kPhotoUrlKey, url);
        await _dbService.setSetting(_kPhotoSigKey, sig);
        return url;
      }
      // فشل الرفع (نت): نستخدم آخر رابط ناجح لو موجود، والمحاولة الجاية
      // هتعيد الرفع (التوقيع ما اتحفظش).
      return (cachedUrl == null || cachedUrl.isEmpty) ? null : cachedUrl;
    } catch (e) {
      debugPrint('ParentPortalService: تعذّر رفع صورة المعلم — $e');
      return null;
    }
  }

  Future<void> _publishProfile(String slug) async {
    final settings = Get.isRegistered<SettingsController>()
        ? Get.find<SettingsController>()
        : null;
    // بننشر تاريخ انتهاء بوابة أولياء الأمور (لو موجود) جوه نفس المستند
    // العام ده — عشان صفحة /track/{slug} (كود JS خام، بدون وصول لمجموعة
    // licenses المحمية) تقدر تتحقق بنفسها إن المدة لسه سارية قبل ما
    // تعرض أي بيانات طالب. null صراحةً لو مفيش تاريخ (مدى الحياة)،
    // عشان تجديد لاحق يمسح تاريخ قديم كان منشور.
    final expiresAt = LicenseController.to.parentPortalExpiresAt.value;
    final photoUrl =
        await _teacherPhotoUrl(slug, settings?.teacherAvatarPath.value ?? '');
    final profile = <String, dynamic>{
      'teacherName': settings?.teacherFullName.value ?? '',
      'teacherGender': settings?.teacherGender.value ?? 'male',
      // التخصص بيظهر تحت اسم المعلم في أعلى صفحة المتابعة.
      'teacherSpecialization':
          (settings?.teacherSpecialization.value ?? '').trim(),
      // صورة المعلم (رابط على الـVPS) — null لو مفيش صورة.
      'teacherPhotoUrl': photoUrl,
      // طريقة دخول ولي الأمر — صفحة المتابعة بتقراها عشان تعرض/تخفي خانة
      // آخر 4 أرقام وتحدد معرّف المستند (كود فقط / كود_آخر4).
      'loginMode': _codeOnly ? 'code_only' : 'code_phone',
      'ownerUid': _auth.currentUser?.uid,
      'deviceId': LicenseController.to.deviceId.value,
      // .toUtc() ضروري هنا — من غيرها الـstring بيطلع بتوقيت محلي بلا
      // علامة timezone، والمتصفح بتاع ولي الأمر (على جهاز تاني، ممكن
      // منطقة زمنية مختلفة) كان هيفسّرها بتوقيته المحلي هو مش توقيت
      // تليفون المدرس — ممكن يفرق ساعات في لحظة القفل الفعلية.
      // .toUtc() بتضمن علامة 'Z' فيرجع new Date() في الجافاسكريبت
      // يفهمها كلحظة مطلقة، بغض النظر عن توقيت أي جهاز.
      'parentPortalExpiresAt': expiresAt?.toUtc().toIso8601String(),
      // البوابة شغّالة — بيتقرا في صفحة /track عشان القفل اليدوي (شيل
      // العلامة من غير تاريخ) يوصل للأهالي كمان مش بس القفل بالتاريخ.
      'active': true,
    };
    // بصمة البروفايل: لو ما اتغيّرش من آخر كتابة ناجحة (في الذاكرة أو المحفوظة)
    // نتخطّى الكتابة — كانت بتتكتب مع كل فتح لشاشة البوابة ومع كل نشر.
    final h = portalDocHash(profile);
    if (_profileHashSlug != slug) {
      _profileHashSlug = slug;
      _profileHash = await _dbService.getSetting('portal_profile_hash_$slug');
    }
    if (_profileHash == h) return;
    await _db.collection('parent_portal').doc(slug).set(
        {...profile, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
    _profileHash = h;
    FirestoreUsage.write('portal.profile');
    try {
      await _dbService.setSetting('portal_profile_hash_$slug', h);
    } catch (_) {}
  }

  /// بيبني بيانات ملخص طالب (من غير أي كتابة) — مستخدمة في النشر الفردي
  /// والجماعي مع بعض، عشان منكررش نفس منطق الحساب في مكانين.
  ///
  /// بيبعت آخر 20 سجل حضور وآخر 15 دفعة بس (مش التاريخ كله) — عشان
  /// المستند يفضل خفيف حتى لطالب قديم عنده سنين من السجلات، ولأن
  /// ولي الأمر أصلاً مهتم بالأحدث مش بأرشيف كامل.
  /// spec 050 — حقل `performance` في ملخص الطالب. الشهر الحالي لو فيه
  /// بيانات وإلا السابق. فاضي لو مفيش بيانات أو كل المؤشرات مخفية.
  Map<String, dynamic> _performanceForPortal(
    Student student,
    String groupName,
    List<Attendance> attendance,
    List<Homework> homework,
    List<StudentExamRecord> exams,
  ) {
    try {
      final enabled = PerformanceService.enabledKinds();
      final now = DateTime.now();
      var perf = buildPerformance(
        student: student,
        groupName: groupName,
        month: now,
        attendance: attendance,
        homework: homework,
        exams: exams,
        enabled: enabled,
      );
      if (!perf.hasData) {
        perf = buildPerformance(
          student: student,
          groupName: groupName,
          month: DateTime(now.year, now.month - 1, 1),
          attendance: attendance,
          homework: homework,
          exams: exams,
          enabled: enabled,
        );
      }
      final f = performancePortalFields(perf);
      return f == null ? const {} : {'performance': f};
    } catch (e) {
      debugPrint('portal performance failed: $e');
      return const {};
    }
  }

  /// جداول المذكرات كلها مرة واحدة (فاضية لو الجداول مش جاهزة — البوابة
  /// تفضل شغالة من غيرها).
  Future<
      ({
        List<Booklet> booklets,
        List<BookletGroupLink> links,
        List<BookletRecord> records,
        List<BookletPayment> payments,
      })> _loadBookletData() async {
    try {
      return (
        booklets: await _dbService.getAllBooklets(),
        links: await _dbService.getAllBookletGroups(),
        records: await _dbService.getAllBookletRecords(),
        payments: await _dbService.getAllBookletPayments(),
      );
    } catch (e) {
      debugPrint('portal booklets failed: $e');
      return (
        booklets: const <Booklet>[],
        links: const <BookletGroupLink>[],
        records: const <BookletRecord>[],
        payments: const <BookletPayment>[],
      );
    }
  }

  Map<String, dynamic>? _buildSummaryData(
    Student student, {
    required List<Attendance> attendance,
    required List<Payment> payments,
    required List<Homework> homework,
    required String groupName,
    List<StudentExamRecord> exams = const [],
    Group? group,
    List<Student> allStudents = const [],
    List<BookletPortalLine> bookletLines = const [],
  }) {
    final last4 = _last4(student.guardianPhone);
    // بالكود فقط: الطالب بلا رقم ولي أمر برضو بيتنشر (مفيش آخر 4 مطلوبة).
    if (last4 == null && !_codeOnly) return null;
    final code = student.code.toUpperCase();
    if (code.isEmpty) return null;

    // المديونية المتراكمة المحسوبة زي التطبيق بالظبط (بتاخد نظام التحصيل
    // والحساب النسبي من إعدادات PricingHelper) — عشان "المتبقّي" في
    // البوابة يطابق اللي المدرس شايفه (spec 012).
    final accumulatedDebt = PricingHelper.accumulatedDebt(
      student: student,
      group: group,
      allAttendance: attendance,
      payments: payments,
      siblingGroupMembers: allStudents.isEmpty ? null : allStudents,
    );

    // "متأخر" يُحتسب حضورًا في العدّاد، ويُعرض كفئة ثالثة (spec 011)
    final present =
        attendance.where((a) => attendanceCountsAsPresent(a.status)).length;
    final late = attendance
        .where((a) => normalizeAttendanceStatus(a.status) == ATTENDANCE_LATE)
        .length;
    final absent = attendance
        .where((a) => normalizeAttendanceStatus(a.status) == ATTENDANCE_ABSENT)
        .length;
    // إسقاط المديونية مش دفعة نقدية — مايظهرش لولي الأمر ولا يدخل في "المدفوع"
    // (لكنه محسوب في accumulatedDebt فوق).
    final shownPayments = portalVisiblePayments(payments);
    final totalPaid = shownPayments.fold<double>(0, (s, p) => s + p.amount);
    final homeworkDone = homework
        .where((h) => normalizeHomeworkStatus(h.status) == HOMEWORK_DONE)
        .length;
    final homeworkPartial = homework
        .where((h) => normalizeHomeworkStatus(h.status) == HOMEWORK_PARTIAL)
        .length;
    final homeworkNotDone = homework
        .where((h) => normalizeHomeworkStatus(h.status) == HOMEWORK_NOT_DONE)
        .length;

    final sortedAttendance = [...attendance]
      ..sort((a, b) => b.date.compareTo(a.date));
    final sortedPayments = [...shownPayments]
      ..sort((a, b) => b.date.compareTo(a.date));
    final sortedHomework = [...homework]
      ..sort((a, b) => b.date.compareTo(a.date));

    // امتحانات الطالب — بس اللي اترصد فيها درجة أو اتسجّل غياب (مش
    // امتحانات مجدولة لسه مالهاش نتيجة). أحدث 15.
    final examRecords = exams
        .where((e) => e.grade != null || e.isAbsent)
        .toList()
      ..sort((a, b) => b.examDate.compareTo(a.examDate));

    return {
      '_docId': _codeOnly
          ? portalSafeId(code)
          : '${portalSafeId(code)}_$last4',
      'name': student.name,
      'groupName': groupName,
      'present': present,
      'late': late,
      'absent': absent,
      'totalPaid': totalPaid,
      'remaining': accumulatedDebt,
      'price': student.price,
      'exemptPercent': student.exemptPercent,
      'homeworkDone': homeworkDone,
      'homeworkPartial': homeworkPartial,
      'homeworkNotDone': homeworkNotDone,
      'attendanceHistory': sortedAttendance
          .take(20)
          .map((a) => {
                'date': a.date.toIso8601String(),
                'status': normalizeAttendanceStatus(a.status) ?? a.status,
                'statusLabel': attendanceStatusLabel(a.status),
                // حصة تعويضية (ضيف في مجموعة تانية) — الصفحة بتوضّحها لولي الأمر.
                if (guestGroupIdOf(a) != null) 'guest': true,
              })
          .toList(),
      'paymentHistory': sortedPayments
          .take(15)
          .map((p) => {
                'date': p.date.toIso8601String(),
                'amount': p.amount,
                'note': p.note ?? '',
              })
          .toList(),
      'homeworkHistory': sortedHomework
          .take(20)
          .map((h) => {
                'date': h.date.toIso8601String(),
                'status': normalizeHomeworkStatus(h.status) ?? h.status,
                'statusLabel': homeworkStatusLabel(h.status),
              })
          .toList(),
      // spec 050 — مستوى الطالب (مؤشرات + اتجاه + رسم 6 شهور)
      ..._performanceForPortal(student, groupName, attendance, homework, exams),
      // spec 048 — التسميع (لو الإعداد مفعّل وفيه درجات)
      ...recitationPortalFields(attendance,
          enabled: !Get.isRegistered<SettingsController>() ||
              Get.find<SettingsController>().showRecitation.value,
          scaleTo: currentRecitationMax(Get.isRegistered<SettingsController>()
              ? Get.find<SettingsController>().recitationMax.value
              : null)),
      // المذكرات (جوّه تاب المدفوعات في الصفحة) — فاضية لو مفيش.
      ...bookletPortalFields(bookletLines),
      'examCount': examRecords.length,
      'examHistory': examRecords
          .take(15)
          .map((e) => {
                // examId — عشان صفحة الامتحان الإلكتروني (spec 016) تلاقي
                // نتيجة هذا الامتحان بالتحديد وتعرضها للطالب بعد اعتماد المدرس.
                'examId': e.examId,
                'name': e.examName,
                'date': e.examDate.toIso8601String(),
                'absent': e.isAbsent,
                'grade': e.isAbsent ? null : e.grade,
                'maxGrade': e.maxGrade,
              })
          .toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// بينشر ملخص طالب واحد — بتُستخدم بعد إضافة/تعديل/حذف فردي (حضور،
  /// دفعة، بيانات طالب)، مش للنشر الجماعي (شوف publishAllStudents).
  /// بتتجاهل بصمت لو الميزة مش مفعّلة أو رقم ولي الأمر مش موجود/قصير —
  /// مفيش داعي نزعج المستخدم برسائل خطأ لعملية خلفية اختيارية.
  // تأخير تجميعي: نداءات متلاحقة لنفس الطالب (حضور ثم تسميع ثم دفع…) خلال الفترة
  // دي بتتحوّل لكتابة واحدة. الأقصى 2 دقيقة عشان ما نأجّلش للأبد. عند خروج
  // التطبيق للخلفية بنكتب كل المعلّق فورًا (flushPending).
  static const _debounce = Duration(seconds: 30);
  static const _maxDelay = Duration(minutes: 2);
  static final Map<int, Timer> _timers = {};
  static final Map<int, DateTime> _firstAsk = {};
  static bool _observerAdded = false;

  /// يكتب فورًا كل الملخصات المؤجّلة (بيتنادى لما التطبيق يروح للخلفية).
  static Future<void> flushPending() async {
    final ids = _timers.keys.toList();
    for (final id in ids) {
      _timers.remove(id)?.cancel();
      _firstAsk.remove(id);
      await ParentPortalService()._pushNow(id);
    }
  }

  Future<void> pushStudentSummary(int studentId, {bool immediate = false}) async {
    _watchLicenseChanges();
    if (!LicenseController.to.parentPortalActiveNow) return;
    if (immediate) {
      _timers.remove(studentId)?.cancel();
      _firstAsk.remove(studentId);
      return _pushNow(studentId);
    }
    if (!_observerAdded) {
      _observerAdded = true;
      WidgetsBinding.instance.addObserver(_PortalFlushObserver());
    }
    final first = _firstAsk.putIfAbsent(studentId, DateTime.now);
    _timers.remove(studentId)?.cancel();
    final waited = DateTime.now().difference(first);
    final delay = waited >= _maxDelay ? Duration.zero : _debounce;
    _timers[studentId] = Timer(delay, () {
      _timers.remove(studentId);
      _firstAsk.remove(studentId);
      unawaited(_pushNow(studentId));
    });
  }

  Future<void> _pushNow(int studentId) async {
    if (!LicenseController.to.parentPortalActiveNow) return;
    // نداءات متلاحقة لنفس الطالب (حضور ثم تسميع ثم دفع…) بتتجمّع: واحدة شغّالة
    // + إعادة واحدة بعدها بدل كتابة لكل نداء.
    if (_inflight.contains(studentId)) {
      _dirty.add(studentId);
      return;
    }
    _inflight.add(studentId);
    try {
      await _pushStudentSummaryNow(studentId);
      while (_dirty.remove(studentId)) {
        await _pushStudentSummaryNow(studentId);
      }
    } finally {
      _inflight.remove(studentId);
    }
  }

  Future<void> _pushStudentSummaryNow(int studentId) async {
    try {
      final student = await _dbService.getStudent(studentId);
      if (student == null) return;

      final attendanceRecords =
          await _dbService.getAttendanceByStudent(studentId);
      final payments = await _dbService.getPaymentsByStudent(studentId);
      final homework = await _dbService.getHomeworkByStudent(studentId);
      final exams = await _dbService.getStudentExamHistory(studentId);
      final group = await _dbService.getGroup(student.groupId);
      final allStudents = student.siblingGroupId != null
          ? await _dbService.getAllStudents()
          : const <Student>[];
      final bk = await _loadBookletData();
      final data = _buildSummaryData(student,
          attendance: attendanceRecords,
          payments: payments,
          homework: homework,
          groupName: group?.name ?? '',
          exams: exams,
          group: group,
          allStudents: allStudents,
          bookletLines: studentBookletPortalLines(
              student: student,
              booklets: bk.booklets,
              links: bk.links,
              records: bk.records,
              payments: bk.payments));
      if (data == null) return;
      final docId = data.remove('_docId') as String;

      await _ensureAuth();
      final slug = await ensureSlug();
      await _loadHashes(slug);
      final h = _hashOf(data);
      if (_pubHash[docId] == h) return; // نفس المنشور: مفيش كتابة
      // لازم مستند البروفايل يكون موجود الأول — قاعدة أمان الطلاب
      // بتتحقق منه بـ get()، ولو مش موجود أصلاً الكتابة بترفض.
      await _ensureProfileThrottled(slug);

      await _db
          .collection('parent_portal')
          .doc(slug)
          .collection('students')
          .doc(docId)
          .set(data);
      _pubHash[docId] = h;
      FirestoreUsage.write('portal.student');
      await _saveHashes(slug);
    } catch (e) {
      debugPrint(
          'ParentPortalService: pushStudentSummary($studentId) failed — $e');
      // best-effort — مش هنعطّل أي حاجة في التطبيق بسبب فشل نشر خلفي
    }
  }

  /// لازم تُستدعى **قبل** حذف الطالب فعليًا (محتاجين الكود ورقم
  /// التليفون بتاعه للوصول لمستند الملخص) — وإلا بيانات الطالب المحذوف
  /// (اسمه، حضوره، مدفوعاته) تفضل معروضة للأبد لمين يعرف الكود والرقم،
  /// حتى بعد ما يتمسح من التطبيق تمامًا.
  Future<void> removeStudentSummary(Student student) async {
    if (!LicenseController.to.parentPortalActiveNow) return;
    try {
      final last4 = _last4(student.guardianPhone);
      final code = student.code.toUpperCase();
      if (code.isEmpty) return;
      final slug = await getSlugIfExists();
      if (slug == null) return;
      final col =
          _db.collection('parent_portal').doc(slug).collection('students');
      // بنمسح الشكلين (بالكود فقط / كود_آخر4) عشان مفيش بيانات طالب
      // محذوف تفضل معروضة بأي طريقة دخول.
      await col.doc(portalSafeId(code)).delete();
      _pubHash.remove(portalSafeId(code));
      if (last4 != null) {
        await col.doc('${portalSafeId(code)}_$last4').delete();
        _pubHash.remove('${portalSafeId(code)}_$last4');
      }
    } catch (_) {}
  }

  /// تغيير طريقة دخول ولي الأمر: بيمسح كل ملخصات الطلاب القديمة (بمعرّفاتها
  /// القديمة) ويعيد نشرها بالمعرّفات الجديدة — عشان بيانات قديمة ما تفضلش
  /// مفتوحة بالطريقة الأضعف/السابقة. بيرمي الخطأ لو فشل.
  Future<void> switchLoginMode() async {
    if (!LicenseController.to.parentPortalActiveNow) return;
    await _ensureAuth();
    final slug = await ensureSlug();
    await _publishProfile(slug);
    final col =
        _db.collection('parent_portal').doc(slug).collection('students');
    final snap = await col.get();
    var batch = _db.batch();
    var ops = 0;
    for (final d in snap.docs) {
      batch.delete(d.reference);
      ops++;
      if (ops >= 400) {
        await batch.commit();
        batch = _db.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
    await _clearHashes(); // كل المستندات اتمسحت: لازم النشر يكتب الكل
    await publishAllStudents();
  }

  /// نشر شامل لكل الطلاب — بيتنادى أول مرة الميزة تتفعّل، أو يدويًا من
  /// الإعدادات لو المدرس عايز "يحدّث كل حاجة دلوقتي".
  ///
  /// عمدًا مش بينادي pushStudentSummary لكل طالب لوحده — كانت بتعمل
  /// طلب شبكة منفصل (زائد قراءة قاعدة بيانات منفصلة للحضور/المدفوعات)
  /// لكل طالب، يعني لمدرس عنده 100+ طالب كانت بتاخد دقايق وممكن تتقطع
  /// في النص (يسيب الطلاب اللي بعدها من غير نشر خالص). هنا بنقرا كل
  /// الحضور/المدفوعات/المجموعات مرة واحدة بس، ونبعت التحديثات كلها في
  /// دفعة Firestore واحدة (WriteBatch) — طلب شبكة واحد تقريبًا بدل
  /// مئات.
  /// أسماء الطلاب اللي تعذّر نشرهم في آخر نشر شامل (فاضية لو كله نجح).
  static List<String> lastPublishFailed = const [];

  // ── تقليل كتابات Firestore (خطة Spark: 20 ألف كتابة/يوم) ──────────────────
  // بنفتكر «بصمة» آخر نسخة اتنشرت فعلًا لكل مستند طالب (بعد نجاح الكتابة بس)،
  // وأي نشر بعد كده بيكتب المستندات اللي اتغيّرت بس. كمان بروفايل المدرس بيتنشر
  // مرة كل فترة مش مع كل ملخص طالب (كان بيضاعف الكتابات).
  static String? _hashSlug;
  static final Map<String, String> _pubHash = {};
  static DateTime? _profileAt;
  static String? _profileSlug;
  static const _profileEvery = Duration(minutes: 30);
  static String? _profileHashSlug;
  static String? _profileHash;
  static final Set<int> _inflight = {};
  static final Set<int> _dirty = {};

  String _hashOf(Map<String, dynamic> data) => portalDocHash(data);

  Future<void> _loadHashes(String slug) async {
    if (_hashSlug == slug) return;
    _pubHash.clear();
    _hashSlug = slug;
    try {
      final raw = await _dbService.getSetting('portal_hashes_$slug');
      if (raw != null && raw.isNotEmpty) {
        (jsonDecode(raw) as Map).forEach((k, v) => _pubHash['$k'] = '$v');
      }
    } catch (_) {}
  }

  Future<void> _saveHashes(String slug) async {
    try {
      await _dbService.setSetting('portal_hashes_$slug', jsonEncode(_pubHash));
    } catch (_) {}
  }

  Future<void> _clearHashes() async {
    _pubHash.clear();
    final slug = _hashSlug ?? await getSlugIfExists();
    if (slug != null) await _saveHashes(slug);
  }

  /// بروفايل المدرس مرة كل 30 دقيقة في النشر الفردي (القاعدة محتاجاه موجود بس).
  Future<void> _ensureProfileThrottled(String slug) async {
    final now = DateTime.now();
    if (_profileSlug == slug &&
        _profileAt != null &&
        now.difference(_profileAt!) < _profileEvery) {
      return;
    }
    await _publishProfile(slug);
    _profileSlug = slug;
    _profileAt = now;
  }

  Future<int> publishAllStudents(
      {void Function(int done, int total)? onProgress,
      bool force = false}) async {
    _watchLicenseChanges();
    if (!LicenseController.to.parentPortalActiveNow) return 0;
    // عمدًا مش بننادي publishProfile() هنا — بتبلع أي فشل بصمت (مصمّمة
    // كده لاستخدامها الخلفي التفاعلي العادي)، فلو فشلت (مثلاً تسجيل
    // الدخول المجهول فشل)، كنا بنكمل نكتب دفعة الطلاب كلها بمعرّف
    // مستخدم مش متأكدين إنه صاحب المستند فعلاً — وده كان بيخلي قاعدة
    // الأمان ترفض الدفعة *كلها* دفعة واحدة (Firestore batch كله أو
    // ولا حاجة) من غير أي رسالة خطأ توصل للمدرس. هنا بنسيب أي فشل
    // يوصل لصاحب الاستدعاء (شاشة الإعدادات) عشان يظهر له تنبيه واضح.
    _watchProfileChanges();
    await _ensureAuth();
    final slug = await ensureSlug();
    await _publishProfile(slug);

    final students = await _dbService.getAllStudents();
    final allAttendance = await _dbService.getAllAttendance();
    final allPayments = await _dbService.getAllPayments();
    final allHomework = await _dbService.getAllHomework();
    final allGroups = await _dbService.getAllGroups();
    final examsByStudent = await _dbService.getAllStudentExamHistories();
    final bk = await _loadBookletData();

    final groupNameById = {for (final g in allGroups) g.id: g.name};
    final groupById = {for (final g in allGroups) g.id: g};
    final attendanceByStudent = <int, List<Attendance>>{};
    for (final a in allAttendance) {
      attendanceByStudent.putIfAbsent(a.studentId, () => []).add(a);
    }
    final paymentsByStudent = <int, List<Payment>>{};
    for (final p in allPayments) {
      paymentsByStudent.putIfAbsent(p.studentId, () => []).add(p);
    }
    final homeworkByStudent = <int, List<Homework>>{};
    for (final h in allHomework) {
      homeworkByStudent.putIfAbsent(h.studentId, () => []).add(h);
    }

    final col =
        _db.collection('parent_portal').doc(slug).collection('students');

    // النشر مقاوم لطالب واحد بياناته بتكسر: بنبني ملخّص كل طالب في try/catch،
    // وبنكتب على دفعات صغيرة (50)، ولو دفعة فشلت بنكتب مستنداتها واحد واحد عشان
    // نعزل الطالب المشكل ونكمّل الباقي (قبل كده دفعة واحدة كبيرة: طالب واحد
    // مشكل = ولا طالب بيتنشر، ومن غير ما نعرف مين).
    final failed = <String>[];
    final ids = <String>[];
    final docs = <Map<String, dynamic>>[];
    final labels = <String>[];
    final hashes = <String>[];
    var unchanged = 0;
    await _loadHashes(slug);
    for (final s in students) {
      if (s.id == null) continue;
      Map<String, dynamic>? data;
      try {
        data = _buildSummaryData(
          s,
          attendance: attendanceByStudent[s.id] ?? const [],
          payments: paymentsByStudent[s.id] ?? const [],
          homework: homeworkByStudent[s.id] ?? const [],
          groupName: groupNameById[s.groupId] ?? '',
          exams: examsByStudent[s.id] ?? const [],
          group: groupById[s.groupId],
          allStudents: students,
          bookletLines: studentBookletPortalLines(
              student: s,
              booklets: bk.booklets,
              links: bk.links,
              records: bk.records,
              payments: bk.payments),
        );
      } catch (e) {
        debugPrint('ParentPortalService: build failed for student ${s.id} — $e');
        failed.add(s.name);
        continue;
      }
      if (data == null) continue;
      final docId = data.remove('_docId') as String;
      final h = _hashOf(data);
      // force (زر «انشر الآن»): نتجاهل البصمة ونكتب الكل، لأن جهاز تاني (مساعد)
      // ممكن يكون كتب نسخة أقدم على نفس المستند وبصمتنا هنا ما تعرفش.
      if (!force && _pubHash[docId] == h) {
        unchanged++; // نفس النسخة المنشورة: مفيش كتابة
        continue;
      }
      ids.add(docId);
      docs.add(data);
      labels.add(s.name);
      hashes.add(h);
    }

    // مهلة لكل طلب: Firestore لو مفيش اتصال بيفضّل يستنى للأبد (الكتابة بتتطابر
    // محليًا) فالزر كان بيفضل «جاري النشر» من غير نهاية. بالمهلة نعتبرها فشل.
    const chunkSize = 25;
    var count = unchanged;
    onProgress?.call(0, ids.length);
    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = i + chunkSize < ids.length ? i + chunkSize : ids.length;
      try {
        final batch = _db.batch();
        for (var j = i; j < end; j++) {
          batch.set(col.doc(ids[j]), docs[j]);
        }
        await batch.commit().timeout(const Duration(seconds: 40));
        count += end - i;
        FirestoreUsage.write('portal.student', end - i);
        for (var j = i; j < end; j++) {
          _pubHash[ids[j]] = hashes[j];
        }
      } catch (e) {
        debugPrint('ParentPortalService: batch failed ($i..$end) — $e');
        for (var j = i; j < end; j++) {
          try {
            await col.doc(ids[j]).set(docs[j]).timeout(const Duration(seconds: 15));
            count++;
            FirestoreUsage.write('portal.student');
            _pubHash[ids[j]] = hashes[j];
          } catch (e2) {
            debugPrint('ParentPortalService: write failed ${ids[j]} — $e2');
            failed.add(labels[j]);
          }
        }
      }
      onProgress?.call(end, ids.length);
    }
    lastPublishFailed = failed;
    await _saveHashes(slug);
    // مفيش طالب اتنشر أصلًا والسبب أخطاء: نرمي عشان الشاشة تعرض فشل واضح.
    if (count == 0 && failed.isNotEmpty) {
      throw StateError('تعذّر نشر أي طالب (${failed.length} فشلوا)');
    }
    return count;
  }
}

/// بيكتب الملخصات المؤجّلة لما التطبيق يروح للخلفية (عشان ما تضيعش لو اتقفل).
class _PortalFlushObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(ParentPortalService.flushPending());
    }
  }
}
