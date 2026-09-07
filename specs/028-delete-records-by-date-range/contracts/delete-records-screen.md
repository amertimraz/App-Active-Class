# Contract: `DeleteRecordsPage` + `DeleteRecordsController`

## `DeleteRecordsController` (`lib/controllers/delete_records_controller.dart`)

`GetxController` — حالة الشاشة (انظر data-model §2). دوال:

```dart
void setFrom(DateTime d);          // يمسح preview
void setTo(DateTime d);            // يمسح preview
void toggleType(DeletableRecordType t);  // يمسح preview
Future<void> runPreview();         // canPreview → DatabaseService.countDeletableRecordsInRange
Future<DeleteOutcome> runDelete(); // انظر التدفّق تحت
```

`runDelete()`:
1. حارس: `canDelete == true`.
2. `isRunning = true`.
3. `final b = await BackupService().createBackup();`
   - لو `!b.success` → `isRunning=false` → رجّع `DeleteOutcome.backupFailed(b.error)`.
4. `final deleted = await DatabaseService().deleteRecordsInRange(from:.., to:.., types: selectedTypes);`
   - عند استثناء → `isRunning=false` → `DeleteOutcome.error(e)`.
5. تحديث الكونترولرز المسجّلة: `AttendanceController.loadAttendance()`, `PaymentController.loadPayments()`, `ExamController.load...()`, `DashboardController.loadDashboardData()` (كلها بحارس `Get.isRegistered`).
6. `preview = null; selectedTypes.clear(); isRunning = false;`
7. رجّع `DeleteOutcome.success(deleted)`.

`DeleteOutcome` = sealed/enum بسيط: `success(Map<DeletableRecordType,int>)` / `backupFailed(String?)` / `error(Object)`.

## `DeleteRecordsPage` (`lib/views/settings/delete_records_page.dart`)

- **رأس تحذيري ثابت**: أيقونة + "الحذف نهائي — لا يمكن التراجع إلا باستعادة نسخة احتياطية كاملة."
- **اختيار المدى**: صفّان "من التاريخ" / "إلى التاريخ" → `showDatePicker` (بالعربي، `locale`). عرض التاريخ المختار أو "اختر".
- **الأنواع**: قائمة `CheckboxListTile` لكل `DeletableRecordType` بتسميته. (لا طلاب/مجموعات.)
- **زر "معاينة"**: `onPressed: canPreview ? controller.runPreview : null`.
- **بطاقة المعاينة** (`Obx`): لو `preview != null` → سطر لكل نوع مختار + عدده، وسطر إجمالي بارز. لو `previewTotal == 0` → "لا سجلّات مطابقة".
- **تحذير وضع الفريق**: لو `DatabaseService.teamModeEnabled && previewTotal > 500` → نص "الحذف هيتزامن مع بقية الفريق وقد ياخد وقت في المزامنة."
- **زر "حذف نهائيًا"** (لون أحمر): `onPressed: canDelete ? _confirmAndDelete : null`.
- `_confirmAndDelete()`:
  - `showDialog` — العنوان "تأكيد الحذف"، المحتوى ملخّص الأعداد + المدى.
  - لو `controller.needsTypeConfirm` → `TextField` + نص "اكتب «حذف» للتأكيد"؛ زر "حذف" معطّل حتى `text.trim() == kDeleteConfirmWord`.
  - غير كده → زر "حذف" مفعّل مباشرةً.
  - عند التأكيد: أغلق الحوار، اعرض `ProgressDialog` أثناء `isRunning`، ثم عالج `DeleteOutcome`:
    - `success` → `ToastHelper.success('اتحذف: ' + ملخّص الأعداد الفعلية)`، والشاشة ترجع لحالة فارغة.
    - `backupFailed` → `ToastHelper.error('اتلغى الحذف: فشل النسخة الاحتياطية' + (سبب))`.
    - `error` → `ToastHelper.error('حصل خطأ أثناء الحذف — لم يُحذف شيء')`.

## `settings_page.dart` — سطر الدخول

في قسم البيانات/النسخ الاحتياطي، **منفصل بصريًا** عن "حذف كل البيانات":
```
_buildActionTile (أو ListTile):
  الأيقونة: Icons.auto_delete_outlined
  اللون   : Color(0xFFF59E0B)  (تحذيري، مش أحمر صريح زي "حذف الكل")
  العنوان : "حذف سجلّات بمدى تواريخ"
  الوصف   : "احذف حضور/دفعات/امتحانات فترة معيّنة — مع نسخة احتياطية إجبارية"
  onTap   : Get.to(() => const DeleteRecordsPage())
```

## ثوابت

- لا يظهر زر "حذف" إلا بعد معاينة بإجمالي > 0.
- نسخة احتياطية دايمًا قبل الحذف؛ فشلها = لا حذف إطلاقًا.
- الطلاب/المجموعات لا يظهران في قائمة الأنواع تحت أي حال.
