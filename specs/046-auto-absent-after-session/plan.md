# Implementation Plan: الغياب التلقائي بعد انتهاء الحصة

**Branch**: `046-auto-absent-after-session` | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

## Summary
خدمة صغيرة تفحص كل دقيقة (وعند الفتح/الاستئناف) الحصص المنتهية في آخر 3 أيام وتسجّل "غائب" للطلاب بلا سجل، مبنية على دوال صرفة قابلة للاختبار. تعديل واحد في مسار مسح الـQR ليستبدل الغياب التلقائي. لا schema ولا migration ولا server.

## Technical Context
Flutter 3.38 / Dart 3.5, GetX, sqflite (جدول settings موجود، DB لا تتغير). الاختبار: `flutter test`. هدف: Android. قيد: لا Workmanager (دقة)، الفحص خفيف (قراءة محلية فقط).

## Constitution Check
الـconstitution قالب غير مُعبَّأ → لا بوابات. ملتزم بنمط المشروع: دوال صرفة + اختبارات، إعدادات محلية، بلا تغيير DB.

## Project Structure
```
lib/utils/auto_absent.dart            (جديد، صرف)
lib/services/auto_absent_service.dart (جديد)
lib/config/constants.dart             (مفاتيح الإعدادات)
lib/controllers/settings_controller.dart (حالة + setters)
lib/views/settings/settings_page.dart (مفتاح + مهلة، جنب إعدادات QR)
lib/controllers/qr_controller.dart    (استبدال الغياب التلقائي عند المسح)
lib/main.dart                         (resumed + start)
test/auto_absent_test.dart            (جديد)
```

## Design notes
- الخدمة: لكل يوم في lookbackDays → لكل مجموعة بحصة (`groupHasSessionOnDay`) → `sessionEndFor` → `sessionEligible` → الطلاب اللي مالهمش سجل (من DB/القائمة) → `insertAttendance` لكل واحد → تعليم الحصة processed (حتى لو ما فيش طلاب) → تحديث واحد للقائمة + push ملخصات + تذكير الدفع.
- السجلات مؤرَّخة بيوم الحصة وبساعة الإغلاق.
- `enabled_at` يتكتب في `setAutoAbsentEnabled(true)` ويمنع الأثر الرجعي.
- تخفيف الـrace في الفريق: الفهرس الفريد + LWW (spec 031)؛ الـprocessed محلي.
