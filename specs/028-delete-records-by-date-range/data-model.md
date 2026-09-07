# Data Model: حذف السجلات بمدى تواريخ

لا كيانات قاعدة بيانات جديدة. DB version يبقى **28**. لا أعمدة/جداول. لا تغيير مزامنة. حذف صفوف فقط.

## 1. `DeletableRecordType` (enum جديد — `lib/models/deletable_record_type.dart`)

| العضو | التسمية للمدرّس | الجدول | عمود التاريخ | مُزامَن؟ | توابع عند الحذف |
|---|---|---|---|---|---|
| `attendance` | سجل الحضور | `attendance` | `date` | نعم | — |
| `payments` | الدفعات | `payments` | `date` | نعم | — |
| `examGrades` | درجات الامتحانات | `exam_grades` | تاريخ الامتحان الأب (`exams.date` عبر `exam_id`) | نعم | — |
| `exams` | الامتحانات | `exams` | `date` | نعم | `exam_grades` + `exam_groups` + `exam_questions` + `exam_submissions` المرتبطة |
| `homework` | الواجبات | `homework` | `date` | نعم | — |
| `reportLogs` | سجلّات تقارير واتساب | `report_logs` | `sent_at` | **لا** | — |

- `mainTable` / `dateColumn` / `pkColumn` / `isTeamSynced` / `label` — خصائص على الـenum.
- مصدر واحد للحقيقة تُستخدمه المعاينة والحذف والواجهة.

## 2. مدخلات العملية (غير مخزَّنة — حالة `DeleteRecordsController`)

| الحقل | النوع | الوصف |
|---|---|---|
| `fromDate` | `Rxn<DateTime>` | بداية المدى (يُطبَّع لـ00:00:00) |
| `toDate` | `Rxn<DateTime>` | نهاية المدى (تُطبَّع لـ+1 يوم 00:00:00 حصريًا داخليًا) |
| `selectedTypes` | `RxSet<DeletableRecordType>` | نوع واحد على الأقل للتفعيل |
| `preview` | `Rxn<Map<DeletableRecordType,int>>` | نتيجة آخر معاينة؛ `null` = لم تُحسب بعد |
| `isRunning` | `RxBool` | أثناء النسخة الاحتياطية/الحذف |

**مشتقّات**:
- `rangeValid` = `fromDate != null && toDate != null && !fromDate.isAfter(toDate)`
- `previewTotal` = مجموع قيم `preview`
- `needsTypeConfirm` = `previewTotal > 100` (ثابت `kBulkDeleteThreshold`)
- `canPreview` = `rangeValid && selectedTypes.isNotEmpty`
- `canDelete` = `preview != null && previewTotal > 0 && !isRunning`

## 3. ثوابت

| الثابت | القيمة | المكان |
|---|---|---|
| `kBulkDeleteThreshold` | `100` | `deletable_record_type.dart` أو الشاشة |
| `kDeleteConfirmWord` | `'حذف'` | نفس المكان |

## 4. لا تأثير على المخطط

- `deleteAllData()` القائمة تبقى كما هي (زر منفصل).
- لا صف يُضاف لأي جدول عدا `sync_outbox` (صفوف `delete` مؤقتة، تُفرَّغ بالمزامنة) — وده فقط في وضع الفريق.
