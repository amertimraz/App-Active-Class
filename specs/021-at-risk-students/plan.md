# Implementation Plan: طلاب محتاجين متابعة (إنذار مبكّر)

**Branch**: `021-at-risk-students` | **Date**: 2026-09-04 | **Spec**: [spec.md](spec.md)

## Summary

خدمة رصد نقيّة (`AtRiskService`) بتحسب 4 إشارات (غياب متتالي / واجب ناقص متكرر / هبوط درجات / تأخّر دفع) من بيانات موجودة بالفعل — بدون أي كتابة عليها. النتيجة تتعرض في شاشة جديدة + كارت لوحة تحكم + إشعار أسبوعي، وكلهم بيستخدموا نفس الدالة. الحاجة الجديدة الوحيدة المخزَّنة هي جدول "وقائع المتابعة" (`student_follow_ups`) — صف واحد لكل ضغطة "تمّت المتابعة"، بيتزامن عبر أجهزة الفريق بنفس آلية outbox/pull الموجودة لباقي الجداول.

## Technical Context

- **Language**: Dart 3.5.4 / Flutter 3.38.1، GetX.
- **Deps**: صفر حزم جديدة — `flutter_local_notifications` (موجودة، لإشعار أسبوعي) و`url_launcher`/`normalizeWhatsappPhone` (موجودان، لأزرار التواصل).
- **DB**: جدول جديد واحد `student_follow_ups` + عمودَي مزامنة قياسيين (`remote_id`, `sync_updated_at`) + `FOREIGN KEY(student_id) ... ON DELETE CASCADE`. **`DATABASE_VERSION` 24 → 25** — نفس نمط migration إضافة جدول جديد اللي استُخدم في spec 016 (`exam_questions`/`exam_submissions` عبر `oldVersion < 23`).
- **إعدادات جديدة** في `app_settings` (key/value): تفعيل/عتبة لكل إشارة (4×2)، مدة التهدئة، يوم/وقت الإشعار الأسبوعي، تفعيل/تعطيل الإشعار — بنفس نمط `SettingsController.paymentGraceDays` (`RxInt`/`RxBool` + `getSetting`/`setSetting`).
- **مزامنة الفريق**: إضافة `TABLE_STUDENT_FOLLOW_UPS` لقائمة `SyncEngine._tables` + primary-key mapping + `_mapRowForRemote` case (يحوّل `student_id` المحلي لـ`student_remote_id` عبر `_localRemoteId` الموجودة) — نفس النمط المستخدَم للحضور/الواجب/المدفوعات بالظبط، صفر آلية جديدة.
- **إشعار أسبوعي**: نفس نمط `NotificationService.scheduleLatePaymentReminder()` (يعيد الحساب من الـDB مباشرة وقت الجدولة، مش من حالة GetX) لكن بـ`_nextInstanceOfWeekdayTime(weekday, time)` + `matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime` (بالظبط زي `scheduleDailyDigestNotifications`) بدل التكرار اليومي.
- **الضغط على الإشعار يفتح الشاشة**: `_onNotificationTap` في `NotificationService` حاليًا `debugPrint` بس (مفيش أي تنقّل من إشعار في التطبيق كله دلوقتي — هتبقى أول حالة). بما إن `GetMaterialApp` (GetX) بتوفّر تنقّل عالمي من غير `navigatorKey`، إضافة `if (response.payload == 'at_risk') Get.toNamed(...)` كافية للحالة "التطبيق شغّال بالفعل". حالة "التطبيق مقفول تمامًا والإشعار هو اللي فتحه" (cold start) محتاجة `getNotificationAppLaunchDetails()` وقت `initialize()` — نفّذها لو الوقت سمح، وإلا توثّق كقيد معروف (الإشعار برضو بيفتح التطبيق عادي، بس مش بيوصّل للشاشة مباشرة في الحالة دي بالذات).
- **الرصد نفسه**: `AtRiskService` (Dart نقي، صفر Flutter) — دالة واحدة `computeAtRiskStudents(...)` بتاخد كل البيانات اللي محمّلة أصلاً (`List<Student>`, `List<Attendance>`, `List<Homework>`, `List<ExamGrade>`, `List<Payment>`, `List<StudentFollowUp>`, `AtRiskSettings`) وترجّع `List<AtRiskStudent>` — نفس فلسفة `certificate_layout.dart` (منطق نقي قابل لإعادة الاستخدام من أي caller: شاشة / كارت / إشعار).
- **Testing**: `flutter analyze` صفر تحذيرات + تحقّق يدوي (quickstart.md) — المنطق قابل لاختبار وحدة (`AtRiskService` نقي، مفيش DB/Flutter جوّاه) لو حابب نضيف `test/at_risk_service_test.dart`.

## Constitution Check

PASS — نفس أنماط موجودة بالفعل بدون اختراع أي آلية جديدة: منطق نقي منفصل عن العرض (زي `certificate_layout.dart`/`leaderboard` queries)، مزامنة فريق بنفس outbox الموجود، جدولة إشعار بنفس نمط `scheduleLatePaymentReminder`/`scheduleDailyDigestNotifications`، إعدادات بنفس نمط `paymentGraceDays`. القيد الوحيد الجديد فعليًا هو تنقّل-من-إشعار (أول استخدام في المشروع) — محدود لحالة واحدة (`payload == 'at_risk'`)، مش رواتر عام.

## Source Changes

