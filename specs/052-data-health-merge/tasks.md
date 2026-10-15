# Tasks: صحة البيانات — اكتشاف ودمج المكرّر

**Input**: `specs/052-data-health-merge/` (plan.md, spec.md, research.md, data-model.md, contracts/merge-rules.md, quickstart.md)

**Tests**: اختبارات وحدة للنواة الصرفة (الاكتشاف + الخطة) + تحقق يدوي. بلا DB schema / migration / تغيير سيرفر.

**ملحوظة تنفيذ (2026-10-14)**: التنفيذ المحلي في `lib/services/database_service_data_health.dart` (extension بـ`part of` عشان يوصل لـ`_queueSync/_queueDelete`). طبقة التنفيذ (transaction + طابور) مغطّاة باختبار على SQLite حقيقي (`test/data_health_db_test.dart` بـ`sqflite_common_ffi`)، والتحقق بجهازين لوضع الفريق يدوي (T023, T027). حماية إضافية اتضافت: رفض دوّارة/تعارض أساسي-مكرّر.

**القاعدة**: كل مرحلة تنتهي بـ`flutter analyze` نضيف والتطبيق شغّال. التنفيذ ذرّي (transaction) + نسخة احتياطية إجبارية. لا يتم تشغيل أي دمج على بيانات المستخدم إلا بتأكيد صريح منه.

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup

- [X] T001 سجّل خط الأساس: `flutter analyze` (عدد الـinfo) و`flutter test` (350+ ناجحين) كمرجع.
- [X] T002 [P] انقل `normalizeArabic` من `lib/views/settings/settings_registry.dart` إلى `lib/utils/arabic_normalize.dart` (نقل حرفي)، وخلّي `settings_registry.dart` يعيد تصديرها (`export`) فاختبارات 051 تفضل شغّالة.

---

## Phase 2: Foundational — النواة الصرفة (تمنع كل القصص)

- [X] T003 `lib/utils/duplicate_detection.dart`: `normalizeName`، `codeStem` (يشيل لاحقة `-N`)، نماذج `CandidateCopy`/`DuplicateCase`/`MatchReason`، `detectGroupDuplicates`، `detectStudentDuplicates` (كود مطابق، اسم مطبّع في نفس المجموعة أو مجموعتين مكرّرتين، استبعاد الإخوة)، `pickCanonical` (الأكتر بيانات ← الأقدم ← بلا لاحقة، غير المؤرشف أولًا).
- [X] T004 [P] `test/duplicate_detection_test.dart`: تطبيع، `G206` مع `G206-2`، إخوة مش تكرار، تطابق بالاسم فقط غير محدّد، نسختين/تلاتة، المؤرشف ما يبقاش الأساسي، مجموعتين بنفس الاسم.
- [X] T005 `lib/utils/merge_plan.dart`: `MergeRule` لكل جدول (حسب contracts/merge-rules.md)، `MergeInputs` (صفوف مبسّطة لكل طالب/جدول: id، remoteId، المفتاح الطبيعي، الحالة)، `buildMergePlan` → `MergePlan` (moves/drops/conflicts/summary) + قواعد "الأساسي يكسب" و"أحدث `updated_at` لو تكرّر المفتاح عند المكرّر".
- [X] T006 [P] `test/merge_plan_test.dart`: حضور بنفس اليوم يتحذف، بيوم مختلف يتنقل، دفعة بنفس التاريخ+المبلغ تتحذف، درجة بنفس الامتحان، تعارض حالة حضور يُعدّ، 3 نسخ، مفيش تعديل في الأساسي، حالة Grade 2 (24 مكرّر → أرقام متوقعة).
- [X] T007 **CHECKPOINT**: `flutter analyze` + اختبارات T004/T006 + اختبارات 051.

---

## Phase 3: US1 — الفحص وعرض الحالات (P1) 🎯 MVP

**اختبار مستقل**: فحص بيانات فيها تكرار → حالات صحيحة بدون أي تعديل.

- [X] T008 [US1] `lib/services/database_service.dart`: دوال قراءة مجمّعة: `studentRecordCounts()` (GROUP BY لحضور/دفعات/واجب/درجات/أخرى لكل طالب) + `pendingOutboxCount()`.
- [X] T009 [US1] `lib/services/data_health_service.dart`: `scan()` يحمّل المجموعات والطلاب والعدّادات ويبني `ScanResult` (حالات مجموعات + طلاب مرتبطة) بمؤشر تقدّم، قراءة فقط.
- [X] T010 [US1] `lib/controllers/data_health_controller.dart`: حالة الشاشة (جاري الفحص/النتيجة/اختيارات/أساسي مختار).
- [X] T011 [US1] `lib/views/settings/data_health_page.dart`: زر "افحص التكرار"، قائمة الحالات (نسخ جنب بعض بالعدّادات)، حالة "بياناتك سليمة"، تحديد/استبعاد، تغيير الأساسي (بدون تنفيذ بعد).
- [X] T012 [US1] سطر تنقّل "صحة البيانات" في `lib/views/settings/categories/data_category.dart` (مخفي للمساعد: `isEnabled && !isOwner`)، وعنصر `data.data_health` في `settings_registry.dart`، وتحديث اختبار الجرد (nav: 10)، وكلمات بحث (تكرار، دمج، مكرر).
- [X] T013 **CHECKPOINT**: analyze + test + تجربة الفحص على بيانات (قراءة فقط).

