// lib/controllers/settings_controller.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/notification_service.dart';

class CurrencyOption {
  final String code; // e.g., SAR
  final String nameAr; // e.g., ريال سعودي
  final String symbol; // e.g., ر.س or ريال

  const CurrencyOption({required this.code, required this.nameAr, required this.symbol});
}

class CountryDialOption {
  final String code; // ISO alpha-2/3 approx
  final String nameAr;
  final String dial; // e.g., 20 for Egypt
  const CountryDialOption({required this.code, required this.nameAr, required this.dial});
}

class SettingsController extends GetxController {
  // Supported Arabic currencies + USD
  static const List<CurrencyOption> supported = [
    CurrencyOption(code: 'EGP', nameAr: 'جنيه مصري', symbol: 'جنيه'),
    CurrencyOption(code: 'SAR', nameAr: 'ريال سعودي', symbol: 'ريال'),
    CurrencyOption(code: 'AED', nameAr: 'درهم إماراتي', symbol: 'درهم'),
    CurrencyOption(code: 'KWD', nameAr: 'دينار كويتي', symbol: 'دينار'),
    CurrencyOption(code: 'QAR', nameAr: 'ريال قطري', symbol: 'ريال'),
    CurrencyOption(code: 'BHD', nameAr: 'دينار بحريني', symbol: 'دينار'),
    CurrencyOption(code: 'OMR', nameAr: 'ريال عماني', symbol: 'ريال'),
    CurrencyOption(code: 'JOD', nameAr: 'دينار أردني', symbol: 'دينار'),
    CurrencyOption(code: 'MAD', nameAr: 'درهم مغربي', symbol: 'درهم'),
    CurrencyOption(code: 'TND', nameAr: 'دينار تونسي', symbol: 'دينار'),
    CurrencyOption(code: 'DZD', nameAr: 'دينار جزائري', symbol: 'دينار'),
    CurrencyOption(code: 'LYD', nameAr: 'دينار ليبي', symbol: 'دينار'),
    CurrencyOption(code: 'IQD', nameAr: 'دينار عراقي', symbol: 'دينار'),
    CurrencyOption(code: 'LBP', nameAr: 'ليرة لبنانية', symbol: 'ليرة'),
    CurrencyOption(code: 'SYP', nameAr: 'ليرة سورية', symbol: 'ليرة'),
    CurrencyOption(code: 'YER', nameAr: 'ريال يمني', symbol: 'ريال'),
    CurrencyOption(code: 'SDG', nameAr: 'جنيه سوداني', symbol: 'جنيه'),
    CurrencyOption(code: 'MRU', nameAr: 'أوقية موريتانية', symbol: 'أوقية'),
    CurrencyOption(code: 'USD', nameAr: 'دولار أمريكي', symbol: 'دولار'),
  ];

  static const String _keyCurrency = 'currency_code';
  static const String _keyCountryDial = 'country_dial';
  static const String _keyUse24h = 'use_24h_time_format';

  // WhatsApp group-send button control
  static const String _keyWaEnabled = 'wa_button_enabled';
  static const String _keyWaSendDay = 'wa_send_day';

  // إخفاء ماسح QR — للمدرسين اللي مش بيطبعوا أكواد QR للطلاب
  static const String _keyHideQrPayment = 'hide_qr_payment';
  static const String _keyHideQrAttendance = 'hide_qr_attendance';

  // مهلة السماح قبل ما الطالب يتعتبر "متأخر" عن دفع الشهر الحالي
  static const String _keyPaymentGraceDays = 'payment_grace_days';

  // Teacher info keys
  static const String _keyTeacherFullName = 'teacher_full_name';
  static const String _keyTeacherAvatar = 'teacher_avatar_path';
  static const String _keyTeacherSpecialization = 'teacher_specialization';
  static const String _keyTeacherPhone = 'teacher_phone';
  static const String _keyTeacherEmail = 'teacher_email';
  static const String _keyTeacherSchool = 'teacher_school';
  static const String _keyTeacherGender = 'teacher_gender'; // 'male' | 'female'

