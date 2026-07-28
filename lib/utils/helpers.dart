// lib/utils/helpers.dart
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/config/constants.dart';

/// يتحقق من صلاحية الوصول لميزة محدودة بالباقة (نسخ احتياطي/واتساب
/// جماعي/تصدير). لو ممنوعة، بيعرض SnackBar فيه زر "ترقية" ويرجّع false.
bool requireLicenseFeature(BuildContext context, bool allowed, String deniedMessage) {
  if (allowed) return true;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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
  // بنستخدم ScaffoldMessenger الأصلي بدل Get.snackbar عمداً: لو أي toast
  // فشل (مثلاً الـ Overlay مش جاهز أثناء انتقال بين الشاشات)، GetX بيسيب
  // الـ SnackbarController في حالة تلف لبقية الجلسة، وأي Get.back() بعد
  // كده في أي حوار بالتطبيق بيعمل crash صامت (تجربة فعلية أثبتت المشكلة
  // دي). ScaffoldMessenger مالوش نفس المشكلة — كل فشل معزول عن التاني.
  static void _show(String title, String message, {Color bg = Colors.green}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = Get.context;
      if (context == null) return;
      try {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              Text(message, style: const TextStyle(color: Colors.white)),
            ],
          ),
          backgroundColor: bg,
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      } catch (_) {}
    });
  }

  static void success(String message, {String title = 'تم'}) {
    _show(title, message, bg: Colors.green);
  }

  static void error(String message, {String title = 'خطأ'}) {
    _show(title, message, bg: Colors.red);
  }

  static void info(String message, {String title = 'تنبيه'}) {
    _show(title, message, bg: Colors.teal);
  }
}
