// lib/controllers/booking_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';

import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/models/booking_request_model.dart';
import 'package:active_class/services/booking_service.dart';
import 'package:active_class/services/database_service.dart';

class BookingController extends GetxController {
  final BookingService _service = BookingService();
  final DatabaseService _db = DatabaseService();

  final RxBool loading = true.obs;
  final RxBool enabled = false.obs;
  final RxString slug = ''.obs;
  final RxString coverUrl = ''.obs;
  final RxBool uploadingCover = false.obs;
  final RxString bio = ''.obs;
  final RxBool savingBio = false.obs;

  // إعدادات الحقول الاختيارية — إظهار + إجبارية
  final RxBool showGrade = true.obs;
  final RxBool requireGrade = false.obs;
  final RxBool showClass = true.obs;
  final RxBool requireClass = false.obs;
  final RxBool showTime = true.obs;
  final RxBool requireTime = false.obs;
  final RxBool showNotes = true.obs;
  final RxBool requireNotes = false.obs;

  /// حقول مخصصة يضيفها المعلم بنفسه — كل عنصر {key, label, required}.
  /// الحد الأقصى 6 عشان الفورم مايطولش أوي.
  final RxList<Map<String, dynamic>> customFields = <Map<String, dynamic>>[].obs;
  static const maxCustomFields = 6;

  final RxList<BookingRequest> requests = <BookingRequest>[].obs;
  final RxBool syncError = false.obs;
  StreamSubscription? _sub;

  String get bookingUrl =>
      slug.value.isEmpty ? '' : 'https://active-class.online/book/${slug.value}';

  static const _kEnabled = 'booking_enabled';
  static const _kSlug = 'booking_slug';
  static const _kShowGrade = 'booking_show_grade';
  static const _kRequireGrade = 'booking_require_grade';
  static const _kShowClass = 'booking_show_class';
  static const _kRequireClass = 'booking_require_class';
  static const _kShowTime = 'booking_show_time';
  static const _kRequireTime = 'booking_require_time';
  static const _kShowNotes = 'booking_show_notes';
  static const _kRequireNotes = 'booking_require_notes';
  static const _kCustomFields = 'booking_custom_fields';

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<bool> _flag(String key, {bool fallback = true}) async {
    final v = await _db.getSetting(key);
    if (v == null) return fallback;
    return v == '1';
  }

  Future<void> retry() => _load();