  final RxString currencyCode = 'EGP'.obs; // افتراضي: جنيه مصري
  final RxString countryDial = '20'.obs; // افتراضي: مصر
  final RxBool use24hFormat = true.obs;

  // زر إرسال الواتساب للمجموعة
  final RxBool whatsappEnabled = true.obs;   // إظهار/إخفاء الزر
  final RxInt  whatsappSendDay = 1.obs;      // اليوم الذي يظهر فيه الزر (1-28)

  // إخفاء ماسح QR في شاشتي الدفع/الحضور، ويظهر بس البحث اليدوي
  final RxBool hideQrInPayment = false.obs;
  final RxBool hideQrInAttendance = false.obs;

  // إرسال تقرير واتساب تلقائي لأولياء الأمور بعد اكتمال تسجيل حضور
  // المجموعة — افتراضيًا معطّل، المدرس يفعّله بنفسه من الإعدادات.
  final RxBool reportOnCompletionEnabled = false.obs;

  // مهلة السماح (بالأيام) في أول الشهر قبل ما شارات/تنبيهات "متأخر"
  // تظهر — افتراضيًا 0 (زي السلوك القديم بالظبط: يظهر من أول يوم).
  // ملحوظة: المديونية الفعلية (المبلغ المستحق) بتتحسب صح من أول يوم
  // دايمًا — المهلة دي بتأخّر ظهور "تنبيه" بس، مش حساب الفلوس.
  final RxInt paymentGraceDays = 0.obs;

  /// هل وصل اليوم المحدد للإرسال في الشهر الحالي؟
  bool get isWhatsappDayReached =>
      DateTime.now().day >= whatsappSendDay.value;

  /// هل زر الواتساب مرئي ومتاح الآن؟
  bool get isWhatsappAvailable =>
      whatsappEnabled.value && isWhatsappDayReached;

  // Teacher info state
  final RxString teacherFullName = ''.obs;
  final RxString teacherAvatarPath = ''.obs;
  final RxString teacherSpecialization = ''.obs;
  final RxString teacherPhone = ''.obs;
  final RxString teacherEmail = ''.obs;
  final RxString teacherSchool = ''.obs;
  final RxString teacherGender = 'male'.obs; // 'male' | 'female'

  /// "مستر" or "مس" based on gender
  String get teacherTitle => teacherGender.value == 'female' ? 'مس' : 'مستر';


  @override
  void onInit() {
    super.onInit();
    reloadFromDatabase();
  }

  /// يعيد تحميل كل الإعدادات من القاعدة — لازم بعد استعادة نسخة
  /// احتياطية (قاعدة البيانات اتستبدلت بالكامل، والقيم في الذاكرة
  /// لسه القديمة لحد ما نعيد تحميلها).
  Future<void> reloadFromDatabase() async {
    await Future.wait([
      _loadCurrency(),
      _loadCountryDial(),
      _loadUse24hFormat(),
      _loadTeacherInfo(),
      _loadWhatsappSettings(),
      _loadHideQrSettings(),
      _loadReportOnCompletionSetting(),
      _loadPaymentGraceDays(),
      _loadLateAttendanceSettings(),
    ]);
  }

  // ── تخزين الإعدادات في قاعدة البيانات (جدول app_settings) بدل
  // SharedPreferences — عشان تتضمن تلقائيًا في أي نسخة احتياطية (النسخ
  // الاحتياطي بينسخ ملف قاعدة البيانات فقط). بنقرأ من SharedPreferences
  // كخطوة ترحيل لمرة واحدة فقط لو المفتاح مش موجود لسه في القاعدة،
  // عشان مستخدمين النسخة القديمة ميفقدوش إعداداتهم المحفوظة.
  Future<String?> _dbGet(String key) => DatabaseService().getSetting(key);
  Future<void> _dbSet(String key, String value) =>
      DatabaseService().setSetting(key, value);

