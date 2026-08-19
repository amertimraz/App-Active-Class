// lib/utils/helpers.dart
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/widgets/app_toast.dart';

/// يتحقق من صلاحية الوصول لميزة محدودة بالباقة (نسخ احتياطي/واتساب
/// جماعي/تصدير). لو ممنوعة، بيعرض SnackBar فيه زر "ترقية" ويرجّع false.
bool requireLicenseFeature(BuildContext context, bool allowed, String deniedMessage) {
  if (allowed) return true;
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(
    content: Text(deniedMessage, style: const TextStyle(fontFamily: 'Cairo')),
    backgroundColor: Colors.red.shade700,
    duration: const Duration(seconds: 4),
    action: SnackBarAction(
      label: 'ترقية',
      textColor: Colors.white,
      onPressed: () => Get.toNamed(ROUTE_PLANS),
    ),
  ));
  return false;
}

/// يتحقق إن أفعال النظام الخطيرة (حذف كامل البيانات / استعادة نسخة
/// احتياطية بتستبدل كل حاجة) متاحة بس للمدرس (صاحب الفريق) لو وضع
/// الفريق مفعّل — أي مساعد، مهما كانت صلاحياته التانية، ميقدرش
/// يوصلها. لو وضع الفريق مش مفعّل أصلاً، الفعل متاح عادي زي ما كان
/// دايمًا (مفيش تأثير على مستخدم لوحده).
bool requireTeamOwnerIfTeamMode(BuildContext context) {
  final team = TeamModeService();
  if (!team.isEnabled.value || team.isOwner.value) return true;
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(const SnackBar(
    content: Text(
      'الإجراء ده متاح للمدرس (صاحب الفريق) بس',
      style: TextStyle(fontFamily: 'Cairo'),
    ),
    backgroundColor: Colors.red,
    duration: Duration(seconds: 3),
  ));
  return false;
}

/// يتحقق إن المساعد عنده صلاحية الحذف المطلوبة (حضور/دفعات/طلاب-
/// مجموعات) **قبل** ما نسمح بالحذف محليًا. من غير الفحص ده، الحذف كان
/// بيحصل محليًا على طول ويختفي الصف من شاشة المساعد فورًا، وبعدين
/// السيرفر بس هو اللي بيرفض المزامنة بصمت (RLS trigger) — يعني الصف
/// يفضل موجود عند المدرس بس متسحّب من عند المساعد، لخبطة حقيقية بين
/// الجهازين بدل ما نمنع الحذف من الأساس.
bool requireDeletePermission(BuildContext context, bool allowed) {
  if (allowed) return true;
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(const SnackBar(
    content: Text(
      'معندكش صلاحية الحذف ده — كلم المدرس يفعّلها من شاشة إدارة الأعضاء',
      style: TextStyle(fontFamily: 'Cairo'),
    ),
    backgroundColor: Colors.red,
    duration: Duration(seconds: 3),
  ));
  return false;
}

/// أدوات تنسيق للنصوص والتواريخ
class FormatHelper {
  /// تنسيق التاريخ
  static String formatDate(DateTime? date) {
    if (date == null) return 'لم يتم التحديد';
    return DateFormat('yyyy-MM-dd', 'ar').format(date);
    }

  /// تنسيق تاريخ الدفعة — يوم + ساعة + دقيقة (للدقة في السجلات)
  static String formatPaymentDate(DateTime? date) {
    if (date == null) return 'لم يتم التحديد';
    String timePattern = 'HH:mm';
    try {
      final settings = Get.find<SettingsController>();
      timePattern = settings.use24hFormat.value ? 'HH:mm' : 'hh:mm a';
    } catch (_) {}
    return DateFormat('yyyy-MM-dd  $timePattern', 'ar').format(date);
  }

  /// تنسيق التاريخ الكامل (مثال: الاثنين، 10 يناير 2025)
  static String formatFullDate(DateTime? date) {
    if (date == null) return 'لم يتم التحديد';
    return DateFormat('EEEE d MMMM yyyy', 'ar').format(date);
  }

