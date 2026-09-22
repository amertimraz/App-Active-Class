# Tasks: تفاعل الطالب في حضور اليوم — تقييم إيموجي بسيط

**Input**: Design documents from `specs/040-student-interaction/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/attendance-controller.md, quickstart.md

**Tests**: اختبار وحدة واحد مطلوب (`test/student_interaction_test.dart` للدوال الصرفة). باقي التحقق يدوي على جهاز حقيقي (لا widget tests لشاشة الحضور).

**Organization**: مقسَّمة حسب الـUser Stories من spec.md (US1 = P1 تسجيل فردي، US2 = P2 تطبيق جماعي، US3 = P2 تقارير). Foundational تشمل تغييرات المخطط/المزامنة اللي كل الـStories محتاجاها.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to
- ملفات المسار كلها نسبية لجذر المشروع `C:\repo\active_class`

---

## Phase 1: Setup

- [X] T001 إضافة الثوابت الجديدة في `lib/config/constants.dart`: `STUDENT_INTERACTION_ACTIVE = 'نشيط'`, `STUDENT_INTERACTION_NEUTRAL = 'عادي'`, `STUDENT_INTERACTION_DISENGAGED = 'غير متفاعل'`, `COL_ATTENDANCE_INTERACTION = 'interaction'`، ورفع `DATABASE_VERSION` بمقدار 1 (راجع القيمة الحالية 33 وقت التخطيط — تأكد من القيمة الفعلية وقت التنفيذ)

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: تعديلات المخطط والمزامنة والدوال الصرفة اللي كل الـUser Stories محتاجاها قبل ما تبدأ

- [X] T002 [P] إضافة حقل `interaction` (`String?`) لكلاس `Attendance` في `lib/models/attendance_model.dart`: تحديث `toMap`/`fromMap`/`copyWith` (مع `clearInteraction` بنفس نمط `clearGuardianWhatsapp` في `Student`)
- [X] T003 [P] إضافة الدوال الصرفة في `lib/models/attendance_model.dart` (راجع data-model.md): `normalizeInteraction`, `canRecordInteraction`, `interactionEmoji`, `interactionLabel`
- [X] T004 [P] إنشاء `test/student_interaction_test.dart` باختبارات `canRecordInteraction`, `interactionEmoji`, `normalizeInteraction` (راجع quickstart.md)
- [X] T005 في `lib/services/database_service.dart`: إضافة `$COL_ATTENDANCE_INTERACTION TEXT` لجملة `CREATE TABLE` الخاصة بـ`attendance` (تنصيب جديد)، وإضافة فرع `if (oldVersion < <DATABASE_VERSION الجديدة>)` في `_onUpgrade` بـ`ALTER TABLE $TABLE_ATTENDANCE ADD COLUMN $COL_ATTENDANCE_INTERACTION TEXT` (نفس نمط سطر 806-812 لـguardian_whatsapp)
- [X] T006 في `lib/services/sync_engine.dart`: إضافة `'interaction': payload[COL_ATTENDANCE_INTERACTION]` في push mapping لـ`TABLE_ATTENDANCE` (بجانب `'notes'`، حوالي سطر 558)
- [X] T007 في `lib/services/sync_engine.dart`: إضافة `COL_ATTENDANCE_INTERACTION: remote['interaction']` في pull mapping لـ`TABLE_ATTENDANCE` (بجانب `COL_ATTENDANCE_NOTES`، حوالي سطر 1507)
- [X] T008 إنشاء `supabase/migration_student_interaction.sql` (راجع research.md #6): `alter table public.attendance add column if not exists interaction text;` — **تحقّق وقت التنفيذ الفعلي من الدور المالك لجدول attendance** (`supabase_admin` أو غيره) قبل التطبيق عبر SSH
- [X] T009 **CHECKPOINT**: `flutter analyze` + `flutter test` (شامل T004) — صفر تراجع عن الأساس المرجعي؛ تشغيل التطبيق على جهاز واختبار إن قاعدة البيانات المحلية بترقّى بدون كراش (فتح التطبيق بعد التحديث)، وتطبيق migration T008 على السيرفر فعليًا

**Checkpoint**: البنية التحتية (مخطط + مزامنة + دوال عرض) جاهزة، أي User Story تقدر تبدأ.

---

## Phase 3: User Story 1 - تسجيل تفاعل الطالب وقت الحضور (Priority: P1) 🎯 MVP

**Goal**: المدرّس يقدر يسجّل/يلغي/يغيّر تفاعل طالب حاضر أو متأخر بضغطة إيموجي، ويتمسح تلقائيًا لو الطالب بقى غائب.

**Independent Test**: تسجيل حضور طالب، اختيار تفاعل له، التأكد من الحفظ والعرض الفوري؛ تغيير حالته لغائب والتأكد من مسح التفاعل تلقائيًا (راجع quickstart.md قسم 1).

### Implementation for User Story 1

- [X] T010 [US1] في `lib/controllers/attendance_controller.dart`: تعديل `setAttendanceStatus` بحيث عند `status == null` أو `status == ATTENDANCE_ABSENT`، يُمسح `interaction` على السجل الموجود قبل التحديث/الحذف (راجع contracts/attendance-controller.md — "تعديل setAttendanceStatus الموجودة")
- [X] T011 [US1] في `lib/controllers/attendance_controller.dart`: إضافة دالة `Future<void> setInteraction(int studentId, DateTime day, String? interaction)` (راجع contracts/attendance-controller.md) — تتحقق من `canRecordInteraction` قبل الكتابة، وتنادي `loadAttendance()` بعد النجاح
- [X] T012 [US1] إنشاء ويدجت `_InteractionRow` (أو تسمية مشابهة) في `lib/views/attendance/attendance_page.dart`: صف 3 أزرار إيموجي (😃/😐/😴) بنفس نمط toggle الموجود في `_AttendanceStatusSegmented` (ضغط المختار يمسحه)
- [X] T013 [US1] في `lib/views/attendance/attendance_page.dart` — `_StudentAttendanceChip`: إضافة `_InteractionRow` تحت `_AttendanceStatusSegmented` مباشرة، بشرط ظهور `canRecordInteraction(norm) == true` بس، وربط `onSelect` باستدعاء `controller.setInteraction(...)`
- [X] T014 [US1] **CHECKPOINT**: `flutter analyze` + `flutter test` (صفر تراجع) ثم تحقق يدوي كامل (quickstart.md قسم 1) — تسجيل/إلغاء/تغيير التفاعل، عدم ظهوره لطالب غائب، مسحه التلقائي عند التحوّل لغائب، وبقاؤه بعد إغلاق وفتح الشاشة

**Checkpoint**: US1 مكتملة ومستقلة — MVP قابل للتسليم هنا.

---

## Phase 4: User Story 2 - تطبيق تفاعل واحد على كل الطلاب الحاضرين دفعة واحدة (Priority: P2)

**Goal**: المدرّس يقدر يختار مستوى تفاعل واحد ويطبّقه على كل الطلاب المؤهَّلين (حاضر/متأخر) في المجموعة بإجراء واحد.

**Independent Test**: تطبيق تفاعل جماعي على مجموعة فيها حاضرين وغائبين، التأكد من استثناء الغائبين وتحديث الحاضرين فقط، مع إمكانية تعديل فردي بعدها (راجع quickstart.md قسم 2).

### Implementation for User Story 2

- [X] T015 [US2] في `lib/controllers/attendance_controller.dart`: إضافة دالة `Future<void> markGroupInteraction(List<int> studentIds, DateTime day, String interaction)` (راجع contracts/attendance-controller.md) — بنفس هيكل `markGroupAllPresent` (تتابع نجاح/فشل فردي)، تتخطّى الطلاب غير المؤهَّلين (`canRecordInteraction == false`) بلا خطأ
- [X] T016 [US2] في `lib/views/attendance/attendance_page.dart`: إضافة زرار "تطبيق على الكل" جنب زرار "تحضير الكل" الموجود (نفس صف أدوات المجموعة، حوالي سطر 1180)، يفتح قائمة/bottom sheet صغيرة لاختيار مستوى تفاعل واحد من الثلاثة
- [X] T017 [US2] ربط اختيار المستوى من القائمة/الـsheet في T016 باستدعاء `controller.markGroupInteraction(groupStudents.map((s) => s.id!).toList(), selectedDay, <القيمة المختارة>)`، مع رسالة توست واضحة لو مفيش طلاب مؤهَّلين (FR-014)
- [X] T018 [US2] **CHECKPOINT**: `flutter analyze` + `flutter test` (صفر تراجع) ثم تحقق يدوي كامل (quickstart.md قسم 2)

**Checkpoint**: US2 مكتملة، مستقلة عن US3.

---

## Phase 5: User Story 3 - مراجعة تفاعل الطلاب في التقارير (داخل التطبيق وفي رسالة واتساب) (Priority: P2)

**Goal**: تفاعل الطالب يظهر في سجل حضوره، تقرير الحضور الشهري (شاشة + PDF)، وملخّص رسالة واتساب.

**Independent Test**: تسجيل تفاعل، ثم التأكد من ظهوره بنفس القيمة في الثلاث أماكن (راجع quickstart.md قسم 3).

### Implementation for User Story 3

- [X] T019 [P] [US3] في `lib/views/students/student_details_page.dart` — `_AttendanceTab` (حوالي سطر 1221): إضافة عرض `interactionEmoji(a.interaction)` جنب `title`/`trailing` كل سجل حضور (لو `a.interaction` غير فارغ)
- [X] T020 [US3] في `lib/services/export_service.dart`: تغيير نوع `attMap` من `Map<int, Map<DateTime, String>>` إلى `Map<int, Map<DateTime, Attendance>>` في `exportAttendancePDF`/`_attendanceTable`/`_attendanceSummary` (راجع data-model.md وresearch.md #4) — تحديث كل الاستخدامات الداخلية (`sAtt[d]` بيرجع `Attendance?` بدل `String?`) بدون تغيير في التوقيع الخارجي لـ`exportAttendancePDF` نفسها
- [X] T021 [US3] **مُنفَّذة بتصحيح**: خط PDF (Cairo) لا يدعم رسم إيموجي — بدل استبدال النقطة بإيموجي، `_attCell` بقت تلوّن النقطة بلون مخصَّص لكل مستوى تفاعل (بنفسجي/أزرق/رمادي) بدل اللون العادي، مع مفتاح ألوان نصي في `_attendanceSummary` (راجع research.md #4 المُحدَّث). الأيام بدون تفاعل تفضل بنفس الشكل الحالي بالضبط.
- [X] T022 [US3] في `lib/utils/monthly_report_message.dart` — `buildMonthlyReportMessage`: إضافة حساب عدد أيام كل مستوى تفاعل ضمن `monthAtt` (الفترة المُمرَّرة للدالة)، وإضافة سطر ملخّص بعد قسم الحضور الحالي يستبعد أي مستوى عدده صفر، ويختفي القسم بالكامل لو مفيش أي يوم تفاعل مسجَّل خلال الفترة (راجع research.md #5)
- [X] T023 [US3] **CHECKPOINT النهائي**: `flutter analyze` + `flutter test` (صفر تراجع) ثم تحقق يدوي كامل (quickstart.md قسم 3 و4 — شامل وضع الفريق)

**Checkpoint**: كل الـUser Stories الثلاثة مكتملة.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T024 [P] تشغيل `flutter analyze` كامل للمشروع، التأكد من مطابقة العدد للأساس المرجعي (صفر جديد)
- [X] T025 [P] تشغيل `flutter test` كامل للمشروع، التأكد من نجاح كل الاختبارات (شامل `student_interaction_test.dart` الجديد)
- [X] T026 تحديث `HANDOFF.md` بملخص الميزة بعد التحقق الكامل على جهاز حقيقي ووضع الفريق (رقم سبيك، الملفات المتأثرة، حالة الـmigration على السيرفر)

---

## Dependencies & Execution Order

- **Phase 1 (Setup) → Phase 2 (Foundational)**: T002-T009 تعتمد على ثوابت T001.
- **Phase 2 → كل الـUser Stories**: US1/US2/US3 كلهم يعتمدوا على وجود العمود + دوال العرض + المزامنة من Foundational قبل ما يبدأوا.
- **US1 → US2**: US2 (التطبيق الجماعي) بيستخدم نفس دالة `canRecordInteraction`/نمط الكتابة من US1، لكن تقنيًا مستقلة (ملفات/دوال مختلفة) — يمكن تنفيذها بالتوازي مع US1 لو فيه أكتر من مطوّر، لكن الأولوية تفضّل US1 أولًا (MVP).
- **US1/US2 → US3**: US3 (التقارير) بتعرض بيانات مسجَّلة فعليًا — لازم يكون فيه تفاعل مسجَّل بالفعل (من US1 على الأقل) للتحقق منها عمليًا، رغم إن التعديلات نفسها (كود العرض) مستقلة تقنيًا.

### Parallel Opportunities

- T002/T003/T004 (Foundational): ملفات/أجزاء مختلفة من نفس الملف، قابلة للتنفيذ بالتوازي بحذر (T002/T003 في نفس الملف — تسلسل بسيط أفضل من تعارض).
- T006/T007 (sync_engine push/pull): نفس الملف لكن أقسام مختلفة تمامًا (push مقابل pull) — قابلة للتوازي.
- T019 (US3, ملف مستقل) مقابل T020/T021 (US3, ملف export_service) مقابل T022 (US3, ملف monthly_report_message): 3 ملفات مختلفة تمامًا، قابلة للتوازي الكامل.
- T024/T025 (Polish): بالتوازي.

---

## Implementation Strategy

### MVP الأول

1. Setup (T001) → Foundational (T002-T009، شامل migration السيرفر) → US1 (T010-T014) → **STOP and VALIDATE** على جهاز حقيقي.
2. لو تمام: كمّل US2 ثم US3 بأي ترتيب (مستقلين عن بعض).

### Incremental Delivery

1. Foundational → US1 → تحقق → **تسليم أولي**: المدرّس يقدر يسجّل تفاعل فردي ويشوفه بس في نفس شاشة الحضور.
2. US2 → تحقق → التطبيق الجماعي بقى متاح.
3. US3 → تحقق شامل (شاشة الطالب، PDF، واتساب، وضع الفريق) → Polish → نشر.
