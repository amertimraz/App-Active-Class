---
description: "Task list for feature 033 — تنظيف وتوحيد رقم هاتف ولي الأمر + واتساب"
---

# Tasks: تنظيف وتوحيد رقم هاتف ولي الأمر + دعم اسم مستخدم/رابط واتساب

**Input**: Design documents from `/specs/033-guardian-phone-cleanup/`

**Prerequisites**: plan.md ✅، spec.md ✅، research.md ✅، data-model.md ✅، contracts/ ✅، quickstart.md ✅

**Tests**: مطلوبة لـ`PhoneHelper` النقي فقط (جدول الحالات في العقد). واجهة الإدخال والإرسال تحقّق يدوي (quickstart).

**Organization**: US1 (لصق نظيف) + US2 (معاينة) P1 ويتشاركان `PhoneHelper` + `PhoneField`. US4 (توحيد النسخ المكرّرة) P3 لكنه يتم مع US1 عمليًا. US3 (حقل واتساب + عمود) P2 قابل للفصل بالكامل.

## Format: `[ID] [P?] [Story] Description`

## Path Conventions

تطبيق Flutter مفرد + خادم Supabase. المسارات من جذر المستودع.

---

## Phase 1: Setup

- [ ] T001 [P] أنشئ `lib/utils/phone_helper.dart` (هيكل فارغ: `class PhoneHelper` + `enum WhatsappHandleKind` + `class WhatsappHandle`) وفق [contracts/phone-helper.md](./contracts/phone-helper.md).

---

## Phase 2: Foundational — `PhoneHelper` + اختباره (يَحجُب كل القصص)

- [ ] T002 [US1] نفّذ `PhoneHelper.toLatinDigits` + `cleanForStorage` في [lib/utils/phone_helper.dart](../../lib/utils/phone_helper.dart) وفق [contracts/phone-helper.md](./contracts/phone-helper.md): تحويل U+0660–669 / U+06F0–6F9 → لاتيني؛ إزالة كل ما ليس `[0-9+]` (يشمل U+200B–200F، U+202A–202E، U+2066–2069، U+00A0، U+FEFF)؛ `+` أول الحرف فقط؛ `+2`+`0…` → `0…`؛ `00…` → `+…`.
- [ ] T003 [US1] نفّذ `PhoneHelper.waMe(raw, dialCode)` + `isLikelyValid` + `displayIntl` وفق العقد (waMe = منطق `normalizeWhatsappPhone` الحالي بعد `cleanForStorage`؛ displayIntl يبدأ بـLRM `‎`؛ isLikelyValid: الجزء الوطني 7..12).
- [ ] T004 [US3] نفّذ `PhoneHelper.parseWhatsappHandle(raw)` وفق جدول العقد (waLink / phone / username / invalid / empty).
- [ ] T005 [P] [US1] أنشئ [test/phone_helper_test.dart](../../test/phone_helper_test.dart): جدول data-model §1 كامل + `toLatinDigits` (عربي/فارسي/مختلط) + علامات اتجاه + ثبات `waMe` المزدوج + `displayIntl` (مصري 10، فارغ، LRM) + `parseWhatsappHandle` (8 حالات).
- [ ] T006 [US4] حوّل [lib/utils/phone_format.dart](../../lib/utils/phone_format.dart): `normalizeWhatsappPhone(input, dial) => PhoneHelper.waMe(input, dial)` (غلاف رفيع، احتفظ بالتوقيع).

**Checkpoint**: `flutter test test/phone_helper_test.dart` أخضر.

---

## Phase 3: User Story 1 — لصق رقم نظيف (Priority: P1)

**Goal**: لصق رقم ملوّث (مسافات/أرقام عربية/علامات اتجاه/`00`/`+`) → حقل نظيف LTR غير معكوس، يُحفَظ نظيفًا، والإرسال يفتح على الرقم الصحيح من كل الشاشات.

**Independent Test**: quickstart سيناريوهات 1 + 2 + 3 + 5 + 6.

