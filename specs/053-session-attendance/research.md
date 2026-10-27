# Research: الحضور بالحصة

## 1. الحصة تتشتق ولا تتخزّن

- **Decision**: الحصة = `(group, date)`؛ حالتها (عادية/ملغاة/تعويضية/إضافية) من `AttendanceController.groupsForDayWithOverrides` + `sessionOverrideFor` + `sessionTimeForGroupOnDay` الموجودين.
- **Rationale**: الدوال دي override-aware بالفعل (spec 032) ومستخدمة في تبويب الحضور؛ إعادة استخدامها بتضمن نفس السلوك في الشاشتين.
- **Alternatives**: جدول `sessions` جديد → رُفض (schema + مزامنة + migration بلا داعي).

## 2. حضور الطالب في الحصة

- **Finding**: فهرس فريد `(student_id, day)` على `attendance` (`database_service.dart`) → سجل واحد للطالب في اليوم. `setAttendanceStatus(studentId, day, status)` بيعمل insert/update/delete ويحدّث الـUI محليًا.
- **Decision**: "حصتين لنفس المجموعة في نفس اليوم" بيشاركوا سجل اليوم (موثّق في Assumptions). مفيش تغيير.
- **Rationale**: تغيير ده يحتاج schema + مزامنة، وخارج نطاق الطلب.

## 3. جدول الحصص حاليًا بالأسبوع فقط

- **Finding**: `schedule_page.dart` بيحلّل `group.schedule` (نص "السبت 09:00-10:30, ...") لـ`_ClassSlot` بـ`dayIndex` (السبت=0) بدون تاريخ، ولا بيقرا `session_overrides`، والكارت بيفتح تفاصيل المجموعة.
- **Decision**: إضافة `_weekOffset` (أسبوع بالإزاحة) فوق `_selectedDay`؛ التاريخ = `weekStart(offset) + dayIndex`. حصص اليوم المختار = slots اليوم الأسبوعي مفلترة بـ`groupHasSessionOnDay` (بتستبعد الملغاة وتضيف التعويضية/الإضافية) + عرض الملغاة بعلامة. زرار "اليوم" ورؤوس اليوم تعرض التاريخ. اختيار تاريخ حر (DatePicker) يضبط `_weekOffset` و`_selectedDay`.
- **Alternatives**: استبدال جدول الحصص بالكامل بتقويم → رُفض (تغيير كبير وبعيد عن الطلب).

## 4. تبويب الحضور فيه تنقّل بالأيام بالفعل

- **Finding**: `_DayNavigator` في `attendance_page.dart` فيه يوم قبل/بعد + DatePicker، وبيعرض `_GroupSummaryCard` لكل مجموعة (حاضر/متأخر/إجمالي) ويفتح `showAttendanceSheet`.
- **Decision**: ما نعيدش بناء التنقّل. نضيف في `_GroupSummaryCard` زرار "تفاصيل الحصة" يفتح الصفحة الجديدة بنفس `selectedDay`. `showAttendanceSheet` يفضل زي ما هو (فيه واجب/تسميع/تفاعل/تقرير ولي الأمر).
- **Rationale**: بيحقق FR-002 بأقل تغيير، وما بيكسرش سير العمل الحالي.

## 5. الشاشة الجديدة مقابل ورقة التسجيل الحالية

- **Decision**: الشاشة الجديدة تركّز على **المراجعة والغياب**: ملخص + تبويبات + بحث + صف طالب مضغوط بثلاث أزرار حالة (`setAttendanceStatus`) + "تحضير غير المسجَّلين" (`markGroupAllPresent` على IDs غير المسجَّلين فقط) + إرسال واتساب. الواجب/التسميع/التفاعل يفضلوا في الورقة الحالية، وفيه زرار "فتح ورقة التسجيل الكاملة" يستدعي `showAttendanceSheet`.
- **Rationale**: تقليل المخاطرة وعدم تكرار منطق الواجب/التسميع؛ وده يحقق SC-001 لأن الغايبين في تبويب لوحدهم.

## 6. من يظهر في roster الحصة

- **Decision** (دالة صرفة): طلاب المجموعة غير المؤرشفين، ما عدا من `attendanceStart` بعد التاريخ؛ والمؤرشف يظهر لو عنده سجل حضور في اليوم ده (عشان الحصص القديمة تفضل صحيحة).
- **Rationale**: بيطابق FR-009 ويحافظ على صحة التاريخ.

## 7. رسالة الغياب

- **Finding**: `_AbsentTodayTabState._buildMessage` تبني الرسالة من `DateTime.now()` (يعني تاريخ النهاردة دايمًا).
- **Decision**: استخراجها لدالة صرفة `buildAbsenceMessage(student, groupName, date, teacherName, spec)` و`buildLateMessage` في `lib/utils/absence_message.dart`، يستخدمها "غياب اليوم" (بتاريخ النهاردة، نفس الناتج حرفيًا) والصفحة الجديدة (بتاريخ الحصة). اختبار تراجعي بيثبّت نفس النص.

## 8. إرسال واتساب بالتتابع

- **Decision**: نفس نمط `_sendToSelected` (تأكيد/تخطي/إلغاء الكل لكل ولي أمر + عدّ المتخطّين بلا رقم) عبر `launchGuardianWhatsapp`؛ بدون تغيير في `whatsapp_launcher`.

## 9. الأداء

- **Decision**: بناء `Map<studentId, Attendance>` لليوم مرة لكل build من `controller.attendance` (O(N)) بدل بحث لكل طالب؛ `ListView.builder` للقايمة؛ الملخص من نفس الـMap. تحديث السجل الواحد محليًا موجود في `setAttendanceStatus`.

## 10. الصلاحيات (وضع الفريق)

- **Finding**: `TeamModeService` فيه `canSeeAcademics/canSeeFinancials/canDelete…` ومفيش قيد على تسجيل الحضور نفسه للمساعد.
- **Decision**: الشاشة لا تعرض أي بيانات مالية. إرسال الواتساب متاح زي "غياب اليوم" الحالي (بدون بوابة جديدة). أي زرار حذف/تعديل تاريخ غير موجود في الشاشة.
