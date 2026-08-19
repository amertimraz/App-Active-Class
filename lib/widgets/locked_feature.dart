// lib/widgets/locked_feature.dart
//
// لما المدرس يقفل صلاحية عرض (مالية/أكاديمية) عن مساعد، القسم بتاعها
// بيفضل ظاهر بنفس شكله وتصميمه — بس بعلامة قفل صغيرة، وبمنع التفاعل
// (tap) مع تنبيه يوضح السبب، بدل ما يختفي تمامًا من الواجهة.
import 'package:flutter/material.dart';
import 'package:active_class/utils/helpers.dart';

/// يلف أي عنصر واجهة (زرار قائمة، تاب، كارت...) بعلامة قفل صغيرة في
/// الزاوية لما `locked` تكون true — التصميم الأصلي بتاع الـ child يفضل
/// زي ما هو، بس معتّم شوية وعليه شارة قفل.
class LockBadge extends StatelessWidget {
  final Widget child;
  final bool locked;

  const LockBadge({super.key, required this.child, required this.locked});

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;
    return Stack(
      clipBehavior: Clip.none,
      // StackFit.loose (الافتراضي) بيدّي لـ child قيود "مرنة" (0 لحد
      // أقصى) بدل ما يمرّرله نفس القيود اللي كانت جايالها من غير أي
      // Stack أصلاً — فكان بيتقلّص لحجم محتواه الطبيعي (زي القائمة في
      // GridView) بدل ما يملى الخلية المخصصة له، بس بس لما يكون مقفول
      // (غير المقفول بيرجّع child مباشرة من غير Stack خالص).
      // passthrough بينقل نفس القيود الأصلية زي ما هي — آمن سواء كانت
      // القيود محدودة (GridView/Expanded) أو غير محدودة (عمود عادي).
      fit: StackFit.passthrough,
      children: [
        Opacity(opacity: 0.5, child: child),
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF6B7280),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Icon(Icons.lock_rounded, size: 11, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// بتتنادى بدل تنفيذ الفعل المقفول (فتح صفحة، تبديل تاب...) — بتوضح
/// للمساعد إن الصلاحية دي مقفولة من المدرس بدل ما تفتح الصفحة عادي.
void showLockedPermissionHint() {
  ToastHelper.info('الصلاحية دي مقفولة من المدرس');
}

/// محتوى بديل لتاب/قسم كامل مقفول — بيفضل مكانه في مكان الشاشة زي ما
/// هو (التاب نفسه يفضل ظاهر وقابل للفتح)، بس من غير أي بيانات حقيقية.
class LockedSectionPlaceholder extends StatelessWidget {
  final String? message;
  const LockedSectionPlaceholder({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded,
                size: 40, color: isDark ? Colors.white24 : Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              message ?? 'الصلاحية دي مقفولة من المدرس',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
