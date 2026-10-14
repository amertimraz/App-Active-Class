# Tasks: إعادة تنظيم شاشة الإعدادات

**Input**: `specs/051-settings-reorganize/` (plan.md, spec.md, research.md, data-model.md, contracts/settings-registry.md, quickstart.md)

**Tests**: اختبار وحدة للسجل والبحث (جرد 20/13/9 + معرّفات فريدة) + تحقق يدوي على الجهاز. بلا DB/migration/مزامنة.

**ملحوظة تنفيذ (2026-10-14)**: الاستخراج اتعمل بـ`part`/`part of` بدل ودجتس public: الملفات الجديدة جزء من نفس الـlibrary (`settings_page.dart`)، والدوال اللي كانت instance methods بقت top-level خاصة بنفس الاسم والجسم (نقل حرفي بلا أي تعديل). النتيجة: صفر تغيير سلوكي وأكبر ملف 664 سطر. T026: الأوصاف الموجودة أصلًا كفاية، وسطر تأخّر الدفع اتحدّث.

**القاعدة الذهبية**: نقل حرفي — ممنوع تغيير منطق أي إعداد أو مفتاح تخزين أو قيمة افتراضية أو `SettingsController`. كل مرحلة تنتهي بـ`flutter analyze` نضيف والتطبيق شغّال. الشاشة القديمة تفضل شغّالة لحد مرحلة التبديل (T020).

## Format: `[ID] [P?] [Story] Description`
- **[P]**: ممكن بالتوازي (ملفات مختلفة بلا اعتماد)
- أرقام الأسطر = `lib/views/settings/settings_page.dart` الحالي (قبل أي نقل) — راجع `contracts/settings-registry.md`

---

## Phase 1: Setup

- [X] T001 سجّل خط الأساس: قيم الإعدادات الحالية على الجهاز + `flutter analyze` + `flutter test` (عدّاد الأخطاء/الاختبارات) كمرجع مقارنة بعد التنفيذ.
- [X] T002 [P] أنشئ مجلدات `lib/views/settings/{widgets,categories,actions,dialogs}/` (فاضية بـ`.gitkeep` لو لزم).

---

## Phase 2: Foundational (يمنع أي story قبل ما يخلص)

**الهدف**: استخراج المشترَكات من `settings_page.dart` بنقل حرفي، بحيث الصفحة القديمة تستدعيها وتفضل شغّالة بنفس السلوك.

- [X] T003 `lib/views/settings/widgets/settings_widgets.dart`: حوّل `_buildSection` (1076) و`_buildSwitchTile` (1546) و`_buildNavTile` (1603) و`_buildDropdownTile<T>` (1667) و`_buildInfoTile` (1729) و`_buildTextField` (1774) و`_buildDivider` (1824) لودجتس/دوال top-level (`SettingsSectionCard`, `SettingsSwitchTile`, `SettingsNavTile`, `SettingsDropdownTile<T>`, `SettingsInfoTile`, `SettingsTextField`, `SettingsDivider`) بنفس البارامترات والشكل. شمل `_CollapsibleSection` (3394) و`_IconBtn` (2535) و`_GenderChip` (2584) لو الصفحات الجديدة بتحتاجهم.
- [X] T004 [P] `lib/views/settings/dialogs/backup_dialogs.dart`: انقل `_BackupListDialog` (2874) و`_ManageBackupsDialog` (+State، 2958) و`_DataSummaryList` (2793) و`_ChoiceButton` (2816) و`_InfoRow` (2770) كما هي (تعريفها public داخل الملف الجديد).
- [X] T005 [P] `lib/views/settings/dialogs/parent_portal_tile.dart`: انقل `_ParentPortalTile` (+State، 3154–3393) كما هو.
- [X] T006 `lib/views/settings/actions/backup_actions.dart`: انقل `_handleEnhancedBackup` (1838) و`_handleRestoreBackup` (1919) و`_reloadAllControllers` (2082) و`_handleManageBackups` (2121) و`_handleCloudBackup` (2149) و`_fmtCloudBackupTime` (2347) و`_confirmCloudRestore` (2358) و`_handleDeleteAll` (2392) كدوال top-level تاخد `BuildContext` + `SettingsController` (حسب الحاجة)، بلا أي تعديل في المنطق.
- [X] T007 [P] `lib/views/settings/actions/whatsapp_batch_send.dart`: انقل `_startWhatsappBatchSend` (2436) و`sendMonthlyReportsViaWhatsAppAuto` (2759) و`_ResumeObserver` (2738) والدالة المساعدة للانتظار (2750). حدّث `lib/main.dart:28/107` ليستورد الدالة من مكانها الجديد. شغّل: ضغط إشعار تقارير الشهر ما يوقعش.
- [X] T008 حدّث `lib/views/settings/settings_page.dart` ليستخدم الملفات الجديدة (T003–T007) بدل الدوال/الكلاسات الخاصة، وبدون أي تغيير في ترتيب أو شكل الشاشة. **CHECKPOINT**: `flutter analyze` نضيف + الإعدادات تفتح وتشتغل زي ما كانت (تحقق سريع على الجهاز).

