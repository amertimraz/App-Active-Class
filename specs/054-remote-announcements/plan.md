# Implementation Plan: إعلانات وبنر الخصومات عن بعد

**Branch**: `054-remote-announcements` | **Date**: 2026-10-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/054-remote-announcements/spec.md`

## Summary

مجموعة Firestore عامة `announcements` (مستند لكل إعلان) يكتبها الأدمن من صفحة جديدة في لوحة الأدمن (مشروع منفصل) ويقرؤها التطبيق مباشرة. التطبيق يختار **إعلانًا واحدًا** مناسبًا (منشور + ساري + باقة العميل ضمن الجمهور + المكان مفعّل) ويعرضه ببنر (6 تصاميم × 8 ألوان × فاتح/داكن) على الرئيسية والباقات، ونافذة مرة واحدة، وإشعار نظام (فحص دوري في الخلفية + عند الفتح). الزرار افتراضيًا يفتح واتساب برقم الأدمن ورسالة جاهزة تُلحَق بها بيانات المدرس. ويعمل أوفلاين بنسخة محفوظة. **لا خادم جديد**؛ التغيير الوحيد في الأمان قاعدة واحدة لـ`announcements`.

الاستراتيجية: منطق اختيار/صلاحية/عداد/رابط الواتساب/تحليل رد REST **دوال صرفة مختبَرة**؛ ويدجت البنر **Flutter صرف بلا GetX** عشان يُنسخ كما هو للأدمن للمعاينة فيطابق التطبيق تمامًا.

## Technical Context

**Language/Version**: Dart 3.5 / Flutter 3.38 (التطبيق والأدمن)

**Primary Dependencies**: GetX، `cloud_firestore`، `shared_preferences`، `workmanager` ^0.9، `flutter_local_notifications`، `url_launcher` (كلها موجودة). **لا إضافات جديدة** — الفحص الخلفي عبر `dart:io HttpClient` على Firestore REST (قراءة عامة).

**Storage**: Firestore `announcements/{id}` (جديد، عام للقراءة). محليًا: `SharedPreferences` (نسخة الإعلانات المخزَّنة، إغلاق البنر، آخر نافذة/إشعار، باقة العميل للفحص الخلفي). **لا تغيير في SQLite (DB v39)**.

**Testing**: `flutter test` — وحدة للدوال الصرفة + widget smoke لكل التصاميم/الألوان/الوضعين (التطبيق)، واختبار نموذج/تسلسل في الأدمن.

**Target Platform**: Android (التطبيق)؛ الأدمن Flutter Web/Windows.

**Project Type**: mobile-app + مشروع أدمن منفصل (مستودع git مستقل).

**Performance Goals**: بنر لا يكلّف فتح الشاشة الرئيسية؛ العداد يتحدّث كل ثانية بدون إعادة بناء الشاشة كلها؛ استعلام واحد صغير (حد أقصى 20 مستند).

**Constraints**: يعمل بلا نت؛ فشل القراءة صامت؛ إشعار الخلفية قد يتأخر (مقبول)؛ نص عادي بلا HTML؛ روابط http/https فقط.

**Scale/Scope**: ~10 ملفات جديدة في التطبيق، ~5 في الأدمن، تعديل شاشتين + `main.dart` + `NotificationService` + `LicenseController` (صغير).

## Constitution Check

`.specify/memory/constitution.md` قالب فارغ → لا بوابات رسمية. الالتزام بمبادئ المشروع العملية: (1) منطق صرف قابل للاختبار منفصل عن الواجهة، (2) لا تغيير schema/مزامنة، (3) عدم كسر سلوك قائم (المهمة الخلفية الشهرية تبقى كما هي)، (4) الفشل الصامت للميزات الاختيارية، (5) أمان: قراءة عامة + كتابة أدمن فقط، ومحتوى نصي فقط. **النتيجة: pass** (قبل وبعد التصميم).

## Project Structure

### Documentation (this feature)

```text
specs/054-remote-announcements/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/firestore-announcements.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code — التطبيق (`C:\repo\active_class`)

```text
lib/
├── models/announcement_model.dart          # جديد: Announcement + فك الحقول بتسامح + fromRestDoc
├── utils/announcement_logic.dart           # جديد (صرف): pick/isActive/audience/countdown/whatsappUri/safeUrl
├── services/announcement_service.dart      # جديد: قراءة Firestore + REST للخلفية + كاش محلي
├── controllers/announcement_controller.dart# جديد (GetX): العناصر + اختيار لكل مكان + إغلاق/نافذة/إشعار
├── widgets/
│   ├── announcement_banner.dart            # جديد: 6 تصاميم × 8 ألوان × فاتح/داكن (Flutter صرف — يُنسخ للأدمن)
│   └── announcement_popup.dart             # جديد: نافذة مرة واحدة
├── services/notification_service.dart      # تعديل: showAnnouncement + payload 'announcement'
├── controllers/license_controller.dart     # تعديل صغير: يكتب مفتاح الباقة في SharedPreferences عند التغيّر
├── views/home_page.dart                    # تعديل: بنر الرئيسية + نافذة أول فتح
├── views/license/plans_page.dart           # تعديل: بنر أعلى القايمة
└── main.dart                               # تعديل: تسجيل الـcontroller + فصل مهام workmanager + مهمة الإعلانات
firestore.rules                              # تعديل: match /announcements
test/
├── announcement_logic_test.dart
├── announcement_model_test.dart
├── announcement_banner_test.dart            # widget: 6×8×2 بدون overflow على عرض 320
└── announcement_controller_test.dart
```

### Source Code — لوحة الأدمن (`C:\repo\active_class_admin`، مستودع مستقل)

```text
lib/
├── models/announcement_model.dart          # نسخة بدالتي toMap/fromDoc
├── services/announcement_service.dart      # CRUD: watchAll / save / publish / duplicate / delete
├── widgets/announcement_banner.dart        # نسخة طبق الأصل من التطبيق (للمعاينة)
├── views/announcements_page.dart           # القائمة + المحرّر + المعاينة الحيّة
└── views/dashboard_page.dart               # تعديل: عنصر تنقّل "الإعلانات"
firestore.rules                              # تعديل: نفس قاعدة announcements
test/announcement_model_test.dart
```

**Structure Decision**: كل منطق قابل للاختبار في `lib/utils` (صرف)، والواجهة في `widgets/views`. البنر بلا GetX عشان نسخة واحدة تخدم المشروعين. ملف `firestore.rules` في المشروعين لازم يتطابق ويُنشر مرة واحدة.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| مشروعان (التطبيق + الأدمن) | الأدمن هو المكان الوحيد المخوَّل بالكتابة ومنه بتتحكم | صفحة ويب جديدة = مصادقة وصيانة إضافية |
| نسخ ويدجت البنر للأدمن | معاينة مطابقة 100% للتطبيق | حزمة مشتركة = تغيير بنية لمشروعين من غير داعٍ الآن |
| فحص REST خلفي بدل `cloud_firestore` | عزل الخلفية بدون تهيئة Firebase الكاملة وأخف | `Firebase.initializeApp` في isolate الخلفية أثقل وأقل ثباتًا |