```text
lib/config/constants.dart
  + DATABASE_VERSION 24 → 25
  + TABLE_STUDENT_FOLLOW_UPS = 'student_follow_ups'
  + COL_SFU_ID / COL_SFU_STUDENT_ID / COL_SFU_REASON_TYPES / COL_SFU_ACKNOWLEDGED_AT / COL_SFU_NOTE
  + SETTING_ATRISK_*  (تفعيل/عتبة لكل إشارة ×4، مدة التهدئة، يوم/وقت/تفعيل الإشعار الأسبوعي)

lib/models/student_follow_up_model.dart   [جديد]
  class StudentFollowUp { id, studentId, reasonTypes (List<String>), acknowledgedAt, note }
  toMap/fromMap (زي Homework/Payment)، reasonTypes مخزّنة JSON في العمود

lib/models/at_risk_model.dart   [جديد]
  enum RiskSignalType { consecutiveAbsence, missingHomework, gradeDrop, latePayment }
  class RiskSignal { type, reasonText, severityWeight }
  class AtRiskStudent { student, group, signals: List<RiskSignal>, severityScore, isAcknowledged }

lib/services/at_risk_service.dart   [جديد]
  class AtRiskSettings { لكل إشارة: enabled + threshold(s)، cooldownDays }
  List<AtRiskStudent> computeAtRiskStudents({
    required List<Student> students, required List<Group> groups,
    required List<Attendance> attendance, required List<Homework> homework,
    required List<ExamGrade> examGrades, required List<Payment> payments,
    required List<StudentFollowUp> recentFollowUps, required AtRiskSettings settings,
  })
  — كل _checkConsecutiveAbsence/_checkMissingHomework/_checkGradeDrop/_checkLatePayment
    دالة خاصة منفصلة، بترجّع RiskSignal? — نفس بنية exam_grade percentage/PricingHelper.isOverdue
    الموجودة، بدون تكرار منطقهم.
  — استبعاد المؤرشفين + تطبيق التهدئة (مطابقة reasonTypes المؤكَّدة مقابل الأنواع الجديدة المتحقِّقة)

lib/services/database_service.dart
  + CREATE TABLE (onCreate) + migration (oldVersion < 25) — نفس نمط _examQuestionsTableSql/
    _examSubmissionsTableSql (spec 016) لجدول جديد كامل، مش عمود.
  + insertFollowUpAcknowledgement / getFollowUpsSince / deleteFollowUp
  + _queueSync(TABLE_STUDENT_FOLLOW_UPS, id, 'insert'/'delete', ...) بعد كل كتابة (نفس نمط الجداول التانية)

lib/services/sync_engine.dart
  + TABLE_STUDENT_FOLLOW_UPS في _tables + COL_SFU_ID في primary-key map
  + case في _mapRowForRemote: student_id محلي → student_remote_id عبر _localRemoteId الموجودة

lib/controllers/settings_controller.dart
  + Rx لكل إعداد جديد (زي paymentGraceDays) + تحميل/حفظ عبر getSetting/setSetting

lib/controllers/at_risk_controller.dart   [جديد]
  GetX controller: RxList<AtRiskStudent> items, RxInt count (بعد استبعاد المؤجَّلين)،
  فلتر نوع السبب + مجموعة، acknowledge(studentId, note), unacknowledge(studentId),
  refresh() — بيحمّل من الـcontrollers/DB الموجودة (Student/Attendance/Homework/Exam/Payment)
  وينادي AtRiskService.computeAtRiskStudents

lib/views/students/at_risk_students_page.dart   [جديد]
  الشاشة: قائمة كروت (اسم، مجموعة، شرائح أسباب، أزرار اتصال/واتساب/فتح صفحة الطالب/تمّت المتابعة)
  + فلترة (نوع سبب، مجموعة) + تبويب/فلتر "تمّت متابعتهم" + حالة فاضية إيجابية

lib/views/home_page.dart
  + كارت "محتاجين متابعة (N)" (نفس نمط _PaymentProgressCard بصريًا) يفتح at_risk_students_page

lib/views/settings/settings_page.dart
  + قسم "متابعة الطلاب": تفعيل/عتبة لكل إشارة، مدة التهدئة، يوم ووقت الإشعار الأسبوعي وتفعيله

lib/services/notification_service.dart
  + _atRiskNotificationId (مساحة IDs منفصلة زي _latePaymentNotificationId)
  + _keyAtRiskEnabled + isAtRiskEnabled/setAtRiskEnabled
  + scheduleWeeklyAtRiskDigest() — يحسب AtRiskService.computeAtRiskStudents مباشرة من الـDB
    (نفس نمط scheduleLatePaymentReminder)، يجدول بـ_nextInstanceOfWeekdayTime +
    matchDateTimeComponents: dayOfWeekAndTime (نفس نمط scheduleDailyDigestNotifications)،
    ولو count == 0 يلغي أي إشعار مجدوَل قديم (نفس معالجة late-payment)
  + _onNotificationTap: لو response.payload == 'at_risk' → Get.toNamed(at_risk_students_page)
  + استدعاء scheduleWeeklyAtRiskDigest من نفس نقطة استدعاء scheduleLatePaymentReminder
    (بعد أي تغيير حضور/واجب/درجة/دفعة ذي صلة، أو كحد أدنى ضمن دورة sync الدورية الموجودة)
```

**نقطة الدخول الأساسية**: كارت `home_page.dart` (اكتشاف) → `at_risk_students_page.dart` (فعل). الإشعار الأسبوعي طريق دخول تاني لنفس الشاشة.

## Complexity Tracking

> لا انتهاكات — الميزة بتعيد استخدام 4 أنظمة فرعية موجودة (PricingHelper، SyncEngine outbox، NotificationService scheduling، app_settings) بدل ما تخترع بديل لأي واحد فيهم. الإضافة الحقيقية الوحيدة الجديدة معماريًا هي التنقّل من إشعار (مش موجود خالص دلوقتي) — محدودة لحالة واحدة، موثّقة فوق.