  /// تنسيق الوقت
  static String formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'لم يتم التحديد';
    String pattern = 'HH:mm';
    try {
      final settings = Get.find<SettingsController>();
      pattern = settings.use24hFormat.value ? 'HH:mm' : 'hh:mm a';
    } catch (_) {}
    return DateFormat(pattern, 'ar').format(dateTime);
  }

  /// تنسيق التاريخ والوقت معًا
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'لم يتم التحديد';
    String timePattern = 'HH:mm';
    try {
      final settings = Get.find<SettingsController>();
      timePattern = settings.use24hFormat.value ? 'HH:mm' : 'hh:mm a';
    } catch (_) {}
    return DateFormat('yyyy-MM-dd $timePattern', 'ar').format(dateTime);
  }

  /// تنسيق العملة وفق اختيار المستخدم
  static String formatCurrency(double? amount) {
    final value = (amount ?? 0).toDouble();
    // Try to read currency from SettingsController if available
    try {
      final settings = Get.find<SettingsController>();
      final formatter = NumberFormat.currency(locale: 'ar', symbol: settings.symbol, decimalDigits: 2);
      return formatter.format(value);
    } catch (_) {
      // fallback to SAR symbol if controller not ready
      final formatter = NumberFormat.currency(locale: 'ar', symbol: 'ريال', decimalDigits: 2);
      return formatter.format(value);
    }
  }

  /// تنسيق النسبة المئوية
  static String formatPercentage(double? percentage) {
    final value = (percentage ?? 0).toDouble();
    return '${value.toStringAsFixed(0)}%';
  }

  /// الفرق بالأيام بين تاريخين
  static int daysBetween(DateTime? from, DateTime? to) {
    if (from == null || to == null) return 0;
    return to.difference(from).inDays;
  }

  /// هل التاريخ اليوم؟
  static bool isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// هل التاريخ بالأمس؟
  static bool isYesterday(DateTime? date) {
    if (date == null) return false;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  }

  /// نص نسبي للتاريخ
  static String getRelativeDateText(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (isToday(date)) {
      return 'اليوم';
    } else if (isYesterday(date)) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'منذ $weeks أسابيع';
    } else {
      return formatDate(date);
    }
  }
}

/// أدوات تحقق من المدخلات
class ValidationHelper {
  /// التحقق من عدم فراغ الحقل
  static String? validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال $fieldName';
    }
    return null;
  }

  /// التحقق من البريد الإلكتروني
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال بريد إلكتروني';
    }
    // Regex مبسط وصحيح عبر سطر واحد مع نهاية السلسلة
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!regex.hasMatch(value.trim())) {
      return 'البريد الإلكتروني غير صحيح';
    }
    return null;
  }

  /// التحقق من رقم الهاتف
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال رقم الهاتف';
    }
    if (value.trim().length < 9) {
      return 'رقم الهاتف يجب أن يكون على الأقل 9 أرقام';
    }
    return null;
  }

  /// التحقق من رقم (double)
  static String? validateNumber(String? value, {String fieldName = 'الرقم'}) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال $fieldName';
    }
    if (double.tryParse(value.trim()) == null) {
      return 'القيمة يجب أن تكون رقمًا';
    }
    return null;
  }

  /// التحقق من الحد الأدنى للطول
  static String? validateMinLength(String? value, int minLength, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال $fieldName';
    }
    if (value.trim().length < minLength) {
      return 'يجب أن يكون $fieldName على الأقل $minLength أحرف';
    }
    return null;
  }

  /// تحقق من تطابق كلمتي المرور
  static String? validatePasswordMatch(String? password, String? confirmPassword) {
    if (password != confirmPassword) {
      return 'كلمتا المرور غير متطابقتين';
    }
    return null;
  }
}

