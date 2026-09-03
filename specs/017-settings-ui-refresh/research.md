# Phase 0 — Research: تطوير واجهة الإعدادات

كل قرارات النطاق اتحسمت مع المستخدم. تفاصيل تقنية محلولة تحت.

## R1 — نمط التنسيق الموحّد موجود بالفعل

**Decision**: إعادة استخدام `_buildSection(context, isDark, {title, icon, color, children, collapsible, initiallyExpanded})` كما هو — عنده ترويسة (أيقونة في مربّع `alpha 0.12` radius 10 + عنوان `w900`) وكارت `radius 22` بظل وحدود، ووضع قابل للطي عبر `ExpansionTile`.

**Rationale**: FR-004/FR-005 (ترويسة موحّدة + مسافات متّسقة) تتحقّق تلقائيًا لو كل قسم يمرّ من نفس الـhelper. مفيش داعي لنمط جديد. الشغل = ترتيب الاستدعاءات + توحيد `SizedBox(height: 14)` بين الأقسام + توحيد `_buildDivider` بين البنود.

**Alternatives considered**: widget ترويسة جديد — مرفوض، ازدواج.

## R2 — إعدادات الفوترة داخل قسم "الواتساب"

**Decision**: القسم الحالي "الواتساب" (سطر ~274) فيه 3 بنود فوترة/تحصيل تُنقل لقسم جديد "الفوترة والتحصيل":
- "مهلة السماح قبل «متأخر»" (`settings.paymentGraceDays`)
- "تحصيل مؤخّر (بالمنقضي)" (`settings.billingArrears`)
- "حساب نسبي للشهر الأول" (`settings.prorateFirstMonth`)

يفضل في "الواتساب والتقارير": إرسال تقارير الشهر، زر الواتساب في المجموعات + يوم ظهوره، تقرير بعد اكتمال الحضور.

**Rationale**: FR-003 + SC-005. البنود تُنقل **حرفيًا** (نفس `Obx`/`_buildSwitchTile`/`_buildDropdownTile` والـcallbacks) — نسخ-لصق لقسم تاني، صفر تغيير منطق.

**Alternatives considered**: ترك مهلة "متأخر" في الواتساب — مرفوض، هي عن ظهور الطالب "متأخر" (تحصيل).

## R3 — قسم "الإضافات المدفوعة"

**Decision**: قسم موحّد يجمع:
- بوابة متابعة أولياء الأمور — الـ`Obx` الحالي (سطر ~107) كما هو، مع تاريخ الانتهاء (سبيك 016) داخله.
- **بند جديد**: nav tile "إعدادات الحجوزات" → `Get.to(() => const BookingSettingsPage())` — يظهر لو `LicenseController.to.canBooking` (نفس نمط الحراسة الحالي). صفحة الحجوزات نفسها **بدون تغيير**.

**Rationale**: FR-001 بند 8. الحجوزات حاليًا مدفونة في `bookings_page.dart` بس — إضافة اختصار من الإعدادات لطيفة ومنخفضة المخاطرة (nav لصفحة موجودة).

**Alternatives considered**: نقل كل إعدادات الحجوزات لـsettings_page — مرفوض، نطاق أكبر ومخاطرة.

## R4 — فتح قناة الواتساب

**Decision**: `_openCommunityChannel()` = نسخة مبسّطة من `_openSupportWhatsApp` (سطر ~1041):
```
const kCommunityChannelUrl = 'https://whatsapp.com/channel/0029VbDFTCsEquiR7nSaO52X';
try { await launchUrl(Uri.parse(kCommunityChannelUrl), mode: LaunchMode.externalApplication); }
catch (_) { ToastHelper.error('تعذّر فتح القناة، حاول تاني'); }
```
`LaunchMode.externalApplication` بيحاول واتساب الأول ثم المتصفح (سلوك النظام)، فالبديل مغطّى (FR-011).

**Rationale**: نفس نمط `_openSupportWhatsApp`/`_openPrivacyPolicy` الموجود — متّسق ومجرّب.

## R5 — الطي الافتراضي

**Decision**:
- **مفتوح**: بيانات المدرس، العملة، الفوترة والتحصيل، الإضافات المدفوعة، المجتمع والدعم.
- **مطويّ افتراضيًا** (`collapsible: true, initiallyExpanded: false`): الواتساب والتقارير (زي دلوقتي)، الإشعارات، ماسح QR، المظهر والتوقيت، المساعدين والحسابات، النسخ الاحتياطي، عن التطبيق.

**Rationale**: FR-007 — تقصير الشاشة؛ الأقسام الأساسية اليومية مفتوحة، التقنية مطويّة. المستخدم يفتح اللي يحتاجه.

## R6 — لا تغييرات قاعدة بيانات ولا controller

**Decision**: `DATABASE_VERSION` يفضل 23. لا لمس `settings_controller.dart`. كل `rxValue`/`onChanged` تُنقل كما هي.

**Rationale**: SC-006. الميزة تنظيم عرض + بند واحد جديد.
