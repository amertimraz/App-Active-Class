# Data Model: مدة تفعيل بوابة متابعة أولياء الأمور

## 1. `licenses/{code}` (Firestore — موجود بالفعل، حقل جديد بس)

| الحقل | النوع | الوصف |
|---|---|---|
| `parentPortalEnabled` | `boolean` | موجود بالفعل — "هل الإضافة مفعّلة أصلاً" (مستقل عن المدة) |
| `parentPortalExpiresAt` | `timestamp \| null` | **جديد**. `null` = مدى الحياة (الافتراضي — مطابق للمستندات الحالية من غير أي migration). موجود = البوابة "شغالة فعليًا" لحد التاريخ ده بس، بشرط `parentPortalEnabled == true` أيضًا. |

**قاعدة "شغالة فعليًا"**: `parentPortalEnabled == true AND (parentPortalExpiresAt == null OR parentPortalExpiresAt > now)`.

يعدّله المطور يدويًا (نفس أسلوب `expiresAt`/`status`/`durationDays` الحاليين على نفس المستند) وقت تفعيل/تجديد الإضافة لمدرس.

## 2. `LicenseController` (Dart — تعديل)

| العضو | النوع | الوصف |
|---|---|---|
| `parentPortalEnabled` | `RxBool` | موجود بالفعل |
| `parentPortalExpiresAt` | `Rxn<DateTime>` | **جديد** — بيتقرأ من `licenses/{code}.parentPortalExpiresAt` في `_validateLicense` و`_watchLicense`، بنفس نمط `expiresAt` العام |
| `parentPortalActiveNow` | `bool` (getter محسوب، مش Rx) | **جديد** — `parentPortalEnabled.value && (parentPortalExpiresAt.value == null \|\| parentPortalExpiresAt.value!.isAfter(DateTime.now()))` |
| تايمر دوري داخلي (5 دقايق) | — | **جديد** — بيعيد تقييم/إشعار المستمعين طول ما الترخيص نشط، عشان `Obx` المبنية على `parentPortalActiveNow` تتحدّث حتى بدون حدث Firestore جديد (قرار 3 في research.md) |

## 3. `ParentPortalService` (Dart — تعديل)

كل الأماكن الأربعة اللي بتفحص `LicenseController.to.parentPortalEnabled.value` (`publishProfile`, `pushStudentSummary`, وحارسين تانيين) تتحول لـ`LicenseController.to.parentPortalActiveNow`.

مستمع جديد (`ever()`) على `parentPortalEnabled`/`parentPortalExpiresAt` بينادي `publishProfile()` تلقائيًا عند أي تغيير — عشان التجديد بعد انتهاء ينعكس بسرعة على الصفحة العامة (قرار 4).

## 4. `parent_portal/{slug}` (Firestore — موجود بالفعل، حقل جديد بس)

| الحقل | النوع | الوصف |
|---|---|---|
| `teacherName`, `teacherGender`, `ownerUid`, `deviceId`, `updatedAt` | — | موجودين بالفعل |
| `parentPortalExpiresAt` | `string (ISO) \| null` | **جديد** — نسخة منشورة من نفس القيمة في `licenses/{code}`، للقراءة العامة من `track/index.html` بدون وصول لمجموعة `licenses` المحمية |

## 5. `track/index.html` (خارج هذا المستودع — VPS)

منطق جديد في `init()`: لو `profileSnap.data().parentPortalExpiresAt` موجود و`new Date(...) < new Date()` → اعرض شاشة "الخدمة غير متاحة حاليًا" بدل الفورم، ووقف — مفيش أي محاولة قراءة لأي مستند طالب.

## Settings UI (`settings_page.dart` — تعديل سطر واحد)

شرط ظهور قسم "متابعة أولياء الأمور" يتحول من `parentPortalEnabled.value` إلى `parentPortalActiveNow`.