  Future<String?> _migrateString(String key) async {
    final v = await _dbGet(key);
    if (v != null) return v;
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(key);
      if (legacy != null) await _dbSet(key, legacy);
      return legacy;
    } catch (_) {
      return null;
    }
  }

  Future<bool?> _migrateBool(String key) async {
    final v = await _dbGet(key);
    if (v != null) return v == '1';
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getBool(key);
      if (legacy != null) await _dbSet(key, legacy ? '1' : '0');
      return legacy;
    } catch (_) {
      return null;
    }
  }

  Future<int?> _migrateInt(String key) async {
    final v = await _dbGet(key);
    if (v != null) return int.tryParse(v);
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getInt(key);
      if (legacy != null) await _dbSet(key, legacy.toString());
      return legacy;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadWhatsappSettings() async {
    try {
      whatsappEnabled.value = await _migrateBool(_keyWaEnabled) ?? true;
      whatsappSendDay.value = await _migrateInt(_keyWaSendDay) ?? 1;
    } catch (_) {}
  }

  Future<void> _loadHideQrSettings() async {
    try {
      hideQrInPayment.value = await _migrateBool(_keyHideQrPayment) ?? false;
      hideQrInAttendance.value = await _migrateBool(_keyHideQrAttendance) ?? false;
    } catch (_) {}
  }

  Future<void> setHideQrInPayment(bool v) async {
    hideQrInPayment.value = v;
    try {
      await _dbSet(_keyHideQrPayment, v ? '1' : '0');
    } catch (_) {}
  }

  Future<void> setHideQrInAttendance(bool v) async {
    hideQrInAttendance.value = v;
    try {
      await _dbSet(_keyHideQrAttendance, v ? '1' : '0');
    } catch (_) {}
  }

  Future<void> setWhatsappEnabled(bool v) async {
    whatsappEnabled.value = v;
    try {
      await _dbSet(_keyWaEnabled, v ? '1' : '0');
    } catch (_) {}
  }

  Future<void> _loadReportOnCompletionSetting() async {
    try {
      reportOnCompletionEnabled.value =
          await _migrateBool(SETTING_REPORT_ON_COMPLETION_ENABLED) ?? false;
    } catch (_) {}
  }

  Future<void> setReportOnCompletionEnabled(bool v) async {
    reportOnCompletionEnabled.value = v;
    try {
      await _dbSet(SETTING_REPORT_ON_COMPLETION_ENABLED, v ? '1' : '0');
    } catch (_) {}
  }

  Future<void> _loadPaymentGraceDays() async {
    try {
      paymentGraceDays.value = await _migrateInt(_keyPaymentGraceDays) ?? 0;
    } catch (_) {}
  }

  Future<void> setPaymentGraceDays(int days) async {
    final d = days.clamp(0, 28);
    paymentGraceDays.value = d;
    try {
      await _dbSet(_keyPaymentGraceDays, d.toString());
    } catch (_) {}
  }

  // ── حالة حضور "متأخر" (spec 011) ──────────────────────────────
  // مهلة السماح بالدقايق بعد بداية الحصة قبل ما مسح الـQR يسجّل "متأخر".
  final RxInt lateGraceMinutes = 15.obs;
  // تفعيل حساب "متأخر" تلقائيًا عند مسح الـQR (لو معطّل → "حاضر" دايمًا).
  final RxBool qrAutoLateEnabled = true.obs;

  Future<void> _loadLateAttendanceSettings() async {
    try {
      lateGraceMinutes.value =
          await _migrateInt(SETTING_LATE_GRACE_MINUTES) ?? 15;
      qrAutoLateEnabled.value =
          await _migrateBool(SETTING_QR_AUTO_LATE_ENABLED) ?? true;
    } catch (_) {}
  }

  Future<void> setLateGraceMinutes(int minutes) async {
    final m = minutes.clamp(0, 120);
    lateGraceMinutes.value = m;
    try {
      await _dbSet(SETTING_LATE_GRACE_MINUTES, m.toString());
    } catch (_) {}
  }

  Future<void> setQrAutoLateEnabled(bool v) async {
    qrAutoLateEnabled.value = v;
    try {
      await _dbSet(SETTING_QR_AUTO_LATE_ENABLED, v ? '1' : '0');
    } catch (_) {}
  }

  Future<void> setWhatsappSendDay(int day) async {
    final d = day.clamp(1, 28);
    whatsappSendDay.value = d;
    try {
      await _dbSet(_keyWaSendDay, d.toString());
    } catch (_) {}
  }

  Future<void> _loadCurrency() async {
    try {
      final saved = await _migrateString(_keyCurrency);
      if (saved != null && supported.any((c) => c.code == saved)) {
        currencyCode.value = saved;
      }
    } catch (_) {}
  }

  Future<void> _loadCountryDial() async {
    try {
      final saved = await _migrateString(_keyCountryDial);
      if (saved != null && saved.isNotEmpty) {
        countryDial.value = saved;
      }
    } catch (_) {}
  }

  Future<void> _loadUse24hFormat() async {
    try {
      use24hFormat.value = await _migrateBool(_keyUse24h) ?? true;
    } catch (_) {}
  }

  Future<void> _loadTeacherInfo() async {
    try {
      teacherFullName.value = await _migrateString(_keyTeacherFullName) ?? '';
      teacherAvatarPath.value = await _migrateString(_keyTeacherAvatar) ?? '';
      teacherSpecialization.value = await _migrateString(_keyTeacherSpecialization) ?? '';
      teacherPhone.value = await _migrateString(_keyTeacherPhone) ?? '';
      teacherEmail.value = await _migrateString(_keyTeacherEmail) ?? '';
      teacherSchool.value = await _migrateString(_keyTeacherSchool) ?? '';
      teacherGender.value = await _migrateString(_keyTeacherGender) ?? 'male';
    } catch (_) {}
  }

  CurrencyOption get currentCurrency {
    return supported.firstWhere(
      (c) => c.code == currencyCode.value,
      orElse: () => supported.first,
    );
  }

  String get symbol => currentCurrency.symbol;

  Future<void> setCurrency(String code) async {
    if (supported.any((c) => c.code == code)) {
      currencyCode.value = code;
      try {
        await _dbSet(_keyCurrency, code);
      } catch (_) {}
    }
  }

  // ===== Country Dials =====
  static const List<CountryDialOption> arabCountryDials = [
    CountryDialOption(code: 'EG', nameAr: 'مصر', dial: '20'),
    CountryDialOption(code: 'SA', nameAr: 'السعودية', dial: '966'),
    CountryDialOption(code: 'AE', nameAr: 'الإمارات', dial: '971'),
    CountryDialOption(code: 'KW', nameAr: 'الكويت', dial: '965'),
    CountryDialOption(code: 'QA', nameAr: 'قطر', dial: '974'),
    CountryDialOption(code: 'BH', nameAr: 'البحرين', dial: '973'),
    CountryDialOption(code: 'OM', nameAr: 'عُمان', dial: '968'),
    CountryDialOption(code: 'JO', nameAr: 'الأردن', dial: '962'),
    CountryDialOption(code: 'MA', nameAr: 'المغرب', dial: '212'),
    CountryDialOption(code: 'TN', nameAr: 'تونس', dial: '216'),
    CountryDialOption(code: 'DZ', nameAr: 'الجزائر', dial: '213'),
    CountryDialOption(code: 'LY', nameAr: 'ليبيا', dial: '218'),
    CountryDialOption(code: 'IQ', nameAr: 'العراق', dial: '964'),
    CountryDialOption(code: 'LB', nameAr: 'لبنان', dial: '961'),
    CountryDialOption(code: 'SY', nameAr: 'سوريا', dial: '963'),
    CountryDialOption(code: 'YE', nameAr: 'اليمن', dial: '967'),
    CountryDialOption(code: 'SD', nameAr: 'السودان', dial: '249'),
    CountryDialOption(code: 'PS', nameAr: 'فلسطين', dial: '970'),
    CountryDialOption(code: 'MR', nameAr: 'موريتانيا', dial: '222'),
    CountryDialOption(code: 'SO', nameAr: 'الصومال', dial: '252'),
    CountryDialOption(code: 'KM', nameAr: 'جزر القمر', dial: '269'),
    CountryDialOption(code: 'DJ', nameAr: 'جيبوتي', dial: '253'),
  ];

  Future<void> setCountryDial(String dial) async {
    countryDial.value = dial;
    try {
      await _dbSet(_keyCountryDial, dial);
    } catch (_) {}
  }

  Future<void> setUse24hFormat(bool v) async {
    use24hFormat.value = v;
    try {
      await _dbSet(_keyUse24h, v ? '1' : '0');
    } catch (_) {}
    // نصوص الإشعارات المجدولة (تذكير الحصة، ملخص اليوم) بتتحدّد وقت
    // الجدولة، فلازم إعادة جدولة عشان تظهر بالصيغة الجديدة.
    unawaited(NotificationService().syncAllScheduledNotifications());
  }

  // ===== Teacher Info =====
  void setTeacherFullName(String v) => teacherFullName.value = v;
  void setTeacherAvatarPath(String v) => teacherAvatarPath.value = v;
  void setTeacherSpecialization(String v) => teacherSpecialization.value = v;
  void setTeacherPhone(String v) => teacherPhone.value = v;
  void setTeacherEmail(String v) => teacherEmail.value = v;
  void setTeacherSchool(String v) => teacherSchool.value = v;
  void setTeacherGender(String v) => teacherGender.value = v;

  Future<void> saveTeacherInfo() async {
    try {
      await _dbSet(_keyTeacherFullName, teacherFullName.value);
      await _dbSet(_keyTeacherAvatar, teacherAvatarPath.value);
      await _dbSet(_keyTeacherSpecialization, teacherSpecialization.value);
      await _dbSet(_keyTeacherPhone, teacherPhone.value);
      await _dbSet(_keyTeacherEmail, teacherEmail.value);
      await _dbSet(_keyTeacherSchool, teacherSchool.value);
      await _dbSet(_keyTeacherGender, teacherGender.value);
    } catch (_) {}
  }

  /// Export all data to a JSON file and return the full file path
  Future<String> backupData() async {
    final db = DatabaseService();
    // Fetch all tables
    final groups = await db.getAllGroups();
    final students = await db.getAllStudents();
    final attendance = await db.getAllAttendance();
    final payments = await db.getAllPayments();

    // Build JSON payload
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final ts = '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';

    final payload = {
      'version': DATABASE_VERSION,
      'exported_at': now.toIso8601String(),
      'groups': groups.map((e) => e.toMap()).toList(),
      'students': students.map((e) => e.toMap()).toList(),
      'attendance': attendance.map((e) => e.toMap()).toList(),
      'payments': payments.map((e) => e.toMap()).toList(),
    };

    final encoder = const JsonEncoder.withIndent('  ');
    final jsonStr = encoder.convert(payload);

    // Choose app documents directory (no extra permissions needed)
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'active_class_backup_$ts.json';
    final fullPath = p.join(dir.path, fileName);
    final file = File(fullPath);
    await file.writeAsString(jsonStr);

    return fullPath;
  }

  /// Delete all data from the database
  Future<void> deleteAllData() async {
    final db = DatabaseService();
    await db.deleteAllData();
  }
}
