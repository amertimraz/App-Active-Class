# Active Class — نظرة عامة على المشروع

تطبيق Flutter لإدارة الفصول الدراسية، مصمم للمعلمين لإدارة المجموعات والطلاب والحضور والمدفوعات بواجهة عربية كاملة (RTL).

---

## المحتويات

1. [معلومات عامة](#1-معلومات-عامة)
2. [هيكل المجلدات](#2-هيكل-المجلدات)
3. [المعماريّة](#3-المعمارية)
4. [قاعدة البيانات](#4-قاعدة-البيانات)
5. [الصفحات والميزات](#5-الصفحات-والميزات)
6. [المكونات المشتركة](#6-المكونات-المشتركة)
7. [الخدمات](#7-الخدمات)
8. [الحالة والتنقل](#8-الحالة-والتنقل)
9. [الثيم والتصميم](#9-الثيم-والتصميم)
10. [التبعيات الرئيسية](#10-التبعيات-الرئيسية)
11. [ميزات خاصة](#11-ميزات-خاصة)

---

## 1. معلومات عامة

| الحقل | القيمة |
|---|---|
| اسم التطبيق | Active Class |
| الوصف | تطبيق إدارة الفصول الدراسية |
| الإصدار | 1.0.0+1 |
| Flutter SDK | ^3.5.4 |
| اللغة | العربية (ar / ar_SA) |
| الخط | Cairo (Regular 400, Bold 700) |
| الاتجاه | RTL |

---

## 2. هيكل المجلدات

```
lib/
├── config/
│   ├── constants.dart          # ثوابت التطبيق (مسارات، ألوان، مخطط DB)
│   └── theme.dart              # تعريف الثيم الفاتح والداكن (Material 3)
│
├── controllers/
│   ├── attendance_controller.dart    # CRUD الحضور + فلترة + ترتيب
│   ├── dashboard_controller.dart     # إحصاءات الرئيسية
│   ├── group_controller.dart         # إدارة المجموعات
│   ├── payment_controller.dart       # إدارة المدفوعات
│   ├── qr_controller.dart            # منطق مسح QR
│   ├── report_controller.dart        # توليد التقارير
│   ├── settings_controller.dart      # إعدادات المستخدم ومعلومات المعلم
│   ├── student_controller.dart       # إدارة الطلاب + توليد QR
│   └── theme_controller.dart         # حفظ واسترجاع الثيم
│
├── models/
│   ├── attendance_model.dart   # نموذج الحضور (حاضر / غائب)
│   ├── group_model.dart        # نموذج المجموعة
│   ├── payment_model.dart      # نموذج الدفعة
│   └── student_model.dart      # نموذج الطالب (إخوة، ولي الأمر، تاريخ الميلاد)
│
├── services/
│   ├── backup_service.dart     # نسخ احتياطي + استعادة DB
│   ├── database_service.dart   # عمليات SQLite (Singleton)
│   └── notification_service.dart # إشعارات محلية وتذكيرات
│
├── views/
│   ├── attendance/
│   │   └── attendance_page.dart       # تبويبات: اليوم / السجلات / الإحصاء / QR
│   ├── groups/
│   │   ├── groups_page.dart           # قائمة/شبكة المجموعات مع CRUD
│   │   └── group_details_page.dart    # تفاصيل مجموعة + تسجيل حضور جماعي
│   ├── payments/
│   │   └── payments_page.dart         # دفعات بالشهر والمجموعة
│   ├── qr_scanner/
│   │   ├── qr_scanner_attendance_page.dart    # مسح QR للحضور
│   │   ├── qr_scanner_payment_page.dart       # مسح QR للدفع
│   │   ├── code39_scanner_payment_page.dart   # مسح باركود Code39
│   │   └── qr_gallery_page.dart               # معرض QR وتصدير PDF
│   ├── reports/
│   │   ├── reports_page.dart          # لوحة الإحصاءات
│   │   └── payments_report_page.dart  # تقارير الدفعات (شهري / يومي)
│   ├── students/
│   │   ├── students_page.dart         # قائمة/شبكة الطلاب مع CRUD
│   │   └── student_details_page.dart  # ملف الطالب + الحضور + الدفعات
│   ├── settings/
│   │   ├── settings_page.dart                   # الإعدادات العامة
│   │   └── notification_settings_page.dart      # إعدادات الإشعارات
│   ├── home_page.dart          # الرئيسية: 8 بطاقات تنقل + إحصاءات
│   └── splash_page.dart        # شاشة البداية (1.7 ثانية)
│
└── widgets/
    ├── app_chrome.dart         # AppBar متدرج + خلفيات
    ├── custom_dialogs.dart     # Dialogs (تأكيد، تاريخ، طالب، مجموعة...)
    └── custom_widgets.dart     # StatsCard, CustomTextField, EmptyState
```

---

## 3. المعمارية

**النمط:** GetX MVC

```
Views  ──Obx()──►  Controllers  ──async──►  Services / Database
                       │
                     Models
```

- **Models:** كلاسات بيانات بسيطة مع `toMap()` / `fromMap()` / `copyWith()`
- **Controllers:** تمتد `GetxController`، تحتوي متغيرات `Rx<T>` تفاعلية
- **Views:** `StatefulWidget` في الغالب، تستخدم `Obx()` للتحديث التلقائي
- **Services:** Singletons لقاعدة البيانات والإشعارات والنسخ الاحتياطي
- **Dependency Injection:** `Get.put()` عند التسجيل، `Get.find()` عند الاستخدام

---

## 4. قاعدة البيانات

**المحرك:** SQLite (sqflite)  
**الاسم:** `active_class.db`  
**الإصدار:** 7 (مع دعم الـ migrations)

### الجداول

#### `groups` — المجموعات التدريسية
| العمود | النوع | ملاحظة |
|---|---|---|
| id | INTEGER PK | |
| name | TEXT UNIQUE | اسم المجموعة |
| code | TEXT UNIQUE | رمز المجموعة |
| price | REAL | السعر الافتراضي |
| color | INTEGER | لون (قيمة Color) |
| icon | TEXT | أيقونة |
| schedule | TEXT | JSON أيام الجدول |
| created_at | TEXT | |

#### `students` — الطلاب
| العمود | النوع | ملاحظة |
|---|---|---|
| id | INTEGER PK | |
| name | TEXT | |
| code | TEXT UNIQUE | بادئة المجموعة + رقم تسلسلي |
| group_id | INTEGER FK | CASCADE على الحذف |
| price | REAL | سعر خاص (يعيد تعريف سعر المجموعة) |
| qr_path | TEXT | مسار صورة QR |
| sibling_id | INTEGER | ربط بالأشقاء |
| siblings_total | INTEGER | عدد الأشقاء |
| attendance_start | TEXT | تاريخ بداية احتساب الحضور |
| guardian_phone | TEXT | رقم ولي الأمر |
| birth_date | TEXT | تاريخ الميلاد |
| created_at | TEXT | |

#### `attendance` — الحضور
| العمود | النوع | ملاحظة |
|---|---|---|
| id | INTEGER PK | |
| student_id | INTEGER FK | CASCADE على الحذف |
| date | TEXT | |
| status | TEXT | `حاضر` أو `غائب` |
| notes | TEXT | ملاحظات (مثلاً "تم عبر QR") |
| created_at | TEXT | |
| — | UNIQUE(student_id, date) | منع التكرار |

#### `payments` — المدفوعات
| العمود | النوع | ملاحظة |
|---|---|---|
| id | INTEGER PK | |
| student_id | INTEGER FK | CASCADE على الحذف |
| date | TEXT | |
| amount | REAL | > 0 |
| note | TEXT | |
| created_at | TEXT | |

#### `report_logs` — سجل إرسال التقارير
| العمود | النوع | ملاحظة |
|---|---|---|
| id | INTEGER PK | |
| student_id | INTEGER FK | |
| month_start | TEXT | |
| sent_at | TEXT | |
| — | UNIQUE(student_id, month_start) | |

---

## 5. الصفحات والميزات

### الرئيسية (`home_page.dart`)
- 8 بطاقات تنقل ملونة (مجموعات، مدفوعات، حضور، طلاب، تقارير، معرض QR، إشعارات، إعدادات)
- Drawer جانبي
- خلفية متدرجة مع توهج متحرك

### المجموعات (`groups_page.dart`)
- عرض قائمة / شبكة مع تبديل
- إضافة / تعديل / حذف مجموعات
- بحث بالاسم
- عرض عدد الطلاب والجدول

### تفاصيل المجموعة (`group_details_page.dart`)
- قائمة طلاب المجموعة
- وضع التحديد لتسجيل حضور جماعي
- تتبع الطلاب المدفوعين شهرياً
- تصدير QR للمجموعة

### الطلاب (`students_page.dart`)
- عرض قائمة / شبكة مع تبديل
- CRUD كامل + بحث وفلترة
- توليد كود الطالب (بادئة المجموعة + رقم تسلسلي)
- إنشاء QR فوري

### تفاصيل الطالب (`student_details_page.dart`)
- الملف الشخصي (اسم، كود، مجموعة، سعر)
- سجل الحضور (تبويبات: حاضر / غائب / الكل)
- سجل الدفعات مع الترتيب
- مشاركة تقرير شهري عبر WhatsApp
- عرض QR + الاتصال بولي الأمر

### الحضور (`attendance_page.dart`)
- **اليوم:** تسجيل سريع مرتّب حسب المجموعة
- **السجلات:** سجل تاريخي مع فلتر نطاق التاريخ
- **الإحصاءات:** نسبة الحضور لكل مجموعة
- **QR:** ماسح QR آني للحضور
- تصدير PDF + فلتر المجموعة/الحالة + تراجع الحذف

### المدفوعات (`payments_page.dart`)
- اختيار الشهر والمجموعة
- قائمة الطلاب بالمبلغ المتوقع مقابل المدفوع
- مؤشر ملون: مدفوع كامل / جزئي / غير مدفوع
- حوار إضافة دفعة + بحث

### ماسح QR للحضور (`qr_scanner_attendance_page.dart`)
- مسح آني + بحث يدوي
- تسجيل تلقائي بملاحظة "تم عبر QR"

### ماسح QR للدفع (`qr_scanner_payment_page.dart`)
- تسجيل دفع بعد المسح
- اختيار الشهر + تعديل المبلغ + منع المسح المكرر (500ms)

### ماسح Code39 (`code39_scanner_payment_page.dart`)
- مسح باركود Code39 مع احتياطي OCR (ML Kit)

### معرض QR (`qr_gallery_page.dart`)
- عرض QR لجميع الطلاب مع فلتر المجموعة والبحث
- تصدير PDF جماعي + حفظ PNG فردي للجهاز

### التقارير (`reports_page.dart`)
- إجمالي المجموعات / الطلاب / الدفعات / نسبة الحضور
- آخر السجلات

### تقارير الدفعات (`payments_report_page.dart`)
- **شهري:** حالة دفع الطلاب + مشاركة WhatsApp
- **يومي:** تفصيل دفعات كل يوم

### الإعدادات (`settings_page.dart`)
- تبديل الثيم (فاتح / داكن)
- العملة (19 خيار: SAR, EGP, AED, KWD...)
- صيغة الوقت (12h / 24h)
- معلومات المعلم (اسم، صورة، تخصص، هاتف، بريد، مدرسة)
- نسخ احتياطي / استعادة
- حذف جميع البيانات

### إعدادات الإشعارات (`notification_settings_page.dart`)
- تذكير أعياد الميلاد
- تذكير مواعيد الحصص
- تذكير التأخر في الدفع
- أزرار اختبار لكل نوع

---

## 6. المكونات المشتركة

### `widgets/custom_widgets.dart`
| المكون | الوصف |
|---|---|
| `StatsCard` | بطاقة إحصاء متحركة (أيقونة + عنوان + قيمة + لون) |
| `CustomTextField` | حقل نص مُنسَّق مع تحقق، أيقونة، دعم متعدد الأسطر |
| `EmptyState` | أيقونة + عنوان + زر عمل عند عدم وجود بيانات |
| `SectionHeader` | رأس قسم بعنوان وعنوان فرعي |

### `widgets/app_chrome.dart`
| الدالة | الوصف |
|---|---|
| `buildGradientAppBar()` | AppBar بتدرج لوني مخصص |
| `buildScreenBackground()` | خلفية شاشة بتدرج |
| `buildSoftBackground()` | غلاف بخلفية ناعمة |
| `buildSoftPanel()` | بطاقة بظل وحدود ناعمة |
| `buildSectionHeader()` | رأس قسم قابل للإعادة |

### `widgets/custom_dialogs.dart`
| الـ Dialog | الوصف |
|---|---|
| `ConfirmDeleteDialog` | تأكيد الحذف |
| `DatePickerDialog` | اختيار تاريخ (ar locale) |
| `ConfirmDialog` | تأكيد عام مع أيقونة |
| `PaymentDialog` | إدخال دفعة (أشهر، مبلغ، ملاحظة) |
| `AttendanceDialog` | تسجيل حضور (حاضر / غائب) |
| `StudentDialog` | إضافة / تعديل طالب |
| `GroupDialog` | إضافة / تعديل مجموعة |

---

## 7. الخدمات

### `DatabaseService` (Singleton)
- CRUD كامل للكيانات الأربعة
- استعلامات متقدمة: `getStudentsByGroup`، `getPaymentsByStudent`...
- تجميعات: نسب الحضور، إجمالي المدفوعات
- عمليات مجمّعة بـ transactions
- Migrations من v1 إلى v7

### `NotificationService` (Singleton)
- إشعارات محلية (Android + iOS)
- دعم المنطقة الزمنية (Asia/Riyadh)
- تذكير أعياد الميلاد (7 أيام مسبقاً)
- تذكير مواعيد الحصص (حسب اليوم)
- طلب صلاحيات تلقائي

### `BackupService` (Singleton)
- نسخ ملف DB إلى التخزين الخارجي
- استعادة DB من ملف
- تصدير JSON لجميع البيانات

---

## 8. الحالة والتنقل

### إدارة الحالة — GetX
```dart
// الإعلان في Controller
final RxList<Student> students = <Student>[].obs;
final RxString filterGroup = ''.obs;
final RxBool sortAsc = false.obs;

// في View
Obx(() => ListView(children: controller.students.map(...).toList()))
```

**النمط:** فلاتر + ترتيب في `Rx` objects، دالة `_applyFilter()` تُعاد عند أي تغيير.

### التنقل — GetX Named Routes
```dart
Get.toNamed(Routes.STUDENTS)          // تنقل عادي
Get.toNamed(Routes.STUDENT_DETAILS, arguments: student)  // مع بيانات
Get.back()                             // رجوع
```

مسارات التطبيق معرّفة في `lib/config/constants.dart` وتشمل 15+ مساراً.

---

## 9. الثيم والتصميم

| العنصر | القيمة |
|---|---|
| Framework | Material 3 |
| اللون الأساسي | Indigo 600 |
| خلفية داكنة | `0xFF1E293B` |
| الخط | Cairo |
| لون الخطأ | Red |
| لون النجاح | Emerald |
| لون التحذير | Amber |
| ارتفاع Navigation Bar | 65px |

يُحفظ اختيار الثيم في `SharedPreferences` ويُدار عبر `ThemeController`.

---

## 10. التبعيات الرئيسية

| الحزمة | الإصدار | الاستخدام |
|---|---|---|
| `get` | 4.6.0 | State management + Navigation |
| `sqflite` | 2.3.0 | قاعدة البيانات المحلية |
| `path_provider` | 2.1.0 | مسارات الملفات |
| `shared_preferences` | 2.3.2 | التخزين المحلي البسيط |
| `qr_flutter` | 4.1.0 | توليد QR |
| `mobile_scanner` | 7.1.3 | مسح QR/Barcode |
| `google_mlkit_text_recognition` | 0.14.0 | OCR للباركود |
| `pdf` + `printing` | 3.10.0 / 5.11.0 | تصدير PDF |
| `flutter_local_notifications` | 17.2.3 | إشعارات محلية |
| `workmanager` | 0.9.0+3 | مهام خلفية دورية |
| `timezone` | 0.9.4 | دعم المناطق الزمنية |
| `flutter_spinkit` | 5.2.0 | مؤشرات التحميل |
| `fl_chart` | 0.68.0 | رسوم بيانية |
| `flutter_animate` | 4.5.0 | تأثيرات حركية |
| `share_plus` | 10.0.0 | مشاركة الملفات |
| `image_picker` | 1.0.7 | اختيار الصور |
| `media_store_plus` | 0.1.3 | حفظ للمعرض |
| `permission_handler` | 12.0.1 | صلاحيات النظام |
| `intl` | 0.20.2 | تنسيق التاريخ والأرقام |
| `url_launcher` | 6.3.0 | فتح WhatsApp / مكالمة |
| `dio` | 5.3.0 | HTTP (غير مستخدم حالياً) |

---

## 11. ميزات خاصة

### QR كامل الدورة
- توليد QR لكل طالب بكوده
- تصدير PNG بمعلومات الطالب إلى معرض الجهاز
- تصدير PDF جماعي
- مسح للحضور ومسح للدفع

### تكامل WhatsApp
- مشاركة تقارير شهرية مباشرةً عبر WhatsApp
- إرسال تلقائي عند نهاية الشهر بواسطة Workmanager
- إعادة محاولة الإرسال عند فتح التطبيق

### دعم الأشقاء
- ربط الطلاب الأشقاء بمعرّف مشترك
- إمكانية تسجيل دفعات/حضور جماعي للأشقاء

### العمليات الجماعية
- تسجيل حضور جماعي لكامل المجموعة
- تصدير QR جماعي لمجموعة أو كل الطلاب

### النسخ الاحتياطي
- نسخ ملف قاعدة البيانات
- تصدير JSON لجميع البيانات
- استعادة كاملة من ملف النسخة

### العملات المدعومة
SAR، EGP، AED، KWD، QAR، BHD، OMR، JOD، MAD، TND، DZD، LYD، IQD، LBP، SYP، YER، SDG، MRU، USD
