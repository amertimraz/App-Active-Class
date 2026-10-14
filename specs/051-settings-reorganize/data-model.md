# Data Model: إعادة تنظيم شاشة الإعدادات

**لا تغيير في قاعدة البيانات ولا في المزامنة ولا في مفاتيح الإعدادات.** النموذج أدناه **بيانات وصفية في الكود فقط** (تحت `lib/views/settings/settings_registry.dart`) لتغذية الشاشة الرئيسية والبحث واختبار الجرد.

## SettingsCategory

| الحقل | النوع | ملاحظة |
|---|---|---|
| `id` | `String` | ثابت (`account`, `attendance`, `billing`, `whatsapp`, `followup`, `appearance`, `data`, `about`) |
| `title` | `String` | الاسم المعروض |
| `subtitle` | `String` | سطر وصف قصير |
| `icon` | `IconData` | أيقونة الفئة |
| `color` | `Color` | لون الأيقونة (نفس ألوان الأقسام الحالية) |
| `order` | `int` | ترتيب الظهور في الرئيسية |

## SettingsItem

| الحقل | النوع | ملاحظة |
|---|---|---|
| `id` | `String` | ثابت وفريد (`attendance.recitation_max` …) |
| `categoryId` | `String` | فئة واحدة بالظبط |
| `section` | `String?` | قسم فرعي داخل الفئة (مثلاً `ورقة الحضور`، `ماسح QR`، `منطقة الخطر`) |
| `title` | `String` | نفس العنوان المعروض (للبحث) |
| `keywords` | `List<String>` | مرادفات بحث (مثلاً التسميع: `حفظ`, `درجة`) |
| `kind` | `SettingsItemKind` | `switchTile`, `dropdown`, `nav`, `field`, `info` |
| `visibility` | `SettingsVisibility` | `always`, `hiddenForAssistant`, `ownerOnlyAction`, `portalAddonOnly` |
| `parentId` | `String?` | للعناصر المشروطة (مدة التأخير تحت `qr_auto_late`) |

## SettingsVisibility (مطابق للشروط الحالية في الكود)

| القيمة | معناها | أمثلة |
|---|---|---|
| `always` | بتظهر دايمًا | العملة، الوضع الليلي |
| `hiddenForAssistant` | بيانات المعلم للقراءة بس للمساعد | حقول بيانات المعلم |
| `ownerOnlyAction` | مرئي لكن التنفيذ يتطلب مالك الفريق (`requireTeamOwnerIfTeamMode`) | استعادة نسخة، حذف جميع البيانات |
| `portalAddonOnly` | بتظهر لو إضافة البوابة مفعّلة على الترخيص | متابعة أولياء الأمور |

## دوال صرفة

- `searchSettings(String query, {required bool isAssistant, required bool portalEnabled}) → List<SettingsItem>`
- `normalizeArabic(String) → String` (تشكيل/ألف/ياء/تاء مربوطة/أرقام)
- `itemsOfCategory(String categoryId) → List<SettingsItem>`

## ثوابت الجرد (يحرسها الاختبار)

| النوع | العدد |
|---|---|
| `switchTile` | 20 |
| `dropdown` | 13 |
| `nav` | 9 |
| عناصر أخرى (`field`/`info`: بيانات المعلم، الإصدار، إلخ) | تُحصى في الاختبار كما في الجرد |

(المصدر: تفاصيل العناصر في [contracts/settings-registry.md](contracts/settings-registry.md).)
