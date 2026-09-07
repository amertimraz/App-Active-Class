# Research: حذف السجلات بمدى تواريخ

## قرار 1 — أعمدة التاريخ لكل نوع

| النوع | الجدول | عمود التاريخ | ملاحظة |
|---|---|---|---|
| الحضور | `attendance` | `date` (`COL_ATTENDANCE_DATE`) | ISO string |
| الدفعات | `payments` | `date` (`COL_PAYMENT_DATE`) | ISO string |
| الواجبات | `homework` | `date` (`COL_HOMEWORK_DATE`) | ISO string |
| الامتحانات | `exams` | `date` (`COL_EXAM_DATE`) | ISO string |
| درجات الامتحانات | `exam_grades` | **تاريخ الامتحان الأب** (join على `exams.date` عبر `exam_id`) | `exam_grades` مالوش تاريخ ذاتي معتمد (`created_at` قد يكون null لصفوف قديمة). المدرّس يفكّر بـ"درجات امتحانات الفترة دي". |
| سجلّات تقارير واتساب | `report_logs` | `sent_at` (`COL_REPORT_SENT_AT`) | ISO string. **غير مُزامَن.** |

**القرار**: مقارنة `col >= <from 00:00:00> AND col < <to + 1 يوم 00:00:00>` (شامل يوم البداية والنهاية بالكامل، مستقل عن جزء الوقت في الصف).

**تحديث افتراض السبيك**: درجات الامتحانات تُفلتَر بتاريخ الامتحان الأب لا "تاريخ إدخال الدرجة".

---

## قرار 2 — الحذف عبر `DatabaseService` بدالتين

**القرار**:
- `Future<Map<DeletableRecordType,int>> countDeletableRecordsInRange({DateTime from, DateTime to, Set<DeletableRecordType> types})` — `SELECT COUNT(*)` لكل نوع مختار.
- `Future<Map<DeletableRecordType,int>> deleteRecordsInRange({DateTime from, DateTime to, Set<DeletableRecordType> types})` — داخل `db.transaction`: لكل نوع مختار، اقرأ صفوفه المطابقة (`id` + `remote_id`) ثم `DELETE`. بعد الـcommit: `_queueDelete(table, id, remoteId)` لكل صف من نوع **مُزامَن**. يرجع أعداد المحذوف فعليًا.

**السبب**: نفس نمط `deleteAttendance`/`deleteExam` القائم (query remote_id → delete → queue). `_queueDelete` يجب أن يُستدعى بـ`db` handle بعد الـtransaction (مش داخلها).

---

## قرار 3 — الامتحانات: توابع الحذف

**القرار**: عند اختيار "الامتحانات"، لكل `exam.id` ضمن المدى نكرّر منطق `deleteExam` القائم: حذف `exam_grades` + `exam_groups` + `exam_questions` + `exam_submissions` المرتبطة، ثم `exams`، وقائمة انتظار حذف لكلها. يتم كله في نفس الـtransaction الكبيرة.

"درجات الامتحانات" كنوع منفصل: `DELETE FROM exam_grades WHERE exam_id IN (امتحانات ضمن المدى)` فقط — الامتحانات تبقى.

**تعارض**: لو اختير "الامتحانات" **و** "درجات الامتحانات" معًا لنفس المدى — الامتحانات تجرّ درجاتها فتُحذف مرة (idempotent). لا مشكلة.

**السبب**: يطابق سلوك حذف الامتحان اليدوي القائم (`deleteExam` سطر ~2041) — المدرّس يتوقّع نفس الشيء.

---

## قرار 4 — النسخة الاحتياطية الإجبارية

**القرار**: قبل أي حذف: `final r = await BackupService().createBackup();` — لو `!r.success` → إلغاء كامل + رسالة "اتلغى الحذف: فشل إنشاء نسخة احتياطية (${r.error})". لو نجح → كمّل الحذف. (لا `saveToDownloads` — النسخة الداخلية تكفي كشبكة أمان، والخارجية بطيئة على MIUI.)

**السبب**: `createBackup()` نسخ ملف قاعدة سريع (WAL checkpoint + copy). يحقّق FR-006 / SC-003.

---

## قرار 5 — عتبة الكمية الكبيرة + كلمة التأكيد