- [ ] T007 [US1] في [lib/widgets/custom_widgets.dart](../../lib/widgets/custom_widgets.dart) `CustomTextField`: أضف بارامترات اختيارية `TextDirection? textDirection` + `TextAlign textAlign = TextAlign.start` + `List<TextInputFormatter>? inputFormatters`، ومرّرها لـ`TextFormField`. صفر تغيير سلوكي لأي مستدعٍ قائم. استورد `package:flutter/services.dart`.
- [ ] T008 [US1] أنشئ [lib/widgets/phone_field.dart](../../lib/widgets/phone_field.dart): `PhoneSanitizerFormatter extends TextInputFormatter` (`formatEditUpdate` → `PhoneHelper.cleanForStorage` + selection في النهاية) + `PhoneField({controller, dialCode, onContactPick})` وفق [contracts/phone-input-ui.md](./contracts/phone-input-ui.md) — `CustomTextField` LTR + محاذاة يسار + الـformatter + زر جهات الاتصال + `ValueListenableBuilder` للمعاينة/التحذير.
- [ ] T009 [US1] في [lib/widgets/add_student_sheet.dart](../../lib/widgets/add_student_sheet.dart): استبدل `Row(CustomTextField + IconButton جهات الاتصال)` لحقل الرقم بـ`PhoneField(controller: _phoneCtrl, dialCode: <SettingsController.countryDial.value>, onContactPick: () async { ... ContactPickerService.pickPhoneNumber ... })`. `_submit` يخزّن `_phoneCtrl.text.trim()` كما هو (بقى نظيفًا).
- [ ] T010 [US1] في [lib/widgets/edit_student_sheet.dart](../../lib/widgets/edit_student_sheet.dart): نفس الاستبدال لحقل `_phoneCtrl`.
- [ ] T011 [P] [US1] في [lib/services/contact_picker_service.dart](../../lib/services/contact_picker_service.dart): `_normalize` → `PhoneHelper.cleanForStorage` (يزيل النسخة الرابعة من المنطق).

**Checkpoint**: لصق أي صيغة ملوّثة → حقل نظيف LTR؛ الحفظ يخزّن نظيفًا.

---

## Phase 4: User Story 2 — معاينة الرقم اللي هيتبعت (Priority: P1)

**Goal**: تحت حقل الرقم، معاينة حيّة «هيتبعت على: ‎+20 …» + تحذير غير معطِّل للرقم الناقص.

**Independent Test**: quickstart سيناريوهات 1 + 4.

- [ ] T012 [US2] في [lib/widgets/phone_field.dart](../../lib/widgets/phone_field.dart): أكمل جزء `ValueListenableBuilder` — فارغ → `SizedBox.shrink()`؛ وإلا سطر «هيتبعت على: `${PhoneHelper.displayIntl(text, dialCode)}`» (رمادي صغير) + لو `!PhoneHelper.isLikelyValid(text, dialCode)` سطر «الرقم يبدو غير مكتمل» (برتقالي صغير). التحذير **لا يمنع** الحفظ (FR-009).
- [ ] T013 [US2] تحقّق أن رمز الدولة يُقرأ من `SettingsController.countryDial` وأن تغييره ينعكس على المعاينة (تمرير `dialCode` من الشيت الذي يقرأ `.value` داخل `Obx`/`build`).

**Checkpoint**: المعاينة والتحذير يعملان ويتبعان رمز الدولة.

---

## Phase 5: User Story 4 — توحيد نقاط الإرسال (Priority: P3)

**Goal**: نقطة تطبيع واحدة يستدعيها كل مسار واتساب لولي أمر.

**Independent Test**: quickstart سيناريو 5 + مراجعة كود (صفر نسخ محلية للـnormalizer).

