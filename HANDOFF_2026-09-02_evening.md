# Handoff — جلسة 2 سبتمبر 2026 (مساءً)

> ملخّص للجلسة دي عشان نكمّل في محادثة جديدة. مبني على `HANDOFF.md` القديم.

---

## 0) الحالة الحالية

| | |
|---|---|
| الفرع | `main` (كل الشغل مباشرة عليه، متدفوع) |
| آخر كوميت | `cea4da6` — Update booking_site download APK to v1.2.41 |
| الإصدار | **1.2.41+59** (`pubspec.yaml`) |
| DB version | **22** (`DATABASE_VERSION` في `constants.dart`) — سبيك 013 ضاف عمود `exams.report_month` |
| `flutter analyze` | نضيف (صفر أخطاء/تحذيرات) |
| GitHub releases الحيّة | **v1.2.40** و **v1.2.41** بس (النسخ الوسيطة 1.2.37–39 اتمسحت — كانت تكرار سريع) |
| AAB لـ Play | آخر واحد اتبنى واتبعت للمستخدم = **1.2.40** (مش 1.2.41 لسه) |
| ملف untracked | `specs/015-billing-day-of-month/` (draft — مش implemented) |

---

## 1) اللي اتعمل الجلسة دي

### سبيك 013 — تناسق التقارير ✅ (كوميت `27943b5`)
DB v21→v22 (عمود `exams.report_month` nullable). 6 قصص:
- الطلاب المؤرشفين مستبعدين من شاشة التقارير
- التقارير/المدفوعات/تقرير المدفوعات/"تفاصيل الرسوم" بتفتح على **شهر التحصيل** عبر `lib/utils/billing_period.dart` → `defaultCollectionMonth()`
- دالة موحّدة `lib/utils/monthly_report_message.dart` → `buildMonthlyReportMessage()` بدل 3 نسخ مكرّرة؛ 3 مسارات واتساب (المجموعة / الإعدادات الجماعي / صفحة الطالب) فيها منتقي شهر
- كارت "دفعات [الشهر]" في الداشبورد — اتغيّر جذريًا الجلسة دي (شوف تحت)
- جداول PDF (حضور/واجب) بتعرض بس الأيام اللي فيها تسجيل
- عمود "شهر التقرير" للامتحان + كل فلترة امتحانات بالشهر بتتبعه

### سبيك 014 — تقارير الفترة المخصصة ✅ (نفس كوميت `27943b5`)
مفيش DB change. 3 قصص:
- شيت تصدير PDF في شاشة التقارير: مفتاح **شهر / فترة مخصصة**؛ وضع الفترة = منتقي من/إلى + حضور/واجب بس (تقرير الدفعات وملخص المجموعات مخفيين)
- جداول PDF بتفهرس بالتاريخ؛ ترويسة يوم/شهر في وضع الفترة
- `exportAttendancePDF`/`exportHomeworkPDF` بياخدوا `periodEnd` اختياري
- `buildMonthlyReportMessage` بياخد `periodStart/periodEnd` → عنوان فترة + **بدون قسم مالي** (أكاديمي بحت)
- صفحة الطالب: اختيار "تقرير شهر / تقرير فترة" قبل الإرسال
- تحذير قبل الفترات > 100 يوم؛ النطاق محدود لـ "النهاردة" عشان الـdate pickers ما تكسرش

### كارت "دفعات [الشهر]" في الداشبورد — 6 كوميتات تكرارية
تسلسل التطور (`dashboard_controller._computePaymentCard` + `home_page._PaymentProgressCard`):
1. `7fd83ad` — يعرض الشهر المختار وحده (مش تراكمي)
2. `87e3b8e` — سحب أفقي بدل السهمين + نقط + حدود التنقّل `[أقدم شهر عليه مستحق .. الشهر الحالي]`
3. `8e169a2` — طالب اتسجّل بعد الشهر مايتحسبش فيه
4. `113b07a` — توكن تسلسلي للسحب السريع + `paymentCardBusy` (تعتيم الأرقام أثناء الحساب) + عتبة سحب أخف
5. `43bbb6a` — **يحسب الشهر الكامل من أول يوم**: `expected = Σ monthlyDue(month)` لكل طالب مسجّل (مش `totalDueThrough` الفرق — عشان وضع "التحصيل المؤخّر" كان بيخلّي الشهر الجاري 0/0)؛ `collected` = FIFO؛ `unpaid` = مين ما غطّاش الشهر ده
6. `0df1b0a` — **"لم يدفع N" حسب الشهر المعروض** (بيختلف من شهر لشهر)؛ الشيت بيعرضهم بالمبلغ الناقص على الشهر ده وعنوانه فيه اسم الشهر
   + نفس الكوميت: تحديث التطبيق أثبت — زرار "حمّل من المتصفح" في `update_dialog.dart` + مهلات أطول (60ث بين الحزم / 5 دقايق إجمالي)

