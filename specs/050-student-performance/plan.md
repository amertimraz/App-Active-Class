# Implementation Plan: تقرير أداء ومستوى الطالب

**Branch**: `050-student-performance` | **Date**: 2026-10-08 | **Spec**: [spec.md](spec.md)

## Summary
نواة حساب صرفة قابلة للاختبار (`performance.dart`) تبني مؤشرات الأداء الأربعة واتجاهها وسلاسل 6 شهور من بيانات موجودة (بلا تغيير DB). فوقها: تبويب "الأداء" في تفاصيل الطالب (بطاقات مؤشرات + رسم `fl_chart`)، ومخرجات الإرسال (نص، كارت صورة، PDF)، وترتيب المجموعة بالمستوى مع إرسال جماعي، وقسم في بوابة الأهالي.

## Technical Context
Flutter 3.38 / Dart 3.5, GetX, sqflite (لا تغيير)، `fl_chart ^0.68` (موجود)، `pdf`/`printing`، `share_plus`. اختبارات `flutter test`. قيد: صفحة المتابعة (HTML) تحتاج نشر على VPS بموافقة المستخدم؛ لا migration.

## Constitution Check
القالب غير مُعبَّأ → لا بوابات. ملتزم بنمط: دوال صرفة + اختبارات + احترام الصلاحيات والسويتشات.

## Project Structure
```
lib/utils/performance.dart                      (جديد، النواة الصرفة)
lib/services/performance_service.dart           (جديد، جلب فردي/جماعي)
lib/widgets/performance_card.dart               (جديد: PerformanceCard + capture PNG)
lib/views/students/student_performance_tab.dart (جديد: تبويب الأداء + رسم + زر الإرسال)
lib/views/students/student_details_page.dart    (تبويب رابع "الأداء" بصلاحية الأكاديميات)
lib/views/groups/group_performance_page.dart    (جديد: ترتيب + فلتر + إرسال جماعي)
lib/views/groups/group_details_page.dart        (زر "الأداء")
lib/services/export_service.dart                (exportStudentPerformancePDF)
lib/services/parent_portal_service.dart         (حقل performance في الملخص)
lib/controllers/settings_controller.dart        (إعادة نشر الملخصات عند تغيير سويتش الواجب)
booking_site/track/index.html                   (قسم مستوى الطالب — محلي حتى موافقة النشر)
test/performance_test.dart                      (جديد)
```

## Design notes
- كل مخرج (شاشة/نص/كارت/PDF/بوابة) يبنى من نفس `StudentPerformance` → أرقام متطابقة (SC-002).
- المؤشرات المفعّلة تُحدَّد مرة واحدة (من السويتشات) وتُمرَّر للبناء.
- الكارت: عرض 360 ثابت، خط Cairo، ألوان الاتجاه (أخضر/رمادي/أحمر) مع سهم نصي لتفادي الاعتماد على اللون فقط.
- الإرسال الجماعي: نفس إطار تقرير الشهر الجماعي (ملخص قبل البدء، انتظار الرجوع من واتساب، تخطي من بلا رقم).