---

## Phase 3: User Story 1+2 — شاشة الفئات + كل إعداد في مكانه (P1) 🎯 MVP

**الهدف**: الشاشة الرئيسية = قائمة فئات، وكل فئة صفحتها بإعداداتها في المكان الصحيح (US1: الفئات الواضحة، US2: التوزيع المنطقي).

**اختبار مستقل**: افتح الإعدادات ← 8 فئات ← كل فئة تفتح بإعداداتها حسب `contracts/settings-registry.md` وبترجع بزر الرجوع.

- [X] T009 [US1] `lib/views/settings/settings_registry.dart`: عرّف `SettingsCategory` و`SettingsItem` و`SettingsItemKind` و`SettingsVisibility` و`kSettingsCategories` (8 فئات: id/اسم/وصف/أيقونة/لون/ترتيب حسب data-model.md) و`kSettingsItems` (كل عناصر الجرد بمعرّفات ثابتة `category.item`). بدون أي import لـGetX (صرف).
- [X] T010 [P] [US1] `test/settings_registry_test.dart`: جرد (20 switch / 13 dropdown / 9 nav)، معرّفات فريدة، كل `categoryId` موجود، ولا فئة بلا عناصر، `parentId` يشاور لعنصر موجود. شغّله وتأكد إنه ناجح.
- [X] T011 [US1] `lib/views/settings/widgets/settings_category_scaffold.dart`: هيكل صفحة الفئة (نفس خلفية/AppBar الصفحة الحالية، عنوان الفئة، ListView، دعم `highlightId` اختياري) + `lib/views/settings/widgets/settings_category_tile.dart`: صف فئة (أيقونة + اسم + وصف + سهم RTL).
- [X] T012 [P] [US2] `lib/views/settings/categories/account_team_category.dart`: بيانات المعلم (`_buildTeacherSection` 1159–1396 كما هو بقيد المساعد) + المساعدين والحسابات (94–119) + متابعة أولياء الأمور (120–155، بشرط `parentPortalEnabled`).
- [X] T013 [P] [US2] `lib/views/settings/categories/attendance_category.dart`: قسم "ورقة الحضور" (تنبيه المتأخر 730، الواجب 788، التسميع + الدرجة العظمى 802/819، التفاعل 846، الغياب التلقائي + المهلة 861/877) + قسم "ماسح QR" (إخفاء الحضور 697، إخفاء الدفع 683، قارئ خارجي 712، متأخر تلقائي + المهلة 745/761). الشروط (`Obx`) كما هي.
- [X] T014 [P] [US2] `lib/views/settings/categories/billing_category.dart`: العملة (167)، مهلة السماح (234)، التحصيل المؤخّر (263)، يوم النزول (284–344 بالتعطيل والرسالة)، الحساب النسبي (346)، وتأخّر الدفع (487 — منقول من المتابعة).
- [X] T015 [P] [US2] `lib/views/settings/categories/whatsapp_category.dart`: رمز دولة الواتساب (195 — منقول من العملة)، إرسال تقارير الشهر (587)، زر المجموعات (607)، يوم ظهور الزر (629)، تقرير بعد الحضور (656).
- [X] T016 [P] [US2] `lib/views/settings/categories/followup_category.dart`: عتبات الغياب/الواجب/الدرجات (380–484) + مدة التهدئة (498) + مركز الإشعارات (563). (سطر "تأخّر الدفع من الفلوس" يتضاف في T024.)
- [X] T017 [P] [US2] `lib/views/settings/categories/appearance_category.dart`: الوضع الليلي (527) + نظام الساعة (538).
- [X] T018 [P] [US2] `lib/views/settings/categories/data_category.dart`: الحفظ التلقائي (920)، إنشاء/استعادة/إدارة النسخ (938/957/976)، السحابي (987). **بدون** عناصر الحذف (تتضاف في T022).
- [X] T019 [P] [US2] `lib/views/settings/categories/about_category.dart`: الإصدار (1415)، تحقق من التحديثات (1426)، تواصل معنا (1437)، سياسة الخصوصية (1446)، قناة المجتمع (1502) — نقل `_buildAboutSection` و`_buildCommunitySection` وما بيستخدموه (`_openCommunityChannel` 1458، `_openPrivacyPolicy` 1514، `_openSupportWhatsApp` 1524).
- [X] T020 [US1] بدّل `lib/views/settings/settings_page.dart`: `SettingsPage` يعرض `LicenseStatusTile` + قائمة الفئات (من `kSettingsCategories` بـ`SettingsCategoryTile`) والدخول بـ`Get.to`. احذف الأقسام القديمة المتكرّرة من الملف (تبقى `build` الجديدة فقط). **CHECKPOINT**: analyze نضيف + quickstart 1–9 على الجهاز.