**النتيجة النهائية للكارت**: كل شهر مستقل؛ `المتوقع` = مجموع أسعار كل الطلاب المسجّلين للشهر من أول يوم؛ `المحصّل` يبدأ ~0 ويزيد؛ `لم يدفع` يبدأ ~الكل وينقص؛ وضع "التحصيل المؤخّر" مابيأثرش على الكارت (بيخص تنبيه "متأخر" بس).

### إصلاح "مفيش مديونية" بعد الدفع الجزئي ✅ (`88595f9`)
- `payments_page.dart`: صف الطالب كان بيحسب المتبقّي من `totalDueThrough(selectedMonth)` والـselectedMonth = شهر التحصيل (الشهر اللي فات) → طالب غطّى الشهر ده وعليه الجاري كان "مدفوع بالكامل" غلط. اتغيّر لـ `totalDueThrough(DateTime.now())` = نفس رقم تفاصيل الطالب
- `qr_controller._computeBaseAmount`: كان بيجمع `monthlyDue` للشهور المختارة من غير طرح المدفوع منها → لو دفعت جزء ورجعت تختار الشهر بيطلبه كامل. اتغيّر يطرح المدفوع (FIFO) للمجموعات الشهرية؛ بالحصة زي ما هي

---

## 2) سبيك 015 — يوم بداية دورة التحصيل (DRAFT — مش implemented)

`specs/015-billing-day-of-month/spec.md` — إعداد "يوم التحصيل" (D بدل 1)؛ دورة الفوترة `[D → D-1]` بدل `[1 → آخر الشهر]`. الافتراضي 1 = صفر تغيير.

**3 أسئلة clarify معلّقة** (لازم إجابات قبل `/speckit-plan`):
- **Q1**: مدى اليوم — 1–28 فقط / 1–31 مع تثبيت آخر يوم / 1–28 + خيار "آخر الشهر"
- **Q2**: تغيير اليوم بعد وجود بيانات — بأثر رجعي / للأمام فقط
- **Q3**: وضع الفريق — يتزامن / لكل جهاز / يتقفل لصاحب الترخيص

`.specify/feature.json` بيشاور على `specs/015-billing-day-of-month`.

**سياق**: المستخدم قال "خلاص سيبها دلوقتي" وراح يعمل نسخة Play. ممكن نرجعله.

### مؤجّل: فوترة بعدد الحصص
`specs/deferred-session-cycle-billing/` — "8 حصص = شهر". مؤجّل من قبل الجلسة دي. مش نفس 015 (015 عن إزاحة يوم البداية بس).

---

## 3) مهام يدوية على المستخدم

- **نشر `booking_site/` على active-class.online (VPS)** — الملف المتغيّر الوحيد كل مرة = `booking_site/downloads_ready/ActiveClass-arm64-v8a.apk` (محدّث لـ 1.2.41 في الريبو). البيئة هنا مقفولة على SSH لسيرفر خارجي؛ مفيش deploy script. المستخدم بيرفعه يدوي (rsync / لوحة استضافة / git pull على السيرفر). المسار على السيرفر: `/downloads/ActiveClass-arm64-v8a.apk`
- **رفع AAB على Play Console** — آخر AAB مبني = 1.2.40. لو عايز 1.2.41: `flutter build appbundle --release --flavor play` → `build/app/outputs/bundle/playRelease/app-play-release.aab`. versionCode لازم يبقى أعلى من آخر رفعة على Play
- **تجربة على الجهاز** — المستخدم جرّب 1.2.37 على بياناته الفعلية (156 طالب) والميجريشن v21→v22 عدّى تمام. النسخ الأحدث نفس DB v22

---

## 4) حقائق تقنية مهمة (نظام الفوترة)