- [ ] T014 [US4] أنشئ [lib/utils/whatsapp_launcher.dart](../../lib/utils/whatsapp_launcher.dart): `Future<bool> launchGuardianWhatsapp({context, phone, whatsapp, message, dialCode})` وفق [contracts/whatsapp-send.md](./contracts/whatsapp-send.md) (أولوية: رابط `wa.me` → رقم `PhoneHelper.waMe` → username + `Clipboard` + `AppToast` → خطأ). استورد `url_launcher` + `flutter/services` + `app_toast`.
- [ ] T015 [US4] استبدل بلوكات `Uri.parse('https://wa.me/<رقم ولي أمر>...')` بـ`launchGuardianWhatsapp(...)` في: [attendance_page.dart](../../lib/views/attendance/attendance_page.dart) (×2 — فردي + جماعي مع `_atWaitForResume` بين كل إرسال)، [exam_grades_page.dart](../../lib/views/exams/exam_grades_page.dart) (×3 + احذف `_normalizePhone` المحلي سطر ~1007)، [online_exam_results_page.dart](../../lib/views/exams/online_exam_results_page.dart)، [student_exam_history_page.dart](../../lib/views/exams/student_exam_history_page.dart).
- [ ] T016 [US4] نفس الاستبدال + حذف الـnormalizer المحلي في: [reports_page.dart](../../lib/views/reports/reports_page.dart) (احذف `_normalizePhone` سطر ~17)، [payments_report_page.dart](../../lib/views/reports/payments_report_page.dart)، [group_details_page.dart](../../lib/views/groups/group_details_page.dart) (×2)، [student_details_page.dart](../../lib/views/students/student_details_page.dart)، [at_risk_students_page.dart](../../lib/views/students/at_risk_students_page.dart).
- [ ] T017 [US4] في [lib/services/parent_portal_service.dart](../../lib/services/parent_portal_service.dart): الرقم المرفوع للسحابة يمرّ عبر `PhoneHelper.waMe(guardianPhone, dialCode)` (FR-016). **لا** ترفع `guardian_whatsapp`.
- [ ] T018 [US4] `grep -rn "wa.me/\$" lib/` — تأكّد أن الباقي (روابط الدعم/الترخيص الثابتة + `qr_scanner_payment_page.dart:473` مشاركة عامة) بلا تغيير مقصود.

**Checkpoint**: نقطة `PhoneHelper` واحدة؛ كل مسارات ولي الأمر عبر `whatsapp_launcher`.

---

## Phase 6: User Story 3 — حقل واتساب (رابط/username) + عمود مُزامَن (Priority: P2)

**Goal**: حفظ رابط `wa.me`/username لولي أمر بلا رقم، والإرسال يتعامل معهم بالأولوية الصحيحة.

**Independent Test**: quickstart سيناريوهات 7 + 8 + 9 + 10 + 11.

- [ ] T019 [US3] في [lib/config/constants.dart](../../lib/config/constants.dart): `const String COL_STUDENT_GUARDIAN_WHATSAPP = 'guardian_whatsapp';` + `DATABASE_VERSION` من 29 → **30**.
- [ ] T020 [US3] في [lib/models/student_model.dart](../../lib/models/student_model.dart): `final String? guardianWhatsapp;` في الحقول + constructor + `toMap` (`'guardian_whatsapp'`) + `fromMap` (`map['guardian_whatsapp'] as String?`) + `copyWith`.
- [ ] T021 [US3] في [lib/services/database_service.dart](../../lib/services/database_service.dart): عمود `$COL_STUDENT_GUARDIAN_WHATSAPP TEXT` في جدول `students` بـ`_createTables` + `if (oldVersion < 30) { try { await db.execute('ALTER TABLE $TABLE_STUDENTS ADD COLUMN $COL_STUDENT_GUARDIAN_WHATSAPP TEXT'); } catch (_) {} }`.
- [ ] T022 [US3] في [lib/services/sync_engine.dart](../../lib/services/sync_engine.dart) (TABLE_STUDENTS): `'guardian_whatsapp': payload[COL_STUDENT_GUARDIAN_WHATSAPP]` في `_buildRemoteRow` + `COL_STUDENT_GUARDIAN_WHATSAPP: remote['guardian_whatsapp']` في `_toLocalMap`.
- [ ] T023 [P] [US3] أنشئ [supabase/migration_guardian_whatsapp.sql](../../supabase/migration_guardian_whatsapp.sql): `alter table public.students add column if not exists guardian_whatsapp text;`
- [ ] T024 [US3] طبّق الـmigration عبر SSH: `ssh -i ~/.ssh/ovh_key root@active-class.online "docker exec -i active-class-auth-db-1 psql -U postgres -d postgres -v ON_ERROR_STOP=1" < supabase/migration_guardian_whatsapp.sql`. تحقّق: `\d public.students` فيه `guardian_whatsapp`.
- [ ] T025 [US3] في [lib/widgets/add_student_sheet.dart](../../lib/widgets/add_student_sheet.dart) + [lib/widgets/edit_student_sheet.dart](../../lib/widgets/edit_student_sheet.dart): حقل `_whatsappCtrl` تحت `PhoneField` — `CustomTextField(textDirection: ltr, label: 'واتساب ولي الأمر (رابط أو اسم مستخدم — اختياري)')`. عند `_submit`: `parseWhatsappHandle(text).kind == invalid` → `AppToast` تحذير غير معطِّل ثم يُحفظ. مرّر `guardianWhatsapp` للـ`Student`.
- [ ] T026 [US3] في [lib/utils/whatsapp_launcher.dart](../../lib/utils/whatsapp_launcher.dart) + كل مستدعياته (T015/T016): مرّر `whatsapp: student.guardianWhatsapp` بجانب `phone: student.guardianPhone`.
- [ ] T027 [US3] في [lib/views/students/student_details_page.dart](../../lib/views/students/student_details_page.dart): أيقونة/سطر واتساب يستدعي `launchGuardianWhatsapp` (بالفعل عبر T016 — تأكّد أنه يمرّر `whatsapp`).

