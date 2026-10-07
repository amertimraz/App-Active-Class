# Research: سجل أرشفة الطالب

## R1 — التخزين
**Decision**: جدول جديد `student_archive_events` (محلي + Supabase)، صف لكل حدث: (student_id، type أرشفة/إعادة، event_at، أعمدة المزامنة). لا نعدّل جدول الحضور (تجنّب تلوث الحضور والنسب والمديونية) ولا نكتفي بعمود في students (يضيع التاريخ المتعدد).
**Alternatives**: سجل حضور بحالة خاصة — مرفوض (يلوّث الحساب، UNIQUE طالب+يوم، ويكسر كل مستهلكي الحضور).

## R2 — نقطة التسجيل
**Finding**: `DatabaseService.archiveStudent`/`unarchiveStudent` هما المسار الوحيد (فردي؛ مفيش أرشفة جماعية).
**Decision**: تسجيل الحدث داخل نفس الدالتين بعد نجاح التحديث، في try/catch منفصل (فشل الحدث لا يُفشل الأرشفة — FR-010). الحارس: لا حدث لو الحالة ما اتغيرتش؛ `archiveStudent` بتقرأ صف الطالب أصلًا (فنعرف `isArchived` قبل التحديث)، و`unarchiveStudent` نقرأ الحالة قبل التحديث.

## R3 — المزامنة (نمط session_overrides / booklets)
نقاط اللمس في `SyncEngine`: `_tables` (بعد TABLE_STUDENTS)، `_extendedTables` (القناة الممتدة لعزل أي مشكلة migration — درس spec 021/024)، `_pkCol`، payload الإرسال (`student_remote_id` من `_localRemoteId`)، payload الاستقبال (`_localIdForRemote`)، `_refreshAfterPull` (تحديث شاشة الحضور)، وتوفيق التكرار (`_reconcileDuplicate`) لمفتاح (student, type, event_at) عشان حدثين متطابقين من جهازين ما يتكرروش. الحذف: حذف الطالب بيحذف الأحداث محليًا (ON DELETE CASCADE) ومن الخادم بـ`on delete cascade` على `student_remote_id`؛ الأحداث للقراءة فقط فمفيش `check_delete` trigger ولا delete policy.

## R4 — الترحيل (Backfill)
**Decision**: DB v37: إنشاء الجدول + لكل طالب `is_archived=1` وعنده `archived_at` → صف أرشفة بنفس التاريخ (مرة واحدة داخل onUpgrade، بلا `_queueSync` محلي). لو الجهازين (مدرس/مساعد) عملوا backfill لنفس الطالب، المفتاح الفريد المنطقي (student, type, event_at) والتوفيق في الدمج بيمنعوا التكرار.

## R5 — العرض
- **تفاصيل الطالب** (`student_details_page.dart` — `_AttendanceTab`): بيدمج بالفعل `groupOverrides` (spec 032) كسطور بين السجلات؛ نضيف نفس الأسلوب لأحداث الأرشفة (مرتبة بالتاريخ مع التجميع الشهري). لا تدخل في presentCount/absentCount/attRate.
- **قائمة سجلات الحضور العامة** (`_RecordsTab` في `attendance_page.dart`): الأحداث تظهر كسطور مميّزة بين السجلات **بس** لما فلتر الحالة = "الكل" (البحث بالاسم وفلتر المجموعة يطبّقوا عليها كمان). لا تدخل في أي عدّاد.
- شاشات أخرى (تقارير، تصدير، بوابة، نسب): ما تقراش الجدول الجديد خالص → صفر تأثير (FR-006).

## R6 — صيغة العرض
دالة صرفة: "تمت أرشفته — اليوم 3:20 م" / "أُعيد من الأرشيف — أمس 9:05 ص" / تاريخ كامل لو أقدم. أيقونة archive/unarchive بلون محايد.
