// lib/controllers/settings_controller.dart

import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/services/database_service.dart';

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
    _loadCurrency();
    _loadCountryDial();
    _loadUse24hFormat();
    _loadTeacherInfo();
    _loadWhatsappSettings();
  }

  Future<void> _loadWhatsappSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      whatsappEnabled.value = prefs.getBool(_keyWaEnabled) ?? true;
      whatsappSendDay.value = prefs.getInt(_keyWaSendDay) ?? 1;
    } catch (_) {}
  }

  Future<void> setWhatsappEnabled(bool v) async {
    whatsappEnabled.value = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyWaEnabled, v);
    } catch (_) {}
  }

  Future<void> setWhatsappSendDay(int day) async {
    final d = day.clamp(1, 28);
    whatsappSendDay.value = d;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyWaSendDay, d);
    } catch (_) {}
  }

  Future<void> _loadCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_keyCurrency);
      if (saved != null && supported.any((c) => c.code == saved)) {
        currencyCode.value = saved;
      }
    } catch (_) {}
  }

  Future<void> _loadCountryDial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_keyCountryDial);
      if (saved != null && saved.isNotEmpty) {
        countryDial.value = saved;
      }
    } catch (_) {}
  }

  Future<void> _loadUse24hFormat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      use24hFormat.value = prefs.getBool(_keyUse24h) ?? true;
    } catch (_) {}
  }

  Future<void> _loadTeacherInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      teacherFullName.value = prefs.getString(_keyTeacherFullName) ?? '';
      teacherAvatarPath.value = prefs.getString(_keyTeacherAvatar) ?? '';
      teacherSpecialization.value = prefs.getString(_keyTeacherSpecialization) ?? '';
      teacherPhone.value = prefs.getString(_keyTeacherPhone) ?? '';
      teacherEmail.value = prefs.getString(_keyTeacherEmail) ?? '';
      teacherSchool.value = prefs.getString(_keyTeacherSchool) ?? '';
      teacherGender.value = prefs.getString(_keyTeacherGender) ?? 'male';
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyCurrency, code);
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCountryDial, dial);
    } catch (_) {}
  }

  Future<void> setUse24hFormat(bool v) async {
    use24hFormat.value = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyUse24h, v);
    } catch (_) {}
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyTeacherFullName, teacherFullName.value);
      await prefs.setString(_keyTeacherAvatar, teacherAvatarPath.value);
      await prefs.setString(_keyTeacherSpecialization, teacherSpecialization.value);
      await prefs.setString(_keyTeacherPhone, teacherPhone.value);
      await prefs.setString(_keyTeacherEmail, teacherEmail.value);
      await prefs.setString(_keyTeacherSchool, teacherSchool.value);
      await prefs.setString(_keyTeacherGender, teacherGender.value);
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