---

## Phase 4: US2 + US3 — الدمج (طلاب + مجموعات) (P1)

**اختبار مستقل**: دمج حالة طالب وحالة مجموعة والتحقق من الأرقام.

- [X] T014 [US2] `DatabaseService.applyMergePlan(plan)`: (1) collect remote ids، (2) transaction: نقل الصفوف + حذف المكرّر + حذف الطالب + نقل طلاب/روابط المجموعة + حذف المجموعة، (3) طابور المزامنة بالترتيب (contracts §4)، (4) `_unlinkOrphanedSiblingSurvivor` للإخوة، (5) `_notifyChanged`.
- [X] T015 [US2] ربط الخطة بالبيانات: في `DataHealthService` جلب `MergeInputs` للحالات المحدّدة فقط (استعلامات بالـids) وبناء `MergePlan`، وعرض ملخص المعاينة (منقول/محذوف/متعارض + قائمة الدفعات المرشّحة للإزالة القابلة للاستبعاد).
- [X] T016 [US3] دمج المجموعة: مطابقة طلاب المجموعة المكرّرة بالاسم المطبّع مع الأساسية، نقل غير المطابق، `exam_groups`/`booklet_groups` (منع الربط المزدوج)، `session_overrides`.
- [X] T017 [US2] واجهة المعاينة والتأكيد في `data_health_page.dart`: شاشة معاينة بالأرقام + تأكيد صريح + مؤشر تقدّم + شاشة النتيجة، وتحديث الكنترولرات المفتوحة بعد التنفيذ (حضور، دفعات، امتحانات، داشبورد، مجموعات، طلاب).
- [X] T018 **CHECKPOINT**: analyze + test + تجربة دمج على نسخة بيانات (يدوي بموافقة المستخدم).

---

## Phase 5: US4 — الأمان (P2)

- [X] T019 [US4] `DataHealthService.execute`: `BackupService().createBackup()` إجباري (فشله يمنع)، وأي استثناء داخل الـtransaction = rollback كامل برسالة واضحة.
- [X] T020 [US4] شروط مسبقة: الأساسي متزامن (`remote_id`) في وضع الفريق، تحذير `pendingOutboxCount() > 0` (استنّى/كمّل)، `requireTeamOwnerIfTeamMode`، منع التنفيذ للمساعد.
- [X] T021 [P] [US4] رسالة بعد التنفيذ بمكان النسخة وإزاي يرجّع منها (رابط لشاشة الاستعادة الموجودة).

---

## Phase 6: US5 — وضع الفريق (P2)

- [X] T022 [US5] تنبيه ثابت: "لازم المساعد يكون على 1.2.74 أو أحدث"؛ وتأكيد الترتيب في الطابور باختبار وحدة لمنطق الترتيب (قائمة العمليات المطلوبة).
- [ ] T023 [P] [US5] تحقق يدوي (جهازين): المساعد يلاقي نفس الأرقام ولا يرجع المكرّر.

---

## Phase 7: US6 — السجل والتقرير (P3)

- [X] T024 [US6] تخزين `MergeLogEntry` (آخر 20) في `settings['data_health_log']` + عرض السجل + مشاركة الملخص (نص).

---

## Phase 8: Polish

- [X] T025 `flutter analyze` + `flutter test` كاملين.
- [X] T026 تحديث `HANDOFF.md` والذاكرة.
- [ ] T027 تحقق يدوي على الجهاز حسب `quickstart.md` (بموافقة المستخدم على أي دمج فعلي).

---

## Dependencies & Order

- Phase 1 ← Phase 2 (T003..T007) ← Phase 3 (US1) ← Phase 4 (US2/US3) ← Phase 5 (US4) ← Phase 6 (US5) ← Phase 7 (US6) ← Phase 8.
- T004/T006 [P] بعد T003/T005. T008..T011 متسلسلة على T003. T014 بعد T005+T008.

## MVP

Phase 1–3 (الفحص وعرض الحالات). الدمج الفعلي يبدأ من Phase 4 بعد تجربة الفحص.
