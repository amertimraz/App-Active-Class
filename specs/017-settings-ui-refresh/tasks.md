---
description: "Task list — تطوير واجهة الإعدادات + قناة المجتمع (017-settings-ui-refresh)"
---

# Tasks: تطوير واجهة الإعدادات + قناة المجتمع

**Input**: Design documents from `specs/017-settings-ui-refresh/`
**Prerequisites**: plan.md, spec.md, research.md, contracts/, quickstart.md

**Tests**: لا بنية اختبار آلي — تحقّق يدوي عبر [quickstart.md](quickstart.md) + `flutter analyze` صفر تحذيرات.

**Organization**: قصتان P1. **كل الشغل في ملف واحد** `lib/views/settings/settings_page.dart` — فالمهام تسلسلية غالبًا (نفس الملف). لا تغيير على `settings_controller` ولا قاعدة البيانات.

## Path Conventions

Mobile single-project. الملف الوحيد: `lib/views/settings/settings_page.dart`.
المرجع الملزم: [contracts/settings-layout.md](contracts/settings-layout.md) (جدول الترتيب + كود قسم المجتمع).

---

## Phase 1: Setup

- [ ] T001 في `lib/views/settings/settings_page.dart` (أعلى الكلاس، جنب باقي الثوابت أو داخل الـState): أضف `static const String _kCommunityChannelUrl = 'https://whatsapp.com/channel/0029VbDFTCsEquiR7nSaO52X';`.

---

## Phase 2: Foundational (Blocking Prerequisites)

- [ ] T002 راجع `_buildSection` (سطر ~664) و`_buildDivider` و`_buildNavTile` و`_buildSwitchTile` و`_buildDropdownTile` — تأكّد إنها كلها بتاخد `isDark` وبترجّع widget مستقل (هي كده). **لا تعديل** — بس تأكيد إن إعادة الترتيب هتعيد استخدامهم كما هم.

**Checkpoint**: الـhelpers جاهزة لإعادة الاستخدام.

---

## Phase 3: User Story 1 - شاشة إعدادات مرتّبة ومتناسقة (Priority: P1) 🎯 MVP

**Goal**: الأقسام بالترتيب المحدّد، نمط ترويسة موحّد، الفوترة في قسمها المستقل.

**Independent Test**: quickstart سيناريوهات 1–4 و6.

- [ ] T003 [US1] في `settings_page.dart` قسم "الواتساب" (سطر ~274): **انقل** الثلاث بنود دي **كما هي بالظبط** (نفس `Obx`/`_buildSwitchTile`/`_buildDropdownTile` والـcallbacks والـsubtitles) لقائمة مؤقتة/متغيّر عشان نستخدمهم في T004:
  - "مهلة السماح قبل «متأخر»" (`settings.paymentGraceDays`, dropdown)
  - "تحصيل مؤخّر (بالمنقضي)" (`settings.billingArrears`, switch)
  - "حساب نسبي للشهر الأول" (`settings.prorateFirstMonth`, switch)
  وشِل الـ`_buildDivider`s الزيادة اللي كانت بينهم داخل قسم الواتساب. القسم يبقى اسمه "الواتساب والتقارير" ويحتوي فقط: إرسال تقارير الشهر، زر الواتساب في المجموعات + يوم ظهوره، تقرير بعد اكتمال الحضور.