  Future<void> _load() async {
    try {
      enabled.value = await _flag(_kEnabled, fallback: false);
      slug.value = await _db.getSetting(_kSlug) ?? '';
      showGrade.value = await _flag(_kShowGrade);
      requireGrade.value = await _flag(_kRequireGrade, fallback: false);
      showClass.value = await _flag(_kShowClass);
      requireClass.value = await _flag(_kRequireClass, fallback: false);
      showTime.value = await _flag(_kShowTime);
      requireTime.value = await _flag(_kRequireTime, fallback: false);
      showNotes.value = await _flag(_kShowNotes);
      requireNotes.value = await _flag(_kRequireNotes, fallback: false);
      final rawCustom = await _db.getSetting(_kCustomFields);
      if (rawCustom != null && rawCustom.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawCustom) as List;
          customFields.value = decoded.cast<Map<String, dynamic>>();
        } catch (_) {}
      }
      if (enabled.value && slug.value.isNotEmpty) {
        // نعيد ربط ownerUid بالـ uid الحالي قبل السماع — لو الجهاز عدّى
        // بإعادة تثبيت غيّرت anonymous auth uid، هيك بنمنع رفض القراءة
        // الصامت من security rules (راجع BookingService.refreshOwnerUid).
        try {
          final license = Get.find<LicenseController>();
          await _service.refreshOwnerUid(slug.value, license.deviceId.value);
        } catch (_) {}
        _listen();
        await _loadRemoteExtras();
      }
    } finally {
      loading.value = false;
    }
  }

  Future<void> _loadRemoteExtras() async {
    try {
      final data = await _service.getProfile(slug.value);
      coverUrl.value = (data?['coverUrl'] as String?) ?? '';
      bio.value = (data?['bio'] as String?) ?? '';
    } catch (_) {}
  }

  void _listen() {
    _sub?.cancel();
    _sub = _service.watchRequests(slug.value).listen((snap) {
      syncError.value = false;
      requests.value = snap.docs
          .map((d) => BookingRequest.fromMap(d.id, d.data()))
          .toList();
    }, onError: (_) {
      // لو رفضت security rules القراءة (مثلاً ownerUid قديم بعد إعادة
      // تثبيت التطبيق) لازم يبان ده للمعلم بدل ما تفضل القائمة فاضية
      // بصمت وهو يفتكر إنه مفيش طلبات حجز جديدة.
      syncError.value = true;
    });
  }

  Map<String, dynamic> _fieldsMap() => {
        'grade': {'show': showGrade.value, 'required': requireGrade.value},
        'classSection': {
          'show': showClass.value,
          'required': requireClass.value
        },
        'preferredTime': {
          'show': showTime.value,
          'required': requireTime.value
        },
        'notes': {'show': showNotes.value, 'required': requireNotes.value},
      };

  Future<void> _syncProfile({
    required String teacherName,
    String? subject,
    String? title,
    String? photoUrl,
  }) async {
    if (slug.value.isEmpty) return;
    final license = Get.find<LicenseController>();
    await _service.upsertTeacherProfile(
      slug: slug.value,
      deviceId: license.deviceId.value,
      name: teacherName,
      subject: subject,
      title: title,
      photoUrl: photoUrl,
      active: enabled.value,
      fields: _fieldsMap(),
      customFields: customFields.toList(),
    );
  }

  Future<void> _persistCustomFields() async {
    await _db.setSetting(_kCustomFields, jsonEncode(customFields));
  }

  /// يضيف حقل مخصص جديد. يرجّع رسالة خطأ أو null لو نجح.
  Future<String?> addCustomField(
    String label, {
    required bool required,
    required String teacherName,
    String? subject,
    String? title,
  }) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return 'اكتب اسم الحقل';
    if (customFields.length >= maxCustomFields) {
      return 'أقصى عدد حقول مخصصة $maxCustomFields';
    }
    final key = 'c${DateTime.now().millisecondsSinceEpoch}';
    customFields.add({'key': key, 'label': trimmed, 'required': required});
    customFields.refresh();
    await _persistCustomFields();
    if (enabled.value) {
      try {
        await _syncProfile(teacherName: teacherName, subject: subject, title: title);
      } catch (_) {}
    }
    return null;
  }

  Future<void> removeCustomField(
    String key, {
    required String teacherName,
    String? subject,
    String? title,
  }) async {
    customFields.removeWhere((f) => f['key'] == key);
    await _persistCustomFields();
    if (enabled.value) {
      try {
        await _syncProfile(teacherName: teacherName, subject: subject, title: title);
      } catch (_) {}
    }
  }

  Future<void> toggleCustomFieldRequired(
    String key,
    bool required, {
    required String teacherName,
    String? subject,
    String? title,
  }) async {
    final idx = customFields.indexWhere((f) => f['key'] == key);
    if (idx == -1) return;
    customFields[idx] = {...customFields[idx], 'required': required};
    customFields.refresh();
    await _persistCustomFields();
    if (enabled.value) {
      try {
        await _syncProfile(teacherName: teacherName, subject: subject, title: title);
      } catch (_) {}
    }
  }

  /// يفعّل/يوقف رابط الحجز. يرجّع رسالة خطأ أو null لو نجح.
  Future<String?> setEnabled(
    bool value, {
    required String teacherName,
    String? subject,
    String? title,
    String? photoLocalPath,
  }) async {
    final license = Get.find<LicenseController>();
    if (value && !license.canBooking) {
      return 'ميزة الحجز غير متاحة في باقتك الحالية';
    }

    if (value && slug.value.isEmpty) {
      slug.value = _service.generateSlug();
      await _db.setSetting(_kSlug, slug.value);
    }

    enabled.value = value;
    await _db.setSetting(_kEnabled, value ? '1' : '0');

    String? photoUrl;
    if (value && photoLocalPath != null && photoLocalPath.isNotEmpty) {
      final file = File(photoLocalPath);
      if (await file.exists()) {
        photoUrl = await _service.uploadPhoto(slug.value, file);
      }
    }

    try {
      if (value) {
        await _syncProfile(
            teacherName: teacherName,
            subject: subject,
            title: title,
            photoUrl: photoUrl);
        _listen();
      } else {
        await _service.setActive(slug.value, false);
        await _sub?.cancel();
      }
    } catch (e) {
      return 'تعذر الاتصال بالإنترنت — حاول تاني';
    }
    return null;
  }

  Future<void> updateField(
    String key, {
    bool? show,
    bool? required,
    required String teacherName,
    String? subject,
    String? title,
  }) async {
    switch (key) {
      case 'grade':
        if (show != null) {
          showGrade.value = show;
          await _db.setSetting(_kShowGrade, show ? '1' : '0');
        }
        if (required != null) {
          requireGrade.value = required;
          await _db.setSetting(_kRequireGrade, required ? '1' : '0');
        }
        break;
      case 'classSection':
        if (show != null) {
          showClass.value = show;
          await _db.setSetting(_kShowClass, show ? '1' : '0');
        }
        if (required != null) {
          requireClass.value = required;
          await _db.setSetting(_kRequireClass, required ? '1' : '0');
        }
        break;
      case 'preferredTime':
        if (show != null) {
          showTime.value = show;
          await _db.setSetting(_kShowTime, show ? '1' : '0');
        }
        if (required != null) {
          requireTime.value = required;
          await _db.setSetting(_kRequireTime, required ? '1' : '0');
        }
        break;
      case 'notes':
        if (show != null) {
          showNotes.value = show;
          await _db.setSetting(_kShowNotes, show ? '1' : '0');
        }
        if (required != null) {
          requireNotes.value = required;
          await _db.setSetting(_kRequireNotes, required ? '1' : '0');
        }
        break;
    }
    if (enabled.value) {
      try {
        await _syncProfile(
            teacherName: teacherName, subject: subject, title: title);
      } catch (_) {}
    }
  }

  /// السيرة الذاتية اختيارية بالكامل — لو المعلم سابها فاضية، صفحة الحجز
  /// العامة مبتظهرش قسمها خالص (بدل ما تعرض مساحة فاضية بلا فايدة).
  Future<void> saveBio(String value) async {
    if (slug.value.isEmpty) return;
    savingBio.value = true;
    try {
      bio.value = value;
      await _service.updateBio(slug.value, value);
    } finally {
      savingBio.value = false;
    }
  }

  /// يرفع صورة خلفية (غلاف) صفحة الحجز العامة. متاحة بس بعد ما الرابط
  /// يتفعّل (محتاجين slug موجود). لو المعلم ملوش صورة خلفية، الصفحة
  /// العامة بترجع للتدرج اللوني الافتراضي بدلها.
  Future<String?> uploadCover(File file) async {
    if (slug.value.isEmpty) return 'فعّل رابط الحجز أولاً';
    uploadingCover.value = true;
    try {
      final url = await _service.uploadPhoto(slug.value, file, kind: 'cover');
      if (url == null) return 'فشل رفع الصورة — حاول تاني';
      await _service.updateCoverUrl(slug.value, url);
      coverUrl.value = url;
      return null;
    } finally {
      uploadingCover.value = false;
    }
  }

  Future<void> removeCover() async {
    if (slug.value.isEmpty) return;
    coverUrl.value = '';
    try {
      await _service.updateCoverUrl(slug.value, '');
      await _service.deleteUploadedImage(slug.value, kind: 'cover');
    } catch (_) {}
  }

  Future<void> removeRequest(BookingRequest r) async {
    requests.removeWhere((x) => x.id == r.id);
    try {
      await _service.deleteRequest(slug.value, r.id);
    } catch (_) {}
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