---

## Phase 4: User Story 3 — منطقة الخطر (P2)

**اختبار مستقل**: فئة البيانات فيها قسمين: العادي، و"منطقة الخطر" بتمييز.

- [X] T021 [US3] أضف في `lib/views/settings/widgets/settings_widgets.dart` ودجت `SettingsDangerZone` (حدّ/عنوان أحمر "منطقة الخطر" + وصف قصير).
- [X] T022 [US3] في `data_category.dart` أضف داخل `SettingsDangerZone`: "حذف سجلّات بمدى تواريخ" (999 ← `DeleteRecordsPage`) و"حذف جميع البيانات" (1011 ← `requireTeamOwnerIfTeamMode` + `handleDeleteAll`) بنفس خطوات التأكيد. **CHECKPOINT**: quickstart 8.

---

## Phase 5: User Story 4 — الأهم أولًا + تسميات وأوصاف (P2)

**اختبار مستقل**: كل فئة مرتّبة بالأكتر استخدامًا، والغامض عنده وصف، والتعطيل بسببه.

- [X] T023 [US4] رتّب العناصر داخل كل فئة حسب الأهمية (اليومي أولًا، الإعدادات النادرة في قسم فرعي مطويّ لو لزم) وحدّث `order` في السجل.
- [X] T024 [US4] في `followup_category.dart` أضف صف تنقّل "تأخّر الدفع بيتظبط من الفلوس والتحصيل" يفتح `billing_category` مع `highlightId = billing.at_risk_payment`.
- [X] T025 [US4] حدّث نص "بنفس مهلة السماح في قسم الفوترة فوق" (493) ليصير "بنفس مهلة السماح فوق" داخل فئة الفلوس؛ وراجع أي نص يشاور على مكان قديم ("فوق"/"تحت"/اسم قسم).
- [X] T026 [P] [US4] أضف سطر وصف قصير بالمصري للإعدادات الغامضة (التحصيل المؤخّر، الحساب النسبي، يوم النزول، قارئ الباركود الخارجي، مهلة الغياب التلقائي …) من غير تغيير سلوكها، ووحّد استخدام `SettingsSwitchTile`/`SettingsDropdownTile` في كل الصفحات.