/// أدوات إحصائية
class AnalyticsHelper {
  static double calculateAttendancePercentage(int attended, int total) {
    if (total == 0) return 0;
    return (attended / total) * 100;
  }

  static double calculateAverage(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double getMaxValue(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a > b ? a : b);
  }

  static double getMinValue(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a < b ? a : b);
  }

  static double getSum(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b);
  }

  static String gradePercentage(double percentage) {
    if (percentage >= 90) return 'ممتاز';
    if (percentage >= 80) return 'جيد جدًا';
    if (percentage >= 70) return 'جيد';
    if (percentage >= 60) return 'مقبول';
    return 'ضعيف';
  }
}

/// أدوات للألوان
class ColorHelper {
  static Color getPercentageColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case 'حاضر':
      case 'مدفوع':
      case 'نشط':
        return Colors.green;
      case 'غائب':
      case 'معلّق':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  static Color getRandomColor() {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.cyan,
      Colors.pink,
      Colors.amber,
    ];
    return colors[DateTime.now().millisecond % colors.length];
  }
}

/// أدوات تخزين مبسطة
class StorageHelper {
  static Map<String, dynamic> toJson(dynamic object) {
    if (object is Map) return object.cast<String, dynamic>();
    return object.toJson();
  }

  static dynamic fromJson(Map<String, dynamic> json, Type type) {
    return json;
  }

  static bool hasData(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.isNotEmpty;
    if (value is List) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }
}

class ToastHelper {
  // بنستخدم نفس الـ AppToast اللي بيستخدمه باقي التطبيق (Overlay على
  // مستوى الـ root) بدل Get.snackbar أو ScaffoldMessenger عمداً:
  // - Get.snackbar: لو فشل (مثلاً الـ Overlay مش جاهز أثناء انتقال بين
  //   الشاشات)، GetX بيسيب الـ SnackbarController في حالة تلف لبقية
  //   الجلسة، وأي Get.back() بعد كده في أي حوار بالتطبيق بيعمل crash
  //   صامت (تجربة فعلية أثبتت المشكلة دي).
  // - ScaffoldMessenger.of(Get.context): بيدوّر على أقرب Scaffold من
  //   الجذر، فلو الرسالة طلعت من فوق Bottom Sheet/Dialog (زي فحص كود
  //   الطالب المكرر عند الحفظ)، السناك بار بيظهر ورا الموديل بدل ما
  //   يظهر فوقه. الـ Overlay الجذري بتاع AppToast بيتحط فوق كل حاجة
  //   دايماً، فمفيش المشكلة دي.
  static void _show(String title, String message, {ToastType type = ToastType.success}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = Get.context;
      if (context == null) return;
      try {
        switch (type) {
          case ToastType.success:
            AppToast.success(context, message);
            break;
          case ToastType.error:
            AppToast.error(context, message);
            break;
          case ToastType.info:
          case ToastType.warning:
            AppToast.info(context, message);
            break;
        }
      } catch (_) {}
    });
  }

  static void success(String message, {String title = 'تم'}) {
    _show(title, message, type: ToastType.success);
  }

  static void error(String message, {String title = 'خطأ'}) {
    _show(title, message, type: ToastType.error);
  }

  static void info(String message, {String title = 'تنبيه'}) {
    _show(title, message, type: ToastType.info);
  }
}

/// نغمات صوتية لماسح QR (زي أجهزة الكاشير في السوبر ماركت) — بيب حاد
/// لما الكود يتقرأ صح، ونغمة منخفضة لما الكود يكون غلط/مش موجود.
class SoundHelper {
  static final AudioPlayer _player = AudioPlayer()
    ..setPlayerMode(PlayerMode.lowLatency);

  static Future<void> _play(String asset) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(asset));
    } catch (_) {}
  }

  static void scanSuccess() => _play('sounds/scan_beep.wav');
  static void scanError() => _play('sounds/scan_error.wav');
}