**القرار**: ثابت `_bulkDeleteThreshold = 100`. لو `إجمالي المعاينة > 100` → حوار التأكيد فيه `TextField` وزر "حذف" معطّل حتى يُكتب **"حذف"** بالحرف (بعد `trim`). غير كده → زر تأكيد عادي.

**السبب**: يوازن بين الاحتكاك والأمان. القيمة قابلة للتعديل لاحقًا.

---

## قرار 6 — وضع الفريق: صفر كود مزامنة جديد

**القرار**: `_queueDelete` القائمة تكفي:
- في وضع الفريق (`teamModeEnabled`)، كل صف محذوف من نوع مُزامَن → صف `delete` في `sync_outbox` مع `remote_id` → `SyncEngine._pushOne` يدفعه لـSupabase → باقي أجهزة الفريق تسحب الحذف. **يعمل من جهاز المساعد كما المدرّس** (نفس آلية حذف صف واحد اليوم).
- `report_logs` **غير مُزامَن** — `_pkCol('report_logs')` يرمي `ArgumentError`. فلا نستدعي `_queueDelete` له إطلاقًا؛ حذف محلي مباشر (FR-014).
- في الوضع الفردي `_queueSync` يرجع فورًا (`if (!teamModeEnabled) return`) — صفر تكلفة.

**السبب**: الميزة "تُزامَن في الاتجاهين" مطلب صريح — والآلية موجودة بالفعل لحذف الصف الواحد؛ الحذف الجماعي = تكرارها في حلقة.

**خطر**: `sync_outbox` قد يمتلئ بآلاف صفوف الحذف دفعة واحدة — `SyncEngine` يفرّغها على دفعات (drain) بالفعل. مقبول؛ نضيف ملاحظة تحذير في الشاشة لو المجموع كبير جدًا ووضع الفريق مفعّل.

---

## قرار 7 — الشاشة: مكانها وتدفّقها

**القرار**: `DeleteRecordsPage` مستقلة، سطر دخول في `settings_page.dart` ضمن قسم "البيانات/النسخ الاحتياطي" — **بعيد بصريًا** عن "حذف كل البيانات" القائم (لون تحذيري، أيقونة مختلفة). التدفّق:
1. اختيار "من"/"إلى" (`showDatePicker`) + checkboxes الأنواع.
2. زر "معاينة" (مفعّل لو مدى صالح + نوع واحد على الأقل) → استدعاء `countDeletableRecordsInRange` → عرض بطاقة أعداد + إجمالي.
3. زر "حذف" (مفعّل لو الإجمالي > 0) → حوار تأكيد (مع/بدون كتابة حسب العتبة) → عند التأكيد: نسخة احتياطية → `deleteRecordsInRange` → رسالة نجاح بالأعداد الفعلية + تحديث الكونترولرز المفتوحة (`AttendanceController`/`PaymentController`/`ExamController`/`DashboardController` `.load...()` لو مسجّلة).
4. نص ثابت أعلى الشاشة: "الحذف لا رجعة فيه إلا باستعادة نسخة احتياطية كاملة."

**السبب**: يحقّق FR-001/004/005/007/012/016. GetxController يحمل الحالة (المدى، الأنواع، المعاينة، حالة التنفيذ).

---

## ملخّص الحسم

| # | الموضوع | القرار |
|---|---|---|
| 1 | أعمدة التاريخ | `date` للأربعة، `sent_at` للتقارير، تاريخ الامتحان الأب للدرجات |
| 2 | الحذف | دالتان في `DatabaseService`: count + delete range، transaction + queue بعدها |
| 3 | الامتحانات | تكرار منطق `deleteExam` لكل امتحان في المدى؛ الدرجات المنفصلة = `exam_id IN (...)` |
| 4 | النسخة الاحتياطية | `BackupService().createBackup()` إجباري، فشله → إلغاء |
| 5 | التأكيد | عتبة 100، كتابة كلمة "حذف" فوقها |
| 6 | الفريق | `_queueDelete` القائمة، صفر كود مزامنة جديد؛ `report_logs` محلي فقط |
| 7 | الشاشة | `DeleteRecordsPage` + `DeleteRecordsController`، دخول من الإعدادات |
