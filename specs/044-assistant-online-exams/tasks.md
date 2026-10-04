# Tasks: المساعد ينشئ ويدير الامتحانات الإلكترونية

**Input**: plan.md, spec.md, research.md, data-model.md, contracts/team-portal-contract.md, quickstart.md
**Tests**: اختبار وحدة للدالة الصرفة + تحقق يدوي بجهازين (الأمان والتفويض السحابي مش قابلة للأتمتة هنا).
**تنبيه**: T004 وT005 يغيّروا إنتاج (Supabase + قواعد Firestore) — ينفَّذوا بموافقة صريحة من المستخدم.

## Phase 1: Setup / Foundational

- [x] T001 [P] إنشاء `lib/utils/online_exam_access.dart`: `OnlineExamAccess` + `onlineExamAccess(...)` حسب `contracts/team-portal-contract.md` §1
- [x] T002 [P] إنشاء `test/online_exam_access_test.dart`: كل صفوف الجدول (6 حالات) + اشتراك منتهي
- [x] T003 إنشاء `supabase/migration_assistant_online_exams.sql` (idempotent): `alter table team_members add column if not exists can_manage_online_exams boolean not null default false, add column if not exists firebase_uid text`؛ `alter table teams add column if not exists portal_slug text, portal_enabled boolean not null default false, portal_expires_at timestamptz`؛ RPCs `set_team_portal` (owner فقط) و`set_my_firebase_uid`
- [x] T004 **(إنتاج — بموافقة)** التحقق من مالك الجدولين وتطبيق T003 عبر SSH ثم التأكد من الأعمدة والـRPCs
- [x] T005 **(إنتاج — بموافقة)** تعديل `firestore.rules`: `_oeOwner(slug)` تقبل `ownerUid` أو `coOwnerUids`؛ ثم `firebase deploy --only firestore:rules`
- [x] T006 في `lib/services/team_mode_service.dart`: `canManageOnlineExams` (Rx) + getter `canManageOnlineExamsNow`؛ قراءته في `_refreshMyPermissions` (وإعادة ضبطه false عند التعطيل/الخروج)؛ Rx `teamPortalSlug/teamPortalEnabled/teamPortalExpiresAt` للمساعد + حفظها/استعادتها عبر `app_settings` (مفاتيح `team_portal_*`) + getters `isAssistant` و`teamPortalActive`
- [x] T007 **CHECKPOINT**: `flutter analyze` + `flutter test` (شامل T002) صفر تراجع

## Phase 2: US2 — المدرس يتحكم (P1)

- [x] T008 [US2] في `manage_members_screen.dart`: `_PermSwitch` جديد "إدارة الامتحانات الإلكترونية" (مفتاح `can_manage_online_exams`، افتراضي false) تحت مفاتيح العرض؛ بعد نجاح التحديث يستدعي مزامنة `coOwnerUids` فورًا (T012)
- [x] T009 [US2] في `TeamModeService` (جهاز المساعد): مؤقت تحديث دوري 30 ثانية + عند الرجوع للتطبيق يستدعي `_refreshMyPermissions` و`_refreshTeamPortal` (`select portal_* from teams`) — يبدأ مع الفريق ويتوقف مع `disable`/الخروج
- [x] T010 [US2] **CHECKPOINT**: تحقق يدوي (quickstart بنود 1، 2، 6 شقّ الواجهة)

## Phase 3: US3 — اشتراك البوابة يحكم الفريق (P1)

- [x] T011 [US3] في `TeamModeService` (جهاز المالك): `_watchOwnerPortal` — `everAll([parentPortalEnabled, parentPortalExpiresAt, licenseCode, licenseVerifiedTick])` ⇒ RPC `set_team_portal(_slug: ParentPortalService().ensureSlug(), ...)`؛ استدعاء أولي عند بدء الفريق
- [x] T012 [US3] في `OnlineExamService`: `setCoOwners(List<String> uids)` — يكتب `coOwnerUids` على `online_exams/{slug}` (merge، للمالك فقط). وفي `TeamModeService` (مالك): `syncCoOwners()` تقرأ `team_members` (`can_manage_online_exams = true` و`firebase_uid` غير null) وتستدعي `setCoOwners`؛ تُشغَّل عند الإقلاع + كل دقيقتين + بعد تغيير الصلاحية (T008)
- [x] T013 [US3] **CHECKPOINT**: تحقق يدوي (quickstart بند 7: اشتراك منتهي/مجدَّد)

## Phase 4: US1 — المساعد ينشئ وينشر (P1) 🎯

- [x] T014 [US1] في `TeamModeService` (مساعد): تسجيل `firebase_uid` — بعد `OnlineExamService` `_ensureAuth` يستدعي `set_my_firebase_uid` لو الـuid اختلف عن المسجّل؛ يتنفّذ مع دورة T009 وبعد أي تغيير للـuid
- [x] T015 [US1] في `OnlineExamService`: `_slug()` يرجّع `teamPortalSlug` للمساعد (وغير ذلك `ensureSlug()`)؛ `publish()` للمساعد يتخطى كتابة الجذر و`publishProfile()` و"ensure summaries" ويكتب `exams/{id}` فقط؛ نفس الـslug لرفع الصور (`ExamController.uploadQuestionImage`)
- [x] T016 [US1] في `ExamController.publishOnlineExam`: استبدال فحص `parentPortalActiveNow` بـ`onlineExamAccess(...).canCreate` برسالة عربية مناسبة (اشتراك المدرس منتهي / مفيش صلاحية / الرابط لسه ما وصلش)
- [x] T017 [US1] في `exams_page.dart` (زر الإنشاء) و`online_exams_tab.dart` (القفل): استخدام `onlineExamAccess(...)`؛ المساعد غير المسموح يشوف القائمة بدون أزرار الإجراءات (`readOnly`)
- [x] T018 [US1] في `online_exam_results_page.dart`: وسيط `readOnly` يخفي كل إجراءات الاعتماد/الإبطال/التحديث/التعديل؛ `online_exams_tab.dart` يمرّره
- [ ] T019 [US1] **CHECKPOINT**: `flutter analyze` + `flutter test` ثم تحقق يدوي بجهازين (quickstart بنود 3، 4، 5، 6، 8، 9، 10)

## Phase 5: US4 (اختياري) — تتبع المنشئ (FR-013)

- [ ] T020 [P] في `constants.dart`: `DATABASE_VERSION = 37` + `COL_EXAM_CREATED_BY_NAME`؛ `database_service.dart`: عمود + ALTER في `_onUpgrade`؛ `Exam` model؛ `sync_engine.dart` push/pull؛ `supabase` alter على `exams`
- [ ] T021 يعبّى الاسم عند إنشاء امتحان إلكتروني (اسم العضو الحالي) ويظهر في بطاقة الامتحان (`online_exams_tab.dart`)

## Phase 6: Polish

- [x] T022 [P] `flutter analyze` + `flutter test` كاملين
- [ ] T023 تحديث `HANDOFF.md` بملخص spec 044 + بناء release وتثبيت وتحقق نهائي

## Dependencies

T001/T002/T003 بالتوازي ← T004/T005 (إنتاج، بموافقة) ← T006 ← T007. T008/T009 (US2) ← T011/T012 (US3) ← T014–T018 (US1). US4 مستقل ويتأجل بعد الباقي.

## MVP

T001–T019: الصلاحية + حالة البوابة + التفويض + النشر + قفل/قراءة فقط. US4 (T020–T021) اختياري.
