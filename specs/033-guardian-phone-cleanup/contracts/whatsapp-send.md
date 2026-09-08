# Contract: إرسال واتساب + عمود `guardian_whatsapp` (US3)

## `lib/utils/whatsapp_launcher.dart` (جديد)

```dart
Future<bool> launchGuardianWhatsapp({
  required BuildContext context,
  String? phone,        // student.guardianPhone
  String? whatsapp,     // student.guardianWhatsapp
  required String message,
  required String dialCode,   // Get.find<SettingsController>().countryDial.value
});
// يرجّع true لو فتح واتساب (أو نسخ رسالة username)، false لو مفيش وجهة.
```

### خوارزمية الأولوية
1. `h = PhoneHelper.parseWhatsappHandle(whatsapp ?? '')`.
2. `h.kind == waLink`:
   - لو الرابط `wa.me/<digits>` بدون `?text=` → أضِف `?text=${Uri.encodeComponent(message)}`.
   - وإلا افتح الرابط كما هو (`/message/`, `/qr/`, رابط فيه نص مسبق).
   - `launchUrl(externalApplication)` → `return true`.
3. `h.kind == phone` → `num = h.value`؛ اذهب للخطوة 5 بـ`num`.
4. رقم من `phone`: `num = PhoneHelper.waMe(phone ?? '', dialCode)`؛ لو غير فارغ اذهب للخطوة 5.
5. `launchUrl('https://wa.me/$num?text=${Uri.encodeComponent(message)}')` → `return true`.
6. `h.kind == username` → `launchUrl('https://wa.me/')` + `Clipboard.setData(ClipboardData(text: message))`
   + `AppToast.info(context, 'اتنسخت الرسالة — الصقها في شات ولي الأمر @${h.value}')` → `return true`.
7. وإلا → `AppToast.error(context, 'مفيش رقم أو واتساب لولي الأمر')` → `return false`.

### نقاط الاستبدال (كل بلوك `Uri.parse('https://wa.me/...')` لولي أمر)
| ملف | ملاحظة |
|---|---|
| `views/attendance/attendance_page.dart` (×2: تقرير فردي + إرسال جماعي) | الجماعي: حلقة تستدعي `launchGuardianWhatsapp` + `_atWaitForResume()` بينهم |
| `views/exams/exam_grades_page.dart` (×3) | |
| `views/exams/online_exam_results_page.dart` | |
| `views/exams/student_exam_history_page.dart` | |
| `views/reports/reports_page.dart` | |
| `views/reports/payments_report_page.dart` | |
| `views/groups/group_details_page.dart` (×2) | |
| `views/students/student_details_page.dart` | |
| `views/students/at_risk_students_page.dart` | |

**خارج النطاق** (تبقى كما هي): روابط دعم/ترخيص (`_kSupportPhone`, `supportPhone`) في
`login_screen`/`plans_page`/`trial_banner`/`settings_page`/`manage_members_screen` —
دي أرقام ثابتة صحيحة، مش أرقام أولياء أمور. `qr_scanner_payment_page.dart:473`
(`wa.me/?text=` بلا رقم — مشاركة عامة) تبقى.

## عمود `students.guardian_whatsapp`

### `lib/config/constants.dart`
```dart
const String COL_STUDENT_GUARDIAN_WHATSAPP = 'guardian_whatsapp';
const int DATABASE_VERSION = 30; // كان 29
```

### `lib/services/database_service.dart`
- `_createTables` جدول `students`: `+ $COL_STUDENT_GUARDIAN_WHATSAPP TEXT,`
- `_onUpgrade`: `if (oldVersion < 30) { try { await db.execute('ALTER TABLE $TABLE_STUDENTS ADD
  COLUMN $COL_STUDENT_GUARDIAN_WHATSAPP TEXT'); } catch (_) {} }`

### `lib/models/student_model.dart`
`String? guardianWhatsapp` — في الحقول، الـconstructor، `toMap` (`COL_...: guardianWhatsapp` أو
`'guardian_whatsapp'`)، `fromMap` (`map['guardian_whatsapp'] as String?`)، `copyWith`.

### `lib/services/sync_engine.dart` (TABLE_STUDENTS فقط)
- `_buildRemoteRow`: `'guardian_whatsapp': payload[COL_STUDENT_GUARDIAN_WHATSAPP],`
- `_toLocalMap`: `COL_STUDENT_GUARDIAN_WHATSAPP: remote['guardian_whatsapp'],`

### `supabase/migration_guardian_whatsapp.sql` (جديد)
```sql
alter table public.students add column if not exists guardian_whatsapp text;
```
يُطبَّق عبر SSH (نمط specs 021/024/025/031/032). `trg_set_updated_at` على `students` موجود.

## واجهة إدخال حقل الواتساب
- في `add_student_sheet` + `edit_student_sheet` تحت `PhoneField`: `CustomTextField` عادي
  (`textDirection: ltr`) بعنوان «واتساب ولي الأمر (رابط أو اسم مستخدم — اختياري)».
- عند `_submit`: لو `parseWhatsappHandle(text).kind == invalid` → `AppToast` تحذير غير معطِّل، ثم
  يُحفظ النص كما هو.
- `_StudentDetailsPage` وبطاقات الطلاب: أيقونة واتساب تستدعي `launchGuardianWhatsapp`.

## عدم انحدار
- طالب بلا `guardian_whatsapp` (كل الطلاب القدامى) → `launchGuardianWhatsapp` يسقط مباشرة لفرع
  الرقم = السلوك القديم بالحرف.
- `parent_portal_service`: يرفع `guardian_phone` عبر `PhoneHelper.waMe` (اتساق fr-016)؛
  `guardian_whatsapp` **لا يُرفع** لبوابة الأهل في هذا الإصدار (خارج النطاق — البوابة تعرض للأهل
  مش تراسلهم).
