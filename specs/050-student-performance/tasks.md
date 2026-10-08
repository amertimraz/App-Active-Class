# Tasks: تقرير أداء ومستوى الطالب

**Tests**: اختبارات وحدة للنواة + تحقق يدوي. بلا DB/migration. نشر صفحة المتابعة بموافقة المستخدم.

## Phase 1: النواة الصرفة
- [x] T001 `lib/utils/performance.dart`: الأنواع، `monthsBack`، النسب الأربعة والعدّادات، `trendOf`، `levelOf`، `buildPerformance`، `rankPerformances`، `trendArrow` حسب `contracts/performance.md`
- [x] T002 `performanceMessage` + `performancePortalFields`
- [x] T003 [P] `test/performance_test.dart` (الحالات في quickstart)
- [x] T004 **CHECKPOINT**: analyze + `flutter test test/performance_test.dart`

## Phase 2: جلب البيانات
- [x] T005 `lib/services/performance_service.dart`: `forStudent` و`forGroup` (جلب جماعي باستعلام لكل نوع) + قراءة المؤشرات المفعّلة من `SettingsController`
- [x] T006 **CHECKPOINT**: analyze + test

## Phase 3: US1+US2 — تبويب الأداء والرسم
- [x] T007 [US1] `student_performance_tab.dart`: اختيار الشهر، بطاقة لكل مؤشر (نسبة، سابق، سهم، فرق، تقييم، عدد العينات)، حالة "لا بيانات"
- [x] T008 [US2] رسم `fl_chart` لآخر 6 شهور (فجوات عند null، اختيار مؤشر يعرض قيمه)
- [x] T009 [US1] تبويب رابع "الأداء" في `student_details_page.dart` (قفل بدون `canSeeAcademics`)
- [x] T010 **CHECKPOINT**: analyze + test + تحقق يدوي (quickstart 1–2, 7–8)

## Phase 4: US3 — الإرسال
- [x] T011 [US3] `PerformanceCard` + `capturePerformanceCardPng` + معاينة bottom sheet + مشاركة PNG
- [x] T012 [US3] إرسال نصي عبر `launchGuardianWhatsapp` + قفل الزر لو لا رقم
- [x] T013 [US3] `ExportService.exportStudentPerformancePDF` (صفحة A4 واحدة)
- [x] T014 [US3] قائمة "إرسال لولي الأمر" (نص/كارت/PDF) في تبويب الأداء
- [x] T015 **CHECKPOINT**: analyze + test + تحقق يدوي (quickstart 3–4)

## Phase 5: US4+US5 — المجموعة
- [x] T016 [US4] `group_performance_page.dart`: قائمة مرتبة، سهم الاتجاه، فلتر المتراجعين، استبعاد المؤرشفين، فتح أداء الطالب
- [x] T017 [US4] زر "الأداء" في `group_details_page.dart`
- [x] T018 [US5] إرسال جماعي (اختيار الشكل، ملخص قبل البدء، تخطي من بلا رقم، انتظار الرجوع، كارت خارج الشاشة)
- [x] T019 **CHECKPOINT**: analyze + test + تحقق يدوي (quickstart 5–6)

## Phase 6: US6 — البوابة
- [x] T020 [US6] حقل `performance` في `_buildSummaryData` (بالإعدادات المفعّلة) + إعادة نشر عند تغيير سويتش الواجب
- [x] T021 [US6] قسم "مستوى الطالب" في `booking_site/track/index.html` (SVG بسيط)
- [x] T022 **CHECKPOINT**: analyze + test

## Phase 7: Polish
- [x] T023 [P] `flutter analyze` + `flutter test` كاملين
- [ ] T024 بناء release وتجربة على جهاز (quickstart كامل)، تحديث `HANDOFF.md` والذاكرة، ونشر صفحة المتابعة بموافقة المستخدم

## Dependencies
T001←T002←T003. T005 بعد T001. T007/T008 بعد T005. T011–T014 بعد T007. T016 بعد T005. T018 بعد T011+T012+T016. T020 بعد T001+T002.

## MVP
T001–T015 (النواة + الشاشة + الإرسال لولي أمر واحد). المجموعة والبوابة بعده.