---

## Phase 6: User Story 5 — البحث (P3)

**اختبار مستقل**: كتابة "تسميع" ← نتايج ← ضغط ← صفحة الفئة بتمييز.

- [X] T027 [US5] في `settings_registry.dart` أضف `normalizeArabic` و`searchSettings(query, {isAssistant, portalEnabled})` (حد أدنى حرفين، مطابقة العنوان والكلمات المفتاحية، احترام `SettingsVisibility`) وأضف `keywords` لكل عنصر (مثلاً التسميع: حفظ/درجة/تسميع).
- [X] T028 [P] [US5] وسّع `test/settings_registry_test.dart`: تطبيع التشكيل/الألف/الياء/التاء المربوطة، "تسميع" يرجّع عنصريّن، كلمة بلا نتيجة ترجّع فاضي، والمساعد ما يشوفش `portalAddonOnly` لو البوابة مقفولة.
- [X] T029 [US5] صف بحث في `settings_page.dart` فوق الفئات؛ النتايج قائمة (اسم الإعداد + الفئة)، الضغط يفتح الفئة بـ`highlightId`؛ حالة "مفيش إعداد مطابق". طبّق التمييز في `SettingsCategoryScaffold` (`Scrollable.ensureVisible` + خلفية ثانيتين). **CHECKPOINT**: quickstart 10.

---

## Phase 7: Polish

- [X] T030 تنظيف: احذف أي كود ميت/imports مش مستخدمة من `settings_page.dart` (هدف: ≈150 سطر)، وتأكد إن ولا ملف في `lib/views/settings/` يفوق ~1000 سطر (SC-007).
- [X] T031 `flutter analyze` + `flutter test` كاملين: لا errors/warnings جديدة، كل الاختبارات ناجحة (اللي عند خط الأساس + الجديدة).
- [ ] T032 تحقق يدوي على الجهاز حسب `quickstart.md` كامل (1–12) بما فيه وضع المساعد والترقية بالقيم المحفوظة والوضع الليلي وRTL وإشعار تقارير الشهر.
- [X] T033 حدّث `HANDOFF.md` (قسم Spec 051) وذاكرة المشروع، وسجّل الملفات الجديدة والدوال العامة المنقولة.

---

## Dependencies & Execution Order

- **Phase 1** ← بلا اعتماد.
- **Phase 2** (T003–T008) يمنع كل ما بعده. T004/T005/T007 [P] بعد T003 (أو بالتوازي لو مفيهمش اعتماد)؛ T008 بعد T003–T007.
- **Phase 3**: T009 ← T010/T011؛ T012–T019 [P] بعد T003 + T011؛ T020 بعد T012–T019. هي الـMVP (US1+US2).
- **Phase 4** (US3) بعد T018+T020. **Phase 5** (US4) بعد T020. **Phase 6** (US5) بعد T009+T020 (مستقل عن Phase 4/5). **Phase 7** بعد المرغوب منهم.

### Parallel Opportunities
- T012–T019 (كل فئة ملف مستقل) تتعمل بالتوازي بعد T011.
- T010 مع T011.
- T026 مع T024/T025 (ملفات/نصوص مختلفة).

## Implementation Strategy

1. **MVP (US1+US2)**: Phase 1 → 2 → 3. بعد T020 الشاشة الجديدة بفئاتها كاملة وشغّالة (مع البحث والـdanger لسه ناقصين). اعمل commit + جرّب على الجهاز.
2. **US3** (منطقة الخطر) ثم **US4** (ترتيب/أوصاف) ثم **US5** (بحث) كل واحدة commit مستقل.
3. أي regression في أي مرحلة = ارجع لـcommit المرحلة اللي قبلها (كل مرحلة تطبيق شغّال).

## Notes
- ممنوع تعديل `SettingsController` أو `DatabaseService` أو `sync_engine` أو أي مفتاح `SETTING_*` في الـspec ده.
- لو اتغيّر ترتيب/اسم في السجل، حدّث `contracts/settings-registry.md` معاه.
