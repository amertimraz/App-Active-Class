// lib/widgets/clock_text.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/utils/helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  عرض الوقت التفاعلي — الطريقة الموحّدة الوحيدة لعرض أي وقت في الواجهة.
//
//  المشكلة اللي بتحلّها: `FormatHelper.formatTime/formatDateTime/formatPaymentDate`
//  دوال static بتقرا `SettingsController.use24hFormat` (RxBool) خارج أي نطاق
//  تفاعلي، فالشاشة المبنية مبتعيدش البناء لما المدرس يقلب مفتاح "نظام الساعة 24"
//  من الإعدادات. الودجت دي بتلفّ القراءة في `Obx` مرة واحدة في مكان واحد، فأي
//  تبديل ينعكس فورًا من غير إعادة تشغيل ومن غير حِيَل يدوية مبعثرة في كل شاشة.
//
//  للنصوص اللي الوقت متداخل جواها ("في 2:30 م") أو جوه `title:`/`subtitle:`
//  استخدم [ClockBuilder].
// ─────────────────────────────────────────────────────────────────────────────

/// يشترك في `use24hFormat` ويعيد بناء [builder] عند تغييره.
void _watchClockFormat() {
  try {
    // ignore: unnecessary_statements
    Get.find<SettingsController>().use24hFormat.value;
  } catch (_) {}
}

/// وقت فقط (ساعة:دقيقة) — `FormatHelper.formatTime`.
class ClockText extends StatelessWidget {
  final DateTime? value;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ClockText(
    this.value, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) => Obx(() {
        _watchClockFormat();
        return Text(
          FormatHelper.formatTime(value),
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      });
}

/// تاريخ + وقت — `FormatHelper.formatDateTime`.
class ClockDateTimeText extends StatelessWidget {
  final DateTime? value;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ClockDateTimeText(
    this.value, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) => Obx(() {
        _watchClockFormat();
        return Text(
          FormatHelper.formatDateTime(value),
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      });
}

/// تاريخ + وقت بدقّة سجلّ الدفعات — `FormatHelper.formatPaymentDate`.
class ClockPaymentDateText extends StatelessWidget {
  final DateTime? value;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ClockPaymentDateText(
    this.value, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) => Obx(() {
        _watchClockFormat();
        return Text(
          FormatHelper.formatPaymentDate(value),
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      });
}

/// للحالات اللي الوقت متداخل جوه نص أكبر أو جوه `title:`/`subtitle:` —
/// `builder` بيتنفّذ جوه `Obx` بيشترك في `use24hFormat`.
class ClockBuilder extends StatelessWidget {
  final Widget Function(BuildContext context) builder;

  const ClockBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => Obx(() {
        _watchClockFormat();
        return builder(context);
      });
}