- [ ] T004 [US1] في `settings_page.dart`: أنشئ قسم جديد `_buildSection(... title: 'الفوترة والتحصيل', icon: Icons.payments_rounded, color: Color(0xFF10B981), children: [...] )` يحتوي البنود الـ3 من T003 مفصولة بـ`_buildDivider(isDark)`. ضع الاستدعاء في `build()` بعد قسم "العملة" مباشرة (البند 3 في [العقد](contracts/settings-layout.md)).
- [ ] T005 [US1] في `settings_page.dart`: وسّع قسم "الإضافات المدفوعة" — لفّ `Obx` بوابة الأهالي الحالي (سطر ~107) داخل `_buildSection(title: 'الإضافات المدفوعة', icon: Icons.workspace_premium_rounded, color: Color(0xFF8B5CF6), children: [...])`. أضف داخله `Obx` تاني: لو `LicenseController.to.canBooking` (تحقّق من اسم الـgetter الصحيح — ممكن يكون `canBooking` أو عبر `_remoteLimits`) → `_buildNavTile(... title: 'إعدادات الحجوزات', icon: Icons.event_available_rounded, onTap: () => Get.to(() => const BookingSettingsPage()))` — استورد `BookingSettingsPage` من `lib/views/bookings/booking_settings_page.dart`. لو القسمين مخفيين → القسم كله يرجّع `SizedBox.shrink()`.
- [ ] T006 [US1] في `settings_page.dart` `build()` → قائمة `ListView` children: **أعد ترتيب** استدعاءات الأقسام لتطابق جدول [العقد](contracts/settings-layout.md) بالظبط (0..12)، مع `const SizedBox(height: 14)` موحّد بين كل قسم والتالي. لا تغيّر محتوى أي قسم — بس مكانه.
- [ ] T007 [US1] في `settings_page.dart`: طبّق سياسة الطي من [research R5](research.md#r5--الطي-الافتراضي) — `collapsible: true, initiallyExpanded: false` للأقسام: الواتساب والتقارير، الإشعارات، ماسح QR، المظهر والتوقيت، المساعدين والحسابات، النسخ الاحتياطي، عن التطبيق. `collapsible: false` (أو `initiallyExpanded: true`) للأقسام: بيانات المدرس، العملة، الفوترة والتحصيل، الإضافات المدفوعة، المجتمع والدعم.

**Checkpoint**: الترتيب صحيح، الفوترة في قسمها، صفر إعداد مفقود.

---

## Phase 4: User Story 2 - الانضمام لقناة التحديثات والدعم (Priority: P1)

**Goal**: قسم "المجتمع والدعم" فوق الإصدار بزر يفتح قناة الواتساب.

**Independent Test**: quickstart سيناريو 5.

- [ ] T008 [US2] في `settings_page.dart`: أضف دالة `Future<void> _openCommunityChannel() async` — `try { await launchUrl(Uri.parse(_kCommunityChannelUrl), mode: LaunchMode.externalApplication); } catch (_) { ToastHelper.error('تعذّر فتح القناة، حاول تاني'); }` (نفس نمط `_openSupportWhatsApp` سطر ~1041).
- [ ] T009 [US2] في `settings_page.dart`: أضف `_buildCommunitySection(context, isDark)` يرجّع `_buildSection(title: 'المجتمع والدعم', icon: Icons.forum_rounded, color: Color(0xFF25D366), children: [Padding(all 16, child: Column([نص شرح, SizedBox(12), SizedBox(width: infinity, child: FilledButton.icon(onPressed: _openCommunityChannel, style: backgroundColor 0xFF25D366 + foregroundColor white, icon: Icon(Icons.chat_rounded), label: 'انضم لقناة التحديثات والدعم'))]))])`. النص: "قناة التحديثات والدعم — تابع الجديد، وشارك مشاكلك واقتراحاتك مع مجتمع المدرسين."
- [ ] T010 [US2] في `settings_page.dart` `build()`: أضف استدعاء `_buildCommunitySection(context, isDark)` + `SizedBox(height: 14)` **فوق** قسم "عن التطبيق" مباشرة (البند 11 في العقد).

**Checkpoint**: قسم المجتمع ظاهر ويفتح القناة.

---

## Phase 5: Polish & Cross-Cutting

- [ ] T011 `flutter analyze` — صفر أخطاء/تحذيرات. أصلح أي import غير مستخدم (لو `BookingSettingsPage` اتضاف) أو تحذير.
- [ ] T012 تحقّق بصري في الوضعين (فاتح/ليلي): كل قسم بترويسة موحّدة، مسافات `14` متساوية بين الأقسام، `_buildDivider` متساوٍ بين البنود، مفيش نص مقصوص على شاشة صغيرة / خط نظام كبير.
- [ ] T013 نفّذ [quickstart.md](quickstart.md) سيناريوهات 1–6. تأكيد: عدد الإعدادات القابلة للتفاعل قبل = بعد (+ زر القناة)، وكل تبديل/قائمة بيحفظ ويعرض نفس التنبيه زي قبل.
- [ ] T014 [P] حدّث ملاحظات الجلسة/الهاندوف: إعادة ترتيب الإعدادات + قسم "المجتمع والدعم" + رابط القناة الثابت.

---

## Dependencies & Execution Order

- **Phase 1 (T001)**: فورًا.
- **Phase 2 (T002)**: تأكيد فقط.
- **US1 (T003–T007)**: تسلسلي — كلها نفس الملف، وT004 يعتمد على T003، T006 يعتمد على T004/T005. **MVP**.
- **US2 (T008–T010)**: بعد US1 (عشان `build()` يكون اتعاد ترتيبه) — أو بالتوازي منطقيًا لكن نفس الملف فتسلسلي عمليًا.
- **Polish (T011–T014)**: بعد US1+US2.

### تسلسل القصص

US1 و US2 مستقلتان وظيفيًا لكن نفس الملف — تُنفَّذان بالترتيب. US1 وحدها = شاشة مرتّبة (MVP). US2 يضيف قسم المجتمع.

### فرص التوازي

محدودة (ملف واحد). T014 بس متوازي.

---

## Implementation Strategy

### MVP (US1)

Phase 1 → 2 → 3. عند اكتمال US1: شاشة إعدادات مرتّبة بالترتيب الجديد والفوترة في قسمها. **قف وتحقّق** (سيناريوهات 1–4) قبل US2.

### تدريجي

1. Setup + T003–T007 → شاشة مرتّبة.
2. T008–T010 → قسم المجتمع + القناة.
3. Polish → analyze + quickstart.

---

## Notes

- **صفر تغيير سلوك** — كل `rxValue`/`onChanged`/شرط إظهار يُنقل حرفيًا (T003 خطر رئيسي — انسخ الـ`Obx` بالكامل).
- لا `settings_controller`، لا DB، `DATABASE_VERSION` يفضل 23.
- commit بعد US1 وبعد US2.
- تأكّد من اسم getter الحجوزات في `LicenseController` قبل T005 (grep `canBooking`).
