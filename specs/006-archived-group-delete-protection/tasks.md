---

description: "Task list for archived-student group-delete protection"
---

# Tasks: حماية الطلاب المؤرشفين من حذف المجموعة

**Input**: Design documents from `/specs/006-archived-group-delete-protection/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [quickstart.md](quickstart.md)

**Tests**: لم تُطلَب اختبارات آلية — التحقق عبر [quickstart.md](quickstart.md) اليدوي/على الجهاز.

**Organization**: ميزة صغيرة جدًا — فحص مركزي واحد في نقطة استدعاء مشتركة. لا توجد مرحلة Setup/Foundational منفصلة.

## Format: `[ID] [P?] [Story] Description`

## Path Conventions

مشروع Flutter موحّد واحد — المسارات نسبةً لجذر `C:\repo\active_class`.

---

## Phase 1: User Story 1 - منع حذف مجموعة فيها طلاب مؤرشفين (Priority: P1) 🎯 MVP

**Goal**: حذف أي مجموعة بها طالب مؤرشف واحد على الأقل يُرفض، من كل نقاط الحذف في التطبيق، مع رسالة واضحة.

**Independent Test**: أرشفة طالب في مجموعة، محاولة حذفها من الشاشتين (المجموعات، تفاصيل المجموعة)، والتأكد من الرفض في الحالتين (سيناريوهات 1، 2، 4 في quickstart.md).

### Implementation for User Story 1

- [X] T001 [US1] في [lib/services/database_service.dart](../../lib/services/database_service.dart)، بجانب `getGroupStudentCount()` الموجودة، أضف دالة جديدة `Future<int> getArchivedStudentCountForGroup(int groupId)` تنفّذ `SELECT COUNT(*) FROM $TABLE_STUDENTS WHERE $COL_STUDENT_GROUP_ID = ? AND $COL_STUDENT_IS_ARCHIVED = 1` وترجع `Sqflite.firstIntValue(result) ?? 0` — نفس نمط `getAllStudentsCount()` الموجودة بالفعل.
- [X] T002 [US1] في [lib/controllers/group_controller.dart](../../lib/controllers/group_controller.dart)، داخل `deleteGroup(int id)`: قبل استدعاء `_dbService.deleteGroup(id)`، نادِ `final archivedCount = await _dbService.getArchivedStudentCountForGroup(id);` — لو `archivedCount > 0`، نادِ `ToastHelper.error(...)` برسالة توضح العدد وتوجّه لشاشة الأرشيف (مثال: `'لا يمكن حذف المجموعة — بها $archivedCount طالب مؤرشف. تعامل معهم أولاً من شاشة الأرشيف.'`)، وارجع `false` من غير ما تكمل الحذف.
- [X] T003 [US1] تأكد أن باقي جسم `deleteGroup()` (الحذف الفعلي + `groups.removeWhere` + `try/catch` الموجود) يفضل يعمل بلا تغيير لما `archivedCount == 0` — الفحص الجديد إضافة قبل المسار الحالي، مش استبدال له.

**Checkpoint**: US1 شغالة ومختبَرة — نفّذ سيناريوهات 1، 2، 4 من quickstart.md.

---

## Phase 2: User Story 2 - التحذير الحالي يفضل شغال كطبقة أمان ثانية (Priority: P2)

**Goal**: تأكيد إن تحذير الحذف (اللي بيوضح عدد المؤرشفين، من الإصلاح السابق في هذه الجلسة) لسه دقيق، كخط دفاع ثانٍ نظري.

**Independent Test**: مراجعة كودية + تحقق بصري إن الرسالة لسه بتحسب العدد صح (لا حاجة لتنفيذ فعلي جديد — هذا التحذير مُصلَح بالفعل في commit سابق).

### Verification for User Story 2

- [X] T004 [US2] راجع [lib/views/groups/groups_page.dart](../../lib/views/groups/groups_page.dart) و[lib/views/groups/group_details_page.dart](../../lib/views/groups/group_details_page.dart) وتأكد أن حساب `archivedCount`/`totalToDelete` في نص تحذير الحذف (المُصلَح مسبقًا) لسه سليم ولم يتأثر بإضافة الفحص الجديد في US1 — الاثنان مستقلان (التحذير UI-only، الفحص الجديد business-rule في الكونترولر).

**Checkpoint**: US2 مؤكَّدة — لا عمل كود إضافي متوقَّع، تحقق فقط.

---

## Phase 3: Polish & Verification

- [X] T005 **تحقق بمراجعة الكود** (بدل تنفيذ حي على مجموعة حقيقية بها بيانات فعلية — تجنبًا لمخاطرة حذف بيانات المستخدم الحقيقية أثناء الاختبار): تأكدت أن فرع `archivedCount == 0` في `deleteGroup()` يمر مباشرة لنفس سطر `_dbService.deleteGroup(id)` الأصلي، غير معدَّل إطلاقًا — لا تراجع وظيفي ممكن (FR-004).
- [X] T006 **تحقق بمراجعة الكود**: `getArchivedStudentCountForGroup()` استعلام DB حي يُنفَّذ من جديد في كل استدعاء لـ`deleteGroup()` — لا تخزين مؤقت (caching)، فمستحيل تحصل حالة "علقان" بعد ما يتم التعامل مع كل الطلاب المؤرشفين فعليًا.
- [X] T007 **تحقق حي على الجهاز — تم بنجاح**: نفّذت الحذف فعليًا مرتين من [groups_page.dart](../../lib/views/groups/groups_page.dart) (المسار غير المنتظِر) على مجموعة حقيقية بها طالب مؤرشف واحد — الحذف اتمنع في المرتين، والمجموعة فضلت موجودة بنفس عدد الطلاب، والتحذير قبل التأكيد أظهر "19 طالب (منهم 1 من الأرشيف)" بدقة.
- [X] T008 [P] شغّل `flutter analyze` للتأكد من عدم وجود أخطاء/تحذيرات جديدة.

---

## Dependencies & Execution Order

- **US1 (Phase 1)**: لا اعتماديات — التغيير الأساسي والوحيد في الكود.
- **US2 (Phase 2)**: تحقق فقط، يمكن تنفيذه بالتوازي مع US1 أو بعده مباشرة.
- **Polish (Phase 3)**: يعتمد على اكتمال US1.

## Implementation Strategy

### MVP First

1. T001 (دالة العدّ) → T002 (الفحص في الكونترولر) → T003 (تأكيد عدم كسر المسار العادي).
2. تحقق سيناريوهات 1، 2، 4 من quickstart.md.
3. Polish (T005-T008)، مع تركيز خاص على T007 (مسار `groups_page.dart` غير المنتظِر).

## Notes

- الميزة بالكامل تتلخص في دالة DB جديدة + فحص واحد في مكان واحد — لا شاشات جديدة، لا تغيير في مخطط قاعدة البيانات.
- التحذير الحالي (المُصلَح في الجولة السابقة من هذه الجلسة) يبقى كما هو تمامًا — هذه الميزة تضيف منعًا فعليًا فوقه، لا تستبدله.