**Checkpoint**: طالب بلا رقم + رابط `wa.me` → الزر يفتح الرابط؛ username → فتح واتساب + نسخ الرسالة.

---

## Phase 7: Polish & Cross-Cutting

- [ ] T028 [P] `flutter test` كاملًا — كل الاختبارات خضراء + الجديدة.
- [ ] T029 [P] `flutter analyze` — صفر مشاكل جديدة فوق baseline (34).
- [ ] T030 [P] حدّث `HANDOFF.md` + `memory/spec-033-guardian-phone-cleanup.md` (من "planned" إلى "IMPLEMENTED — device test pending"): `PhoneHelper`، `PhoneField`، `whatsapp_launcher`، عمود `guardian_whatsapp` (DB v30، migration مطبّق عبر SSH)، صفر ترحيل بيانات.
- [ ] T031 تحقّق جهازي — quickstart كامل (1–11): لصق من سجل مكالمات حقيقي بلغة عربية، إرسال من كل الشاشات، رابط/username، جهازين للمزامنة، عدم الانحدار.

---

## Dependencies & Execution Order

- **Phase 1** → **Phase 2** (يَحجُب الكل). داخل Phase 2: T002→T003 تسلسلي (نفس الملف)؛ T004 بعد T002؛ T005 موازٍ (ملف اختبار)؛ T006 بعد T003.
- **Phase 3 (US1)**: بعد Phase 2. T007→T008 (T008 يعتمد على بارامترات T007)؛ T009/T010 بعد T008؛ T011 موازٍ.
- **Phase 4 (US2)**: T012 يكمّل نفس ملف T008 → بعد T008. T013 بعد T009/T010.
- **Phase 5 (US4)**: T014 بعد Phase 2؛ T015/T016 بعد T014 (ملفات مختلفة لكن كثيرة — يفضّل تسلسلي للمراجعة)؛ T017/T018 بعد.
- **Phase 6 (US3)**: بعد Phase 2 (لـ`parseWhatsappHandle`). T019→T020→T021→T022 تسلسلي منطقيًا؛ T023 موازٍ؛ T024 بعد T023 (شبكة)؛ T025 بعد T020 + T008؛ T026 بعد T014 + T020؛ T027 بعد T016.
- **Phase 7**: بعد الكل.

### Parallel Opportunities
- T001 + T005 (هيكل + ملف اختبار).
- T011 موازٍ لباقي Phase 3.
- T023 موازٍ لباقي Phase 6.
- T028 + T029 + T030.

---

## Implementation Strategy

### MVP (Phase 1 + 2 + 3 + 4)

`PhoneHelper` + `PhoneField` (LTR + formatter + معاينة) = يحلّ الألم اليومي بالكامل (لصق + إرسال صحيح). صفر تغيير schema.

### Incremental

Foundational → US1 (لصق نظيف) → US2 (معاينة) → US4 (توحيد الإرسال) → US3 (حقل واتساب + عمود v30) → تحقّق جهازي.

### ملاحظة الفصل

لو US3 اتأجّل: Phase 6 كامل يُحذَف، `DATABASE_VERSION` يفضل 29، ولا migration Supabase. US1/US2/US4 يشحنوا مستقلين.