- **`PricingHelper`** (`lib/utils/pricing_helper.dart`) — مصدر الحقيقة الوحيد لكل حسابات المديونية:
  - `monthlyDue(month)` — سعر شهر واحد. **مابيتحققش من تاريخ تسجيل الطالب** — بيرجّع السعر كامل لأي شهر. proration للشهر الأول بس لو `prorateFirstMonth`
  - `totalDueThrough(month)` — مجموع `monthlyDue` من شهر تسجيل الطالب لحد `_effectiveLastMonth(month)`. بيبدأ من التسجيل الفعلي (فمفيش عدّ لطالب اتسجّل بعد الشهر)
  - `_effectiveLastMonth(m)` — في وضع `billingArrears` بيقيّد بآخر شهر مكتمل (الشهر الحالي − 1). غير كده بيرجّع `m` زي ما هو
  - `accumulatedDebt` = `totalDueThrough(now) − Σ payments`, clamped ≥ 0
  - `isOverdue(graceDays)` — بيقيس على الشهر الحالي (أو السابق لو جوّه المهلة). **مابياخدش شهر معيّن كبارامتر**
- **الدفعات مالهاش "شهر" مخزّن** — `Payment` = تاريخ + مبلغ + `note` حر. توزيع الدفعة على الشهور استنتاج **FIFO** (الأقدم الأول). ده حدّ معروف في كل التطبيق
  - في بعض المسارات في الـ`note` فيه `months=YYYY-MM,...` و`sessions=N` و`custom=1` — بس شاشة الدفع اليدوي مابتكتبش `months=`
- **`billing_period.dart` منفصل عن `pricing_helper.dart`** — عشان `settings_controller` بيستورد `pricing_helper` (سبيك 012)، فحطّينا `defaultCollectionMonth()` في ملف تالت لتجنّب circular import
- **`_loadMonthStats` في `dashboard_controller`** — بقى فيه كود ميت (`monthExpected`/`monthPaid`/`unpaidStudentsCount`/`_unpaidList`) — مابقاش معروض في أي مكان بعد إعادة كتابة كارت الدفعات. آمن بس زيادة قراءات DB. تنضيف مؤجّل
- **الفلافورات**: `direct` (GitHub، فيه صلاحية التثبيت الذاتي) و `play` (Play، الصلاحية متشالة). `flutter build apk` بيبني الاتنين. للـPlay لازم `--flavor play` مع `appbundle`
- **التوقيع**: `android/app/upload-keystore.jks` + `android/key.properties` (متجاهلين من git — بياناتهم في `RELEASE_SIGNING_INFO.md`). لازم نفس الـkeystore كل مرة وإلا التثبيت فوق نسخة قديمة بيمسح البيانات
- **الـsandbox بيمنع SSH/curl لسيرفرات خارجية** — نشر الـVPS شغل المستخدم اليدوي
- **`WebFetch`** بيقرأ Firestore anonymously: `https://firestore.googleapis.com/v1/projects/active-class-72e0f/databases/(default)/documents/parent_portal/{slug}` (`parent_portal` عام؛ `licenses` محتاج auth → 403)

---

## 5) SpecKit — الاستخدام

- `.specify/scripts/powershell/*.ps1 -Json` (نستدعيهم بـ `powershell -NoProfile -File ...`)
- مفيش `.specify/extensions.yml` → كل الـhooks بتتخطّى
- ترقيم تسلسلي؛ `.specify/feature.json` بيشاور على السبيك النشط
- الدورة: `/speckit-specify` → (clarify يدوي بالجدول) → `/speckit-plan` → `/speckit-tasks` → `/speckit-implement`
- في skills-mode: `Skill` tool بـ `skill: "speckit-specify"` إلخ

---

## 6) خيوط مفتوحة

- **سبيك 015** — 3 أسئلة clarify (فوق). المستخدم أجّلها مؤقتًا
- **رسالة ترويجية / رد تلقائي فيسبوك** — المستخدم طلب نُسخ جاهزة، اتعملت في آخر الجلسة (مش في ملف — في المحادثة). لينك التحميل = `active-class.online`
- **تنضيف كود ميت** في `_loadMonthStats` (اختياري)
- **`update.json` على الـVPS** — اقتراح لتحديث أثبت (تحميل من سيرفر المستخدم بدل GitHub CDN البطيء من مصر) — مش مطلوب، اقتراح
