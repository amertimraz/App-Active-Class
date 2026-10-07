# Research: الغياب التلقائي بعد انتهاء الحصة

## R1 — مصدر وقت نهاية الحصة
**Decision**: `AttendanceController.sessionTimeForGroupOnDay(group, day)` (يرجّع "HH:mm - HH:mm" من الجدول أو من ميعاد الحصة التعويضية/الإضافية)، ونحلّل النهاية في دالة صرفة جديدة. لو مفيش "-" أو النهاية غير صالحة → null (مفيش غياب). لو النهاية ≤ البداية → حصة عابرة لمنتصف الليل (النهاية +1 يوم).
**Alternatives**: عمود جديد لنهاية الحصة — مرفوض (schema change بلا داعي).

## R2 — هل الحصة موجودة اليوم؟
**Decision**: `groupHasSessionOnDay(group, day)` (جدول + استثناءات spec 032). ملحوظة: مجموعة بلا جدول يرجّع true هنا، لكن بلا وقت نهاية فتُستثنى تلقائيًا بقاعدة R1.

## R3 — منع التكرار والحذف اليدوي
**Decision**: (أ) فهرس UNIQUE موجود على (student, يوم) فيحمي من التكرار على مستوى DB. (ب) علشان حذف المدرس لسجل غياب تلقائي ما يتعوّضش كل دقيقة: نحفظ مجموعة "حصص معالَجة" (`groupId|yyyy-MM-dd`) محليًا في جدول الإعدادات ونقلّمها لنافذة 3 أيام. (ج) `auto_absent_enabled_at` يمنع الأثر الرجعي قبل التفعيل.
**Alternatives**: عمود في attendance — مرفوض (schema + sync).

## R4 — المسح بعد غياب تلقائي
**Finding**: `AttendanceController.addAttendance` بترفض أي سجل في نفس اليوم ("تم تسجيل حضور مسبقًا")، فبدون تعديل المسح بعد الغياب التلقائي هيترفض.
**Decision**: في `QRController._recordAttendance`، قبل الإضافة: لو للطالب سجل اليوم حالته غائب وملاحظته "غياب تلقائي" → نحدّثه (`updateAttendance`) لحاضر/متأخر بملاحظة "تم عبر QR" ثم نحدّث القائمة. أي سجل آخر يمشي في المسار الحالي بلا تغيير.

## R5 — الجدولة
**Decision**: `Timer.periodic(1 min)` في خدمة جديدة + استدعاء عند `AppLifecycleState.resumed` (المراقب الموجود في main.dart) وعند التشغيل. مفيش Workmanager (تقريب 15 دقيقة كحد أدنى، ومش مناسب لدقة دقيقة).
**Decision**: الخدمة تتأكد إن `SettingsController` و`AttendanceController` مسجّلين وإن المفتاح مفعّل قبل أي شغل؛ وإلا ترجع بصمت.

## R6 — الأثر الجانبي بعد التسجيل
**Decision**: إدراج مباشر عبر `DatabaseService.insertAttendance` (بدون Toast)، وبعدها تحديث قائمة الحضور مرة واحدة، و`pushStudentSummary` لكل طالب متأثر (unawaited، لو البوابة شغّالة)، و`scheduleLatePaymentReminder` مرة واحدة. لا رسائل واتساب.
