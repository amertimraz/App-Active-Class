# Active Class — Handoff (محادثة جديدة)

> آخر تحديث: 2026-09-16. المشروع: `C:\repo\active_class` — تطبيق Flutter عربي/RTL للمدرّسين الخصوصيين.
> كلّمني عربي (مصري). Flutter 3.38.1 / Dart 3.5.4، GetX، sqflite، Firebase (بوابة أولياء الأمور + امتحانات أونلاين)، Supabase self-hosted على VPS (مزامنة وضع الفريق).
> **آخر إصدار منشور رسميًا: v1.2.65+4083 — DB version = 33. منشور على GitHub Release (3 APKs: arm64/armeabi-v7a/x86_64) + مرفوع على VPS (arm64) + `.aab` مبني وجاهز لرفعه يدويًا على Google Play Console (لسه ماترفعش).**

### 📦 إصدار v1.2.65+4083 — منشور بالكامل (2026-09-16 مسائية)
- **GitHub Release**: https://github.com/amertimraz/App-Active-Class/releases/tag/v1.2.65 — 3 APKs (arm64-v8a, armeabi-v7a, x86_64)، توقيع متحقَّق (`5f74fe10af2da396cbf0a98895af02bb5ffbdc01cdf68a55bea25a841f02ec7b`).
- **VPS**: `/var/www/active-class.online/downloads/ActiveClass-arm64-v8a.apk` مُحدَّث (النسخة القديمة v1.2.62 اتحفظت `.bak-1.2.62`).
- **Google Play**: `.aab` مبني في `release_assets/v1.2.65/ActiveClass-play.aab` (66.4MB) — **لسه محتاج رفع يدوي من المستخدم على Play Console** (ده بره صلاحيات الأتمتة).
- **Git tag**: `v1.2.65` (annotated) مدفوع على `origin`.
- بناء الـAAB وقع بـOOM مرتين متتاليتين حتى بعد قفل تطبيقات تقيلة (الذاكرة كانت بترجع لـ~4 جيجا وتنزل تاني بسرعة بسبب عمليات `dartaotruntime`/`java` عالقة من المحاولة الفاشلة السابقة) — الحل اللي نجح: `Stop-Process -Force` على `dartaotruntime` و`java` العالقين قبل إعادة المحاولة الثالثة.

---

## ✅ جلسة 2026-09-16 (مسائية، تكملة) — spec 037: نسخ احتياطي سحابي (Google Drive شخصي) — **متنفّذ ومتحقَّق بالكامل على جهاز حقيقي (T001–T027 ✅)**

**تحقّق جهازي فعلي (بعد 3 مشاكل اتصلّحت أثناء التجربة الحية):**
1. **رفع تلقائي/يدوي حقيقي نجح** — لوج مؤكَّد: `metadata response: 200` → `upload content response: 200` → `upload SUCCESS`. نسخة حقيقية (445 كيلوبايت) اترفعت فعليًا لـGoogle Drive المدرّس.
2. **استعادة من السحابة على نفس الجهاز نجحت** — المستخدم أكّد "شغاله".
3. **باج حقيقي اتصلّح أثناء التجربة**: عداد إعادة المحاولة (`pendingRetries`) كان بيقفل زرار "رفع الآن" **اليدوي** بصمت (بلا أي توست) بعد ما يوصل 5 فشلات — من غير أي طريقة يرجع بيها المستخدم غير انتظار "الدور الدوري". الإصلاح: الحد الأقصى بقى يُطبَّق بس على المحاولات **التلقائية** (`isAutomatic=true`)؛ ضغطة يدوية صريحة تتجاوزه دايمًا. راجع `google_drive_backup_service.dart` — تعليق يوضّح السبب.
4. **إضافة تسجيل تشخيصي دائم** (`debugPrint('[CloudBackup] ...')`) في كل خطوة من `uploadBackup`/`_accessToken` — ده اللي كشف باج الـ#3 فورًا، وهيفيد أي تشخيص مستقبلي (بيظهر في `adb logcat` حتى على release، زي `AuthService` قبل كده).
5. **مشكلة إعداد (مش كود)**: أول محاولة رفع فشلت بـ`403 SERVICE_DISABLED` — الـOAuth client اتعمل ظاهريًا تحت مشروع "app-active-class"، لكن Google رجّع الخطأ لمشروع رقمي مختلف (194296515569) لحظيًا — بعد التأكد إن Drive API فعلاً مفعّلة ومطابقة على نفس المشروع والانتظار دقايق (نشر/propagation)، اشتغل عادي. **لو الباج ده اتكرر لاحقًا لمستخدم تاني، الرسالة نفسها من Google بتدّي رابط تفعيل مباشر — كفاية.**
6. **حادث جانبي أثناء التجربة (مش متعلق بالكود الجديد)**: المستخدم بالغلط استعاد نسخة احتياطية **محلية قديمة فاضية** (من قائمة "النسخ المحفوظة") فوق بياناته الحقيقية (166 طالب) ووضع الفريق اتقفل. **الحل الآمن اللي استُخدم**: تسجيل خروج من "المساعدين والحسابات" ثم تسجيل دخول تاني — ده بينادي تلقائيًا `TeamModeService.restoreForCurrentUser()` (بيدوّر على الفريق الموجود فعلاً عند الحساب ويسحب كل البيانات من السيرفر) — **مش** `enableAsOwner()` (بينشئ فريق جديد فاضي ويعزل الفريق الحقيقي). ⚠️ **درس مهم يتوثّق لأي جلسة جاية**: لو مستخدم استعاد بالغلط نسخة قديمة ومسحت بيانات الفريق محليًا، الحل هو "تسجيل خروج ثم دخول تاني"، **أبدًا مش** الضغط على "تفعيل وضع الفريق" من تاني.
7. **بناء الـrelease وقع بـOOM 5 مرات متتالية** أثناء الجلسة (نفس الباج المعروف من قبل) — اتصلّح بس بعد ما المستخدم قفل تطبيقات/تابات تقيلة (الذاكرة الفاضية رجعت من ~1 جيجا لـ~4.7 جيجا).

**الإصدار النهائي المتحقَّق:** v1.2.65+4083 (نفس رقم النسخة عبر كل محاولات البناء المتتالية أثناء التشخيص — لسه محتاج bump قبل أي نشر رسمي).

**الطلب:** المستخدم طلب ميزة نسخ احتياطي سحابي. بعد نقاش، الوجهة اتحدّدت: **Google Drive شخصي لكل مدرّس** (حسابه هو، مش سيرفر Supabase المشترك) — مستقلة تمامًا عن وضع الفريق، متاحة لأي مستخدم للتطبيق.

**السبيك الكامل:** `specs/037-cloud-backup/` (spec.md + plan.md + research.md + data-model.md + contracts/ + quickstart.md + tasks.md، T001–T025 ✅).

**إعداد يدوي اتعمل خلال الجلسة (Google Cloud Console، مشروع `app-active-class`):**
- Google Drive API مفعّلة.
- OAuth consent screen: External، نطاق `.../auth/drive.file` بس (غير حسّاس — بلا مراجعة أمان طويلة من جوجل).
- Android OAuth client ID: package `com.amertimraz.activeclass` + SHA-1 لنفس كيستور الـrelease (`FA:37:95:25:3F:48:62:F0:C1:86:97:61:F0:8E:6D:6C:30:65:1A:6D`) → Client ID: `194296515569-34mrb5gs1e06bvodi0jbt6ut9oa67l5o.apps.googleusercontent.com`.
- **⚠️ لو التطبيق اتنشر على Google Play بـ"Play App Signing" مفعّل، بصمة SHA-1 هتبقى مختلفة لمستخدمي الـPlay — محتاج Android client تاني ببصمة Play (من Play Console → App integrity) وقت النشر هناك.**

**التنفيذ (لب-وضع Google Drive API v3 مباشرة عبر `dio`، بلا مكتبة `googleapis` — راجع research.md #2):**
- `lib/services/google_drive_backup_service.dart` (جديد): `linkAccount`/`unlinkAccount`/`uploadBackup`/`listCloudBackups`/`restoreFromCloud`/`deleteCloudBackup`. الرفع بخطوتين (`POST files` metadata ثم `PATCH upload?uploadType=media` بايتات) بدل multipart/related يدوي؛ فشل الخطوة التانية بيمسح الملف الفاضي. `restoreFromCloud` بيحمّل الملف مؤقتًا وينادي `BackupService().restoreBackup(...)` **الموجودة بالفعل** (بلا تكرار كود). تنظيف تلقائي لأقدم نسخة عند تجاوز 5 نسخ.
- `lib/utils/cloud_backup_retry_policy.dart` + `test/cloud_backup_retry_policy_test.dart` (4 اختبارات) — حد 5 محاولات فشل متتالية قبل التوقف لحد النسخة الدورية الجاية.
- `lib/controllers/google_drive_backup_controller.dart` (جديد، GetX) — حالة الربط + قائمة النسخ.
- `lib/services/auto_backup_service.dart`: بعد نجاح نسخة محلية دورية، رفع سحابي **fire-and-forget** (`unawaited`) — صفر تأثير على تسلسل النسخ المحلي لو فشل.
- `lib/views/settings/settings_page.dart`: قسم جديد "النسخ السحابي (Google Drive)" (شيت: ربط/إلغاء ربط + رفع الآن + قائمة نسخ بتاريخ/حجم + استعادة بتحذير صريح + حذف) بجانب قسم النسخ المحلي الموجود.
- `pubspec.yaml`: تبعية جديدة `google_sign_in: ^6.2.1` (حُلّت 6.3.0) — أول تبعية خدمة خارجية (غير Supabase) في المشروع.

**التحقّق:** `flutter analyze` = 34 (baseline، صفر جديد). `flutter test` = **165/165** ✅ (161 + 4 جديدة). بُنيت v1.2.65+4083 (release، نفس التوقيع `5f74fe10...` تأكّد).

**⚠️ لسه محتاج (T026):** تحقّق جهازي حقيقي بحساب Google حقيقي — **لازم APK release موقّع بنفس الكيستور** (مش debug، وإلا تسجيل الدخول بيفشل `DEVELOPER_ERROR`). سيناريوهات `quickstart.md` 1–7 (ربط، رفع تلقائي، استرجاع على جهاز جديد/حساب مختلف، سحب الصلاحية، انقطاع نت). **بعد الحادثة اللي حصلت أول الجلسة (مسح بيانات بسبب debug build)، مفيش أي تثبيت على جهاز المستخدم الحقيقي من غير إذن صريح كل مرة.**

**متبقّي:** commit + التحقّق الجهازي (T026) + نشر v1.2.65 لاحقًا.

---

## ✅ جلسة 2026-09-16 (مسائية) — إصلاح باج "تنبيه المتأخر في الدفع" + spec 036 (v1.2.63+4081، جهاز اختبار بس)

### إصلاح باج حقيقي — تنبيه "متأخر في الدفع" في شاشة الحضور كان مش بيظهر أبدًا لأي طالب (spec 029 كان معطوب من وقت ما اتعمل)

**البلاغ:** المستخدم طلب ميزة "يظهرلي جمب اسم الطالب في شاشة الحضور لو عليه مدفوعات" — واكتشفنا إنها ميزة موجودة بالفعل (spec 029) لكن **مش شغالة خالص**، لطالبتين معروف إنهم متأخرين فعليًا (ملك جمال سباعي، ملك هشام شريف — 130 ج لكل واحدة).

**السبب:** `lib/widgets/overdue_warning_badge.dart` (`OverdueWarningFor`) كان بيبعت `payCtrl.payments` — **كل مدفوعات المدرسة (كل الـ166 طالب)** — لـ`PricingHelper.showsAttendanceOverdueWarning`/`accumulatedDebt`. الدالة الداخلية `_remainingThrough` بتجمع كل عنصر في القايمة اللي بتوصلها **من غير فلترة بالطالب** (`payments.fold(...)`) — فكانت بتجمع ~10.4 ألف جنيه (كل المدرسة) وتطرحها من مستحق طالب واحد → الناتج دايمًا صفر → البادج ميظهرش لأي حد، مهما كان متأخر فعلاً. الأماكن التانية اللي بتستخدم نفس الدالة (`qr_controller.dart`) كانت بتفلتر صح (`getPaymentsByStudent`)، وده اللي كشف الفرق.

**الإصلاح:** فلترة `payCtrl.payments` على `student.id` قبل ما تتبعت لـ`PricingHelper` — سطرين بس في `overdue_warning_badge.dart`.

**تحقّق جهازي:** بعد بناء ونشر v1.2.63+4081 على جهاز `9aecbc89`، البادج ظهر صح لـ"ملك جمال سباعي" و"ملك هشام شريف" (⚠️ متأخر 130.00 لكل واحدة) في مجموعة "الصف الأول الثانوي".

**⚠️ حادث أثناء التشخيص (درس مهم):** لتشخيص المشكلة اتشغّلت نسخة `flutter run --debug` على الجهاز — ده مسح بيانات التطبيق المحلية بالكامل مرتين (توقيع debug مختلف عن release → أندرويد بيعمل uninstall إجباري). البيانات رجعت في المرتين عن طريق مزامنة الفريق (Supabase). **الدرس: ممنوع تشغيل build/run بتوقيع مختلف عن الـrelease الحالي على جهاز إنتاج المستخدم بدون إذن صريح ومؤكد كل مرة — حتى لو الهدف مجرد تشخيص.** لأي تشخيص مستقبلي: تعديل الكود + بناء release بنفس الكيستور + تثبيت كـupdate عادي (`adb install -r`، بلا uninstall) هو الطريق الآمن الوحيد.

### spec 036 — ملخص تفصيلي لكارت دفعات الشهر (تفصيل حسب المجموعة) — **متنفّذ بالكامل (T001–T017)، لسه محتاج تحقّق جهازي (T018)**

**الطلب:** الضغط على كارت "دفعات [الشهر]" في الصفحة الرئيسية يفتح شيت ملخص تفصيلي: الإجمالي العام + تفصيل كل مجموعة (مستحق/محصّل/باقي/عدد متأخرين) مرتّب تنازليًا حسب الباقي.

**التنفيذ (`specs/036-payment-month-summary/`):**
- `lib/controllers/dashboard_controller.dart`: `GroupPaymentSummaryEntry` (كيان جديد) + `RxList<GroupPaymentSummaryEntry> paymentCardGroupBreakdown` + دالة صرفة جديدة **top-level** `computeMonthlyBreakdown(...)` (مستخرَجة من `_computePaymentCardBody` — نفس حلقة حساب `expected`/`collected`/`unpaidEntries` الموجودة، بلا منطق حساب جديد أو منفصل، عشان مجموع "الباقي" لكل مجموعة يطابق الإجمالي رياضيًا). مجموعات مستحقها صفر (معفيين بالكامل) مُستبعدة، وطلاب بلا مجموعة حقيقية (groupId يتيم) بيتجمّعوا تحت "بلا مجموعة".
- `lib/views/home_page.dart`: `_PaymentProgressCard` بقى ليه `onTapSummary` (منفصل عن `onHorizontalDragEnd` السحب لتبديل الشهر، ومنفصل عن `onTapUnpaid` الموجود على شريحة "N لم يدفع" — التلاتة بيشتغلوا مع بعض بلا تعارض). شيت جديد `_showPaymentMonthSummarySheet` (رأس عام بنفس أرقام الكارت + قائمة مجموعات، كل مجموعة قابلة للضغط تفتح متأخريها بس). `_showUnpaidSheet` الموجودة اتاخدت باراميتر اختياري `groupIdFilter` لإعادة الاستخدام بدل widget قائمة جديد.
- **4 اختبارات وحدة جديدة** (`test/dashboard_group_payment_breakdown_test.dart`) على `computeMonthlyBreakdown` مباشرة (بلا DB/GetX) — بتغطي: تطابق مجموع الباقي مع الإجمالي (SC-002)، الترتيب التنازلي، استبعاد مجموعة معفاة بالكامل، تجميع "بلا مجموعة".
- `flutter test` (165) ✅، `flutter analyze` = 34 (baseline، صفر جديد).

**⏳ متبقّي:** T018 (تحقّق جهازي لسيناريوهات quickstart.md 1–6 على جهاز حقيقي — لسه محتاج إذن صريح قبل أي لمس تاني للجهاز بعد حادثة التشخيص فوق) + commit + نشر v1.2.63.

---

## ✅ جلسة 2026-09-15/16 — spec 035 + دفعة إصلاحات/مزايا صغيرة (منشورة، v1.2.62)

### spec 035 — قرار المدرّس عند خروج أخ من مجموعة إخوة (متنفّذ + **مدفوع ومنشور**، migration مطبّق على الإنتاج)

**البلاغ الأصلي:** مدرّس اشتكى إن لما أخ يمشي من مجموعة ٣ إخوة، بتحصل مشكلة في المدفوعات — القسمة كانت بتتغيّر **صامتة** (من `siblingsTotal ÷ 3` لـ`÷ 2`) وقت أي إعادة حساب، من غير ما المدرّس يوافق أو حتى يلاحظ → قفزة مديونية مفاجئة على الأخوين الباقيين.

**الحل (سبيك كامل: `specs/035-sibling-group-departure/`):**
- عمود جديد `students.sibling_group_committed_count` (**DB v32→v33**) = "آخر عدد أعضاء اتفق عليه المدرّس فعليًا" — ده اللي بقى **القاسم الفعلي** في `PricingHelper.monthlyDue` (عبر `_committedOrLiveCount`)، **مش** العدد الحي المحسوب من `siblingGroupSize`. لحد ما المدرّس يتخذ قرار واعي، القسمة القديمة (٣) تفضل زي ما هي.
- `PricingHelper.siblingGroupDepartureAlert(student, allStudents)`: بيكتشف الفرق (committed > live ≥ 2) ويرجّع `(oldCount, newCount)`.
- `lib/utils/sibling_departure_check.dart` + `lib/widgets/sibling_departure_dialog.dart`: تنبيه تلقائي (حوار) يظهر أول ما يُفتح `group_details_page` أو `student_details_page` لطالب متأثر — بيعرض المبلغ الحالي ونصيب كل واحد قبل/بعد، وبيدّي 3 خيارات: لاحقًا / تأكيد بنفس المبلغ / حفظ مبلغ جديد.
- `DatabaseService.confirmSiblingGroupDeparture(remainingMembers, {newSiblingsTotal})`: تحديث ذري (`db.transaction`) لكل الأعضاء الباقيين + `_queueSync` لكل واحد.
- `linkSiblingGroup` بيحط `sibling_group_committed_count = members.length` عند أي ربط/إعادة ربط جديد.
- `sync_engine.dart`: العمود متزامن (passthrough زي `siblings_total`، بلا ترجمة remote_id).
- `supabase/migration_sibling_group_committed_count.sql` — **مطبّق عبر SSH (`-U supabase_admin`، جدول students).**
- **8 اختبارات وحدة جديدة** (`test/pricing_helper_departure_test.dart`) — كلها تعدّي.

**تحقّق جهازي:** اتعمل مباشرة على جهاز الاختبار (`9aecbc89`) بعد التثبيت — الترقية لـDB v33 نجحت بلا كراش، مفيش أخطاء متعلقة بالمزامنة أو قاعدة البيانات في الـlogcat.

### إصلاح — طالب متأرشف كان لسه بيظهر كـ"أخ" في شاشة تعديل بيانات إخوانه

**بلاغ المستخدم بعد التجربة الجهازية مباشرة:** "لما فتحت بيانات الطالب ظهرلي بردو إن الأخ ده لسه موجود رغم إني أرشفته."

**السبب:** `DatabaseService.getStudentsByGroup​InSiblingGroup` (المُستخدمة في `edit_student_sheet.dart` لعرض/اختيار الإخوة، وكمان في `qr_controller.dart`/`qr_scanner_payment_page.dart`/`add_student_sheet.dart`) ما كانتش بتستبعد الطلاب المؤرشفين من الاستعلام.

**الحل:** إضافة `AND is_archived = 0` لشرط الاستعلام في `getStudentsInSiblingGroup` (سطر واحد، ملف `database_service.dart`) — بيأثر تلقائيًا على كل الأماكن اللي بتستخدمها.

### ميزة — رسائل واتساب للطلاب "المتأخرين" في سجل الحضور

**طلب المستخدم:** مدرّس طلب إن قسم "متأخرون" تحت "غياب اليوم" ييجي بنفس خاصية الواتساب بتاعة الغياب، برسالة مختصرة محترمة (اسم/مجموعة/تاريخ/اسم المدرّس/تخصّصه).

**الحل** (`lib/views/attendance/attendance_page.dart`، `_AbsentTodayTabState`):
- `_buildLateMessage` — نفس شكل رسالة الغياب بالظبط (⚠️ تنبيه تأخير / اسم / مجموعة / تاريخ / مدرّس / تخصّص) — **طابق نص المستخدم حرفيًا بعد ما شاف المسودة الأولى وطلب تعديل بسيط.**
- تحديد فردي/جماعي (`_selectedLate`) + "تحديد الكل" لقسم المتأخرين + زرار "إرسال واتساب للمتأخرين المحددين" أسفل الشاشة (لون كهرماني تمييزًا عن الغياب الأحمر/الأخضر).

### ميزة — تصدير PDF لـ"مدفوعات اليوم" + الإجمالي ظاهر في العنوان

**طلب المستخدم:** زرار طباعة PDF منسّق لمدفوعات اليوم من الصفحة الرئيسية، والإجمالي ظاهر جنب العنوان.

**الحل:**
- `ExportService.exportTodayPaymentsPDF({date, entries})` (جديد، `export_service.dart`) — يستخدم نفس أنماط `_pageHeader`/`_th`/`_td`/`_statBox` القائمة، جدول (اسم/كود/مجموعة/وقت/مبلغ) + صندوق ملخص (عدد الدفعات + الإجمالي).
- `home_page.dart._showTodayPaymentsSheet`: زرار PDF (📄) جنب العنوان + الإجمالي بقى ظاهر في نص العنوان نفسه.

### ميزة — شهادات المراكز مش محدودة بأول ٣ بقى

**طلب المستخدم:** "عايز أدّي أوبشن للمدرّس إنه يتوسّع في عدد الطلاب مش بس أول ٣ مراكز" — وبعدها طلب توضيح السلايدر + إضافة خيار حسب النسبة.

**الحل** (`leaderboard_page.dart` + `exam_controller.dart`):
- حوار `_pickRankCount` بـ`SegmentedButton` **بتلات طرق**: (١) عدد ثابت (سلايدر + أزرار +/-)، (٢) نسبة الدرجة (كل طالب نسبته ≥ X%)، (٣) نسبة من إجمالي الطلاب (أعلى X%). كل وضع بيعرض live preview لعدد الطلاب الناتج قبل التأكيد.
- `ExamController.buildRankCert` قبل `rankNumber` اختياري — لو > 3، بيبني نص "المركز الرابع/الخامس/…" (خريطة `_ordinalWords` لحد ٢٠، وبعدها "رقم N") بدل الاكتفاء بـ"مركز متقدّم".
- `CertKind` ماتغيّرش (لسه بس rank1/2/3 + appreciation) — الترتيب الرقمي (>٣) بيتبعت `kind: CertKind.appreciation` + `rankNumber` فعلي، والنص بيتبني من `rankNumber` مش من `kind`.

### إصلاح — تصادم كود الطالب التلقائي (بيقول "الكود محجوز" رغم إنه أوتوماتيك)

**بلاغ المستخدم + تشخيصه الصحيح:** "بيقولي الكود ده محجوز مع إنه هو حاطّه أوتوماتيك."

**السبب الأرجح (TOCTOU race في وضع الفريق):** الكود التلقائي بيتحسب لحظة فتح شيت "إضافة طالب" أو تغيير المجموعة (`_refreshCode`)، لكن الحفظ الفعلي بيحصل بعدها بوقت (المدرّس بيملا الاسم/الهاتف/السعر...). في وضع الفريق، ممكن جهاز تاني يزامّن طالب بنفس الكود المحسوب في الفترة دي، فيبقى الكود مش متاح فعليًا وقت الحفظ رغم إنه كان صح وقت التوليد.

**الحل** (`add_student_sheet.dart._submit`): لو فشل الإدخال بتعارض كود **وكان الكود تلقائي مش مكتوب يدويًا** (`!_codeIsManual`)، يعيد توليد الكود (`_refreshCode()`) ويحاول تاني — لحد ٣ محاولات — قبل ما يعرض أي رسالة خطأ للمدرّس. لمسناش مسار الاستيراد الجماعي (`import_students_dialog.dart`) — احتمال التصادم فيه أقل بكتير (حلقة سريعة متتالية، مش فورم مفتوح لدقايق).

### الريليس — v1.2.62+4080 (DB v33) — منشور بالكامل

- **Commits:** `68ea410` (spec 035) + `f69ce68` (كل الإصلاحات/المزايا فوق) على `main`، مدفوعين.
- **Tag `v1.2.62`** مدفوع.
- **GitHub Release:** https://github.com/amertimraz/App-Active-Class/releases/tag/v1.2.62 — أصول: `ActiveClass-arm64-v8a.apk` / `-armeabi-v7a.apk` / `-x86_64.apk` (محليًا كمان في `release_assets/v1.2.62/` مع `-play.aab`).
- **VPS:** `/var/www/active-class.online/downloads/ActiveClass-arm64-v8a.apk` محدّث (backup `.bak-1.2.61`).
- **تحقّق جهازي مباشر (جهاز `9aecbc89`):** تجربة كل الميزات الجديدة (تنبيه خروج الأخ، فلتر الإخوة المؤرشفين، واتساب المتأخرين، PDF مدفوعات اليوم، سلايدر شهادات المراكز) — **المستخدم أكّد إنها شغالة**.
- **⏳ متبقّي:** رفع `release_assets/v1.2.62/ActiveClass-play.aab` على Google Play Console يدويًا (لسه ماتعملش).
- **migration واحدة اتطبّقت على الإنتاج هالجلسة:** `migration_sibling_group_committed_count.sql` (`-U supabase_admin`).

**⚠️ حقيقة مهمة اتأكّدت هالجلسة:** الأوامر اللي بتلمس قاعدة بيانات الإنتاج (زي `psql` عبر SSH) بتتمنع أحيانًا من الـauto-mode classifier حتى لو نفس النمط اشتغل قبل كده في جلسات سابقة — محتاجة تأكيد صريح من المستخدم قبل التنفيذ في كل مرة، مش افتراض إذن دائم.

---

## ✅ اللي اتعمل في جلسة 2026-09-08 (سابقة)

### spec 033 — تنظيف رقم ولي الأمر + واتساب (متنفّذ + **مدفوع**، migration مطبّق، **تحقّق جهازي لسه**)

**Commits:** `6fc07a8` سبيك · `60fbedb` خطة · `3f26046` مهام · `23893ed` تنفيذ · `aeb0ac6`+`ca981e9` وصل الإرسال · `05d7e8c` آخر 3 شاشات · **4 مراجعات:** `f3c1643`+`aeff70f` (أرقام دولية، regression `groupsForDay`) · `3694ae5` (normalizers مكسورة فاتوا في settings/reports/auth/db) · `51b49a6` (حذف كود ميت) — كلها مدفوعة.

**الباج:** دالة تطبيع الرقم القديمة `replaceAll(RegExp(r'[^0-9+]'), '')` كانت بتمسح الأرقام العربية (٠١٢٣) بالكامل → واتساب يفتح فاضي. + حقل الرقم RTL بلا `textDirection` → الرقم يتعرض معكوس.

**اللي اتعمل:**
- **`lib/utils/phone_helper.dart`** (جديد، نقي): `PhoneHelper` — `toLatinDigits` (عربي/فارسي→لاتيني)، `cleanForStorage` (يشيل علامات الاتجاه/المسافات/الرموز، يوحّد `+`/`00`)، `waMe(raw, dial)` (رقم دولي صريح — بـ`+` أو `00` أو تسلسل ≥11 خانة بلا صفر — يُحترم؛ غيره + رمز الدولة)، `displayIntl` (‎+20 …، ومايفترضش مصر لرقم دولي مختلف)، `isLikelyValid`، `parseWhatsappHandle` → `WhatsappHandle{kind,value}` (waLink/phone/username/invalid). **36 اختبار** (`test/phone_helper_test.dart`).
- **`lib/utils/phone_format.dart`**: **اتشال** (كان غلاف `normalizeWhatsappPhone` — بقى بلا مستدعين بعد ما كل النقاط اتوصلت بـ`whatsapp_launcher`).
- **`CustomTextField`**: + `textDirection`/`textAlign`/`inputFormatters` اختيارية (صفر تأثير على القائم).
- **`lib/widgets/phone_field.dart`** (جديد): `PhoneSanitizerFormatter` + `PhoneField` — LTR + تنظيف لحظي + معاينة «هيتبعت على: ‎+20 …» + تحذير «الرقم يبدو غير مكتمل» (غير معطِّل).
- **`add_student_sheet` + `edit_student_sheet`**: `PhoneField` بدل الحقل القديم + حقل `_whatsappCtrl` LTR جديد «واتساب ولي الأمر (رابط/username)».
- **`lib/utils/whatsapp_launcher.dart`** (جديد): `launchGuardianWhatsapp({phone, whatsapp, message, dialCode})` — أولوية: رابط `wa.me` → رقم → username (+نسخ الرسالة + توست). **موصول في كل نقاط إرسال واتساب لولي الأمر** (12 موضع): `student_details_page`، `attendance_page` (×3)، `group_details_page` (×2)، `payments_report_page`، `reports_page`، `settings_page` (إرسال جماعي)، `student_exam_history_page`، `exam_grades_page` (×2)، `online_exam_results_page`، `at_risk_students_page`. **كل الـnormalizers المحلية المكسورة (7) اتشالت.**
- **`auth_service.dart`** (تسجيل دخول الفريق) + **`database_service.dart`** (allowed exam students، last4) بقوا يمرّوا الرقم عبر `PhoneHelper.toLatinDigits` قبل الاقتطاع.
- **US3 عمود:** `students.guardian_whatsapp TEXT`، **DB v29→v30**، `Student.guardianWhatsapp` (toMap/fromMap/copyWith)، مُزامَن في `sync_engine` (`_buildRemoteRow`/`_toLocalMap` لـTABLE_STUDENTS). `supabase/migration_guardian_whatsapp.sql` **مطبّق عبر SSH كـ`-U supabase_admin`** (جدول students مملوك لـsupabase_admin مش postgres — اتوثّق في memory).
- **`contact_picker_service._normalize`** + **`parent_portal_service._last4`**: يمرّوا عبر `PhoneHelper` (تحويل الأرقام العربية).
- **التخزين يفضل صيغة بشرية** (`01…`)؛ التطبيع للـ`wa.me` لحظة الإرسال — صفر ترحيل بيانات، صفر موجة مزامنة.
- **اختبارات:** `flutter test` 149 ✅، `flutter analyze` 34 (baseline).

**متبقّي:** T031 (تحقّق جهازي — quickstart 1–11: لصق من سجل مكالمات حقيقي، جهازين للمزامنة). سبيك: `specs/033-guardian-phone-cleanup/`.

**باج قديم (مش من spec 033):** تعديل طالب وإفراغ حقل الرقم مابيتحفظش — `Student.copyWith` مفهوش `clearGuardianPhone` (زيّ ما `guardianWhatsapp` بقى ليه `clearGuardianWhatsapp`).

### spec 032 — إلغاء حصة اليوم وتعويضها (متنفّذ + **مدفوع** على `main`، migration مطبّق عبر SSH، **تحقّق جهازي لسه**)

**Commits:** `15d940d` خطة+مهام · `04230b4` تنفيذ · `c5f9e2b` T018 (إخفاء القائمة للحصة الملغاة) · `aeff70f` مراجعة (regression `groupsForDay`). مدفوعين.

**الفكرة:** مفيش كيان "حصة" — الحصص مشتقّة من `Group.schedule` + التاريخ. جدول جديد `session_overrides` (مفتاح منطقي `(group_id, date)`، `type ∈ {cancelled, makeup, extra}`, `compensates_date` للـmakeup).

**اللي اتعمل:**
- **`constants.dart`**: `TABLE_SESSION_OVERRIDES` + `COL_SO_*` + `DATABASE_VERSION = 29`.
- **`models/session_override_model.dart`** (جديد): `SessionOverride` + `SessionOverrideType` + `toMap/fromMap` (تاريخ ↔ `YYYY-MM-DD`، نوع مجهول → `cancelled`).
- **`utils/session_schedule_resolver.dart`** (جديد، نقي): `resolveHasSession({scheduleSays, overrideType})` + `expectedCountDelta({overridesInRange, scheduleHasDay})`.
- **`services/database_service.dart`**: `_sessionOverridesTableSql` (+ UNIQUE index `(group_id,date)`) في `_createTables` + `_onUpgrade` v29. CRUD: `getAllSessionOverrides`/`getSessionOverride`/`insertSessionOverride`(+`_queueSync`)/`deleteSessionOverride`(+`_queueDelete`). `countAttendanceForGroupOnDay`/`deleteAttendanceForGroupOnDay` (JOIN students بالـgroup، txn + `_queueDelete` لكل صف).
- **`services/sync_engine.dart`**: `TABLE_SESSION_OVERRIDES` في `_tables`+`_coreTables`+`_pkCol`+`_buildRemoteRow` (group_id محلي → `group_remote_id` uuid)+`_toLocalMap`+`_refreshUiForTable`. كتلة dup على `(group_id,date)` → `_reconcileDuplicate` (spec 031).
- **`controllers/session_override_controller.dart`** (جديد، GetX، `permanent` في main.dart، `onInit`→`load()`): `overrides` RxList، `overrideFor`/`overridesForGroupInRange`/`cancelledForGroup`، طفرات `cancelToday`/`addMakeup`/`addExtra`/`removeOverride` (ترجع `String?` خطأ، تطبّق قواعد التحقّق).
- **`controllers/attendance_controller.dart`**: استخرجت `_scheduleWeekdays` + `_scheduleCountForGroup` (جدول فقط). `groupHasSessionOnDay`/`_countExpectedForGroup`/`groupsForDay` بقوا override-aware. جديد: `groupsForDayWithOverrides` (بيسيب كارت المجموعة الملغاة ظاهر عشان التراجع)، `sessionOverrideFor`، `groupHasSessionOnDayScheduleOnly`.
- **`widgets/session_override_widgets.dart`** (جديد): `SessionOverrideMenuButton` (⋮ في رأس موديل الحضور: إلغاء/تعويضية/إضافية/تراجع — الإلغاء متبوّب بـ`canDeleteAttendanceNow` + حوار "هيتمسح N")، `SessionOverrideBanner`، `showAddSessionOverrideFlow` (من `_NoSessionsToday`).
- **`views/attendance/attendance_page.dart`**: القائمة + البانر في الموديل، شارة "ملغاة/تعويضية/إضافية" على `_GroupSummaryCard`، `_RegisterTabState.initState`→`load()`. **حصة ملغاة → موديل الحضور يخفي قائمة الطلاب ويعرض زر "تراجع عن الإلغاء" فقط** (منع تسجيل حضور بالغلط). إحصاءات الشريط اليومي تحسب المجموعات النشطة فقط.
- **`views/students/student_details_page.dart`**: `_SessionOverridesSection` (عرض فقط، فوق قائمة الشهور — مش بيتحسب في النِسبة).
- **`supabase/migration_session_overrides.sql`** (جديد): جدول + RLS (`is_team_member AND is_team_license_active`) + `check_delete_session_overrides` (صلاحية `delete_attendance`) + `trg_set_updated_at` + `replica identity full` + realtime publication. **مطبّق عبر SSH + متحقَّق**.
- **الفوترة: صفر تغيير** (`PricingHelper` ملمسناهوش — كلها من صفوف الحضور).
- **اختبارات:** `test/session_override_model_test.dart` + `test/session_schedule_override_test.dart` (15 اختبار). `flutter test` 149 ✅، `flutter analyze` 34.
- **مراجعة (`aeff70f`):** `groupsForDay` كان بيعرض المجموعات بلا جدول كل يوم (regression — `groupHasSessionOnDay` بترجّع true افتراضيًا) → رجّعنا السلوك القديم: مجموعة بلا جدول تظهر فقط لو ليها `makeup`/`extra` صريح لليوم ده. + `_toLocalMap` بيحط `created_at = updated_at` بدل null.
- **تحسينات UX (v1.2.52، اتجربت على جهاز):**
  - `a626665`+`8aad01e`+`456b288`+`3ff2e22`+`4f7ed13`+`b2eae35`:
  - **فورم واحد** `_AddSessionOverrideSheet` (bottom sheet: مجموعة + نوع + تاريخ + من/إلى + بتعوّض عن حصة) بدل 4 حوارات متتالية. شِلت `makeup`/`extra` من قائمة ⋮ (بقت في الفورم بس).
  - تاريخ الحصة يقبل **مستقبلي** (لحد 120 يوم).
  - **ميعاد الحصة إجباري** — حقلين «من»/«إلى»، النهاية أوتوماتيك = البداية +ساعة (قابلة للتعديل). يتخزّن `HH:mm-HH:mm` في عمود `session_overrides.session_time` (**DB v31**). `sessionTimeForGroupOnDay`/`remainingSessionTime` بيتعاملوا معاه زي جدول المجموعة.
  - **التعويضية لازم تكون عن حصة ملغاة فعليًا** — «بتعوّض عن حصة» = قائمة الحصص الملغاة للمجموعة اللي لسه مالهاش تعويض (`uncompensatedCancelledForGroup`). `addMakeup` بيرفض لو `compensatesDate` مش ملغي.
  - `confirmUndoSessionCancel`: تحذير صريح قبل التراجع («الحضور المتمسح مش هيرجع»). حوار الإلغاء بقى دايمًا يتأكّد.
  - `_NoSessionsToday` بقى scrollable + الزر `OutlinedButton` كامل العرض فوق.
  - migration `migration_session_override_time.sql` مطبّق عبر SSH (`-U postgres`).

**تقييم صادق للسلوك (spec 032):** المنطق سليم والفوترة صح (per-session من صفوف الحضور، الشهري مايتأثرش). حتات خشنة باقية: (1) التراجع عن إلغاء مابيرجّعش الحضور المتمسح — بيحذّر بس مش undo حقيقي؛ (2) **بوابة الأهل** لسه مابتعرضش الإلغاء/التعويض (T024)؛ (3) تعويض بين شهرين بيوزّع النسبة على شهرين.

**متبقّي:** T024 (بوابة الأهل)، T029 + **تحقّق جهازي/جهازين** (quickstart 1–8). سبيك: `specs/032-cancel-makeup-session/`.

### spec 027 — دعم جهاز قارئ باركود خارجي (HID) في شاشتَي الحضور والدفع (متنفّذ + مدفوع على `main`)

**Commits:** `827a44d` (التنفيذ) + `6e5dc3f` (تحسين خوارزمية الكشف = متوسط الزمن). كلها مدفوعة.

**الفكرة:** جهاز قارئ باركود 2D (USB-OTG أو بلوتوث) بوضع HID = كيبورد: بيـ«كتب» الكود بسرعة + Enter. صفر مكتبات/أذونات/DB/مزامنة.

**اللي اتعمل:**
- **`lib/config/constants.dart`**: `SETTING_HARDWARE_SCANNER_ENABLED = 'hardware_scanner_enabled'`.
- **`lib/controllers/settings_controller.dart`**: `RxBool hardwareScannerEnabled` (افتراضي false، محلي، غير مُزامن)، يُحمَّل في `_loadHideQrSettings`، + `setHardwareScannerEnabled`.
- **`lib/utils/hardware_scan_buffer.dart`** (جديد): `HardwareScanBuffer` — يجمّع `KeyDownEvent`، يُصدر `onScan(code)` عند Enter/Tab/numpadEnter لو: طول ≥2 بعد trim **و متوسط الزمن/حرف على التتابع كله ≤50ms** (متوسط مش فاصل بين كل حرفين — عشان jank لحظي في الـUI ميكسرش الكشف). فجوة >250ms → تتابع جديد؛ خمول >300ms → تصفير. `nowOverride` للاختبار.
- **`test/hardware_scan_buffer_test.dart`** (جديد، 11 اختبار كلها تعدّي — يشمل حالة jank لحظي).
- **`lib/widgets/hardware_reader_widgets.dart`** (جديد): `HardwareActiveBadge` (شارة "القارئ نشط • آخر مسح ..." بعد أول مسح ناجح)، `ReaderReadyPanel` (بديل الكاميرا في الوضع الخالص)، `HardwareScannerTestTile` ("جرّب القارئ" في الإعدادات — يمسك مسح واحد، يعرض النص + "✅ HID"، صفر أثر بيانات)، + `relativeScanText`.
- **`qr_scanner_attendance_page.dart` + `qr_scanner_payment_page.dart`**: `HardwareKeyboard.instance.addHandler(_hwKeyHandler)` في initState (مش `Focus` — عشان الفوكس ممكن ميبقاش على الشاشة)، بيتشال في dispose. حواجز الـhandler: تاب index==0 + `ModalRoute.isCurrent` + mounted. يغذّي `_scanBuffer` → `_handleQR(code, fromHardware:true)` / `_handle(...)` (حارس التكرار + الصوت + الاهتزاز مُعاد استخدامها). `_pureScannerMode = hardwareEnabled && hideQr` → الكاميرا متتشغّلش خالص + `ReaderReadyPanel`. `_qrTabVisible = !hideQr || pureMode`. الشارة تشتغل بس مع `fromHardware` (مش إدخال يدوي). buffer.reset() عند تبديل التاب.
- **`settings_page.dart`**: سطر Switch "قارئ باركود خارجي" بعد "إخفاء ماسح QR في الحضور" + `HardwareScannerTestTile` تحته لما مفعّل.

**التحقّق:** كل `flutter test` (64) يعدّي، `flutter analyze` = 34 issue (نفس الـbaseline بالظبط، صفر جديد).

**قرار مهم موثّق في السبيك:** مفيش «زر ربط» ولا عرض اسم الجهاز — مستحيل مع HID (الجهاز كيبورد بالنسبة للـOS). الجاهزية تُستنتج من نجاح مسح فعلي (الشارة + "جرّب القارئ").

**خارج النطاق (follow-ups):** طباعة باركود 1D على الكروت، وضع «الموبايل مقفول/الخلفية» (محتاج Bluetooth SPP).

**سبيك كامل:** `specs/027-hardware-barcode-scanner/` — T001–T018 + T020 ✅، **T019 (تحقّق جهازي بجهاز HID حقيقي — quickstart سيناريوهات 1–11) لسه ماتعملش**.

### ريليس v1.2.52 (منشور بالكامل — تحسينات spec 032 UX + إصلاح spec 028)

- `1.2.51+4069` → **`1.2.52+4070`**. Commit `142c45c` + tag `v1.2.52` مدفوعين.
- **GitHub Release** (latest): https://github.com/amertimraz/App-Active-Class/releases/tag/v1.2.52 — `-arm64-v8a.apk` sha256 `bcf54bf9da6aa7e6d3aafd66cc09d6f59ef1d06c367fd52b52a052cbfb30f8db` · `-armeabi-v7a` `172ef5ff…` · `-x86_64` `517bb623…` · `-play.aab` `860895be…`. versionCode 4070، توقيع `5f74fe10…`.
- **VPS:** backup `.bak-1.2.51` ثم scp. `curl -sI` → 200، 47894720 بايت، sha مطابق. `/releases/latest` → v1.2.52.
- **DB v31** (عمود `session_overrides.session_time`). migrations `migration_guardian_whatsapp.sql` + `migration_session_override_time.sql` مطبّقين عبر SSH.
- **بيتضمّن:** كل تكرارات spec 032 UX (فورم واحد، ميعاد إجباري من/إلى، تاريخ مستقبلي، تعويضية مربوطة بإلغاء فعلي، تحذير التراجع) + **إصلاح المربّع الرمادي في شاشة «حذف سجلّات بمدى تواريخ»** (كان ObxError من `teamModeEnabled && ...` short-circuit).
- **⏳ متبقّي على المستخدم:** رفع `release_assets/ActiveClass-v1.2.52-play.aab` على Play Console.

### ريليس v1.2.51 (منشور بالكامل — يضم specs 028/029/030/031/032/033)

- **`pubspec.yaml`** + `android/local.properties`: `1.2.50+4068` → **`1.2.51+4069`**.
- **Commit `1e4b3ab`** + **tag `v1.2.51`** مدفوعين.
- **GitHub Release** (latest، مش draft/pre): https://github.com/amertimraz/App-Active-Class/releases/tag/v1.2.51
  - أصول: `-arm64-v8a.apk` (sha256 `29ec4836fd0376a1239eb401cac5e7a911fd90b7a90975f20d938280135ad14a`)، `-armeabi-v7a.apk` (`d4e7b0cb…`)، `-x86_64.apk` (`038fb996…`)، `-play.aab` (`6f1db283…`). كلها versionCode **4069**، توقيع release صحيح (`5f74fe10…`)، universal (كل الـABIs). محليًا في `release_assets/ActiveClass-v1.2.51-*`.
- **VPS:** `/var/www/active-class.online/downloads/ActiveClass-arm64-v8a.apk` (backup `.bak-1.2.50`). التحقق: `curl -sI` → 200، 47829184 بايت، sha256 مطابق (`29ec4836…`).
- **`/releases/latest`** يرجّع v1.2.51 → التحديث الذاتي داخل التطبيق شغّال.
- **درس البناء:** `flutter build apk --release --flavor direct` (بلا target-platform) = fat 99MB. الصح: `--target-platform android-arm64` (~48MB، universal فعليًا) ثم `android-arm` ثم `android-x64`، انسخ فورًا. AAB: `flutter build appbundle --release --flavor play`. ~5 دقايق لكل بناء، صفر OOM.
- **⏳ متبقّي على المستخدم:** رفع `release_assets/ActiveClass-v1.2.51-play.aab` على Play Console يدويًا.

### ريليس v1.2.50 (منشور بالكامل)

- **`pubspec.yaml`** + `android/local.properties`: `1.2.49+4067` → **`1.2.50+4068`**.
- **Commit `79ad6d3`** + **tag `v1.2.50`** مدفوعين.
- **GitHub Release** (latest): https://github.com/amertimraz/App-Active-Class/releases/tag/v1.2.50 — أصول: `-arm64-v8a.apk` (sha256 `546d11891c260974f33673ca12cdb0e9d18b68d519b910008f9af277ec4c1679`)، `-armeabi-v7a.apk`، `-x86_64.apk`، `-play.aab`. الثلاث APK **universal** (كل الـABIs) versionCode 4068، توقيع release صحيح (`5f74fe10...`). محليًا في `release_assets/ActiveClass-v1.2.50-*`.
- **VPS:** `/var/www/active-class.online/downloads/ActiveClass-arm64-v8a.apk` (backup `.bak-1.2.49`). التحقق: `curl -sI` → 200، 48228892 بايت، sha256 مطابق.
- **booking_site:** `booking_site/downloads_ready/ActiveClass-arm64-v8a.apk` محدّث (ضمن `79ad6d3`).
- **release notes:** `scratchpad/release_notes_v1.2.50.md`.
- **درس البناء تأكّد تاني:** `--split-per-abi` = OOM. الحل: `flutter build apk --release --flavor direct --target-platform android-arm64` (وبعده `android-arm`، `android-x64`) — بيكتب فوق `build/app/outputs/flutter-apk/app-direct-release.apk` (universal فعليًا مش ABI واحد) فانسخه فورًا. الـAAB: `flutter build appbundle --release --flavor play`. كل بناء ~4.5–6 دقايق، مفيش OOM المرة دي.

### spec 029 — تنبيه "متأخر في الدفع" في شاشة الحضور (متنفّذ + **مدفوع** `220305f`)

**القاعدة:** بادج تحذير بصري جنب اسم الطالب وقت تسجيل حضوره:
- شهري / بلا مجموعة → `PricingHelper.isOverdue(...)` (بمهلة السماح `paymentGraceDays`)
- بالحصة → `accumulatedDebt − (حصص النهاردة × effectivePrice) > 0.01` (يعني عليه رصيد لحصص أقدم من اليوم؛ حصة اليوم طبيعي)
- معفى بالكامل → لا

**اللي اتعمل:**
- `constants.dart`: `SETTING_ATTENDANCE_OVERDUE_WARNING = 'attendance_overdue_warning'`.
- `settings_controller.dart`: `RxBool attendanceOverdueWarning` (افتراضي **true**، محلي)، يُحمَّل في `_loadLateAttendanceSettings`، + setter.
- `pricing_helper.dart`: `showsAttendanceOverdueWarning({student, group, allAttendance, payments, graceDays, siblingGroupMembers})` + `sessionsAttendedOn({student, day, allAttendance})` (يحسب "متأخر" كحضور).
- `test/attendance_overdue_warning_test.dart` (جديد، 10 اختبارات).
- `lib/widgets/overdue_warning_badge.dart` (جديد): `OverdueWarningBadge({debtAmount, compact})` (غبي) + `OverdueWarningFor({student, compact})` (يحلّ كل الكونترولرز عبر Get، `Obx` يتحدّث بعد دفعة).
- `qr_scanner_attendance_page.dart`: `payCtrl.loadPayments()` في postFrame؛ `OverdueWarningFor` في `_AttendancePanel` (كامل) و `_StudentSearchCard` (compact).
- `attendance_page.dart`: `OverdueWarningFor(compact)` تحت اسم الطالب في `_StudentAttendanceChip` (`PaymentController` موجود هناك أصلاً).
- `settings_page.dart`: سطر Switch "تنبيه المتأخر في شاشة الحضور" قبل "تسجيل متأخر تلقائيًا عبر QR".

**التحقّق:** `flutter test` (74) يعدّي، `flutter analyze` = 34 (baseline، صفر جديد).

**سبيك كامل:** `specs/029-attendance-overdue-warning/` — T001–T014 + T016 ✅، **T015 (تحقّق جهازي — quickstart 1–10) لسه**.

**⚠️ لسه محتاج:** commit + تحقّق جهازي.

### spec 031 — اتساق تعارضات المزامنة (متنفّذ + **مدفوع** `62d88dc` + migration مطبّق)

بعد مراجعة أعمق للمزامنة: سببان لـ"المدرّس والمساعد مش متطابقين":

1. **LWW كان بيقارن `updated_at` من ساعة كل موبايل** → جهاز بساعة منحرفة تعديلاته تخسر دايمًا. **الحل:** `supabase/migration_server_updated_at.sql` — دالة `set_updated_at()` + trigger `trg_set_updated_at` (BEFORE INS/UPD) على 11 جدول متزامن يفرض `NEW.updated_at = now()`. **اتطبّق عبر SSH — متحقَّق (11 جدول).**
2. **الصف المكرّر الوارد كان بيتجاهل بصمت** → المدرّس "حاضر"، المساعد "متأخر"، خلاف دائم. **الحل:** `_reconcileDuplicate` في `sync_engine.dart` بدل الـ5 كتل `if(dup.isNotEmpty){return;}` (attendance/homework/exam_groups/exam_grades/exam_submissions) → LWW على البيانات (الأحدث بوقت الخادم يفوز)، **`remote_id` المحلي ثابت** (تغييره بيربك outbox)، الصف الخاسر على الخادم بيفضل يعيد البثّ ويخسر LWW (اتساق نهائي).

- `lib/utils/sync_conflict.dart` (جديد): `syncConflictIncomingWins(...)` نقية (وقت + tie-break بالمعرّف الأصغر معجميًا). 6 اختبارات.
- صفر تغيير schema محلي (v28)، صفر تغيير RLS، الـtrigger يضبط `updated_at` فقط.

**التحقّق:** `flutter test` + `analyze` نظيف. **لسه:** تحقّق جهازين (ساعة منحرفة، حضور/درجة مزدوجة).

**⚠️ توافق رجعي:** البيانات القديمة على الخادم طوابعها المحلية القديمة تبقى لحد أول تعديل يمرّ عبر الخادم فيأخذ الوقت الموحّد. أثر انتقالي بسيط أول أيام.

### spec 030 — تقوية مزامنة وضع الفريق (متنفّذ + **مدفوع** `9540952` + مراجعات `31d77ed`/`d4268fe`)

**3 باجات في `sync_engine.dart` بلّغ عنها مساعد** (بيانات مش بتوصل / بتتأخّر / تسجيل خروج تلقائي):

1. **طابور الإرسال بيتجوّع من صفوف مسمومة** — `drainOutbox` كان `WHERE synced=0 ... LIMIT 50`؛ صف بيفشل دايمًا بيتراكم في المقدمة وأول ما يوصلوا 50 → صفر تقدّم. **الحل:** `Map _outboxFails` في الذاكرة، صف تجاوز 5 فشل → `WHERE id NOT IN (poison)` (يُعاد المحاولة كل 20 جولة)، لوج واحد عبر `_loggedPoison`.
2. **مفيش سحب دوري** — السحب بس عند البدء وعند Realtime `subscribed`. **الحل:** `_catchUpTimer = Timer.periodic(50s → catchUpPull)` + `SyncEngine with WidgetsBindingObserver` → `catchUpPull` عند `resumed`. يُلغى في `stop()`.
3. **`_wasRemovedFromTeam` بيسجّل خروج على استعلام فاضٍ واحد** — RLS بترجّع فاضي على توكن قرب يخلص. **الحل:** `_sessionUsable()` (`currentSession` صالحة، وإلا `refreshSession` + تأجيل) + `_emptyMembershipStreak >= 3` قبل `onRemovedFromTeam`. نفس المبدأ لـ`_wasDeviceUnbound`. `_wasLicenseDeactivated` += حارس الجلسة فقط.

- `lib/utils/sync_retry_policy.dart` (جديد): `shouldAttemptOutboxRow` + `shouldFireTeamExit` (دوال نقية) + ثوابت `kMaxOutboxFails=5`/`kPoisonRetryEvery=20`/`kTeamExitStreak=3`.
- `test/sync_retry_policy_test.dart` (جديد، 8 اختبارات).
- `team_mode_service.dart`: `_startEngine` بقى ينادي `_engine?.stop()` الأول (SyncEngine بقى بيسجّل observer + تايمر).

**التحقّق:** `flutter test` (91) يعدّي، `flutter analyze` = 34 (baseline). صفر تغيير DB/خادم/بروتوكول.

**سبيك:** `specs/030-team-sync-hardening/` — T001–T014 + T016 ✅، **T015 (تحقّق جهازين — quickstart) لسه**.

**⚠️ لسه محتاج:** commit + تحقّق جهازين (هبّة شبكة لا تسجّل خروج، إزالة فعلية تسجّله، مزامنة ثنائية كاملة).

### spec 028 — حذف السجلات بمدى تواريخ (متنفّذ + **مدفوع** `3aa0d20` + `5588c99`)

- `lib/models/deletable_record_type.dart` (جديد): `enum DeletableRecordType` (attendance/payments/examGrades/exams/homework/reportLogs) + `label`/`mainTable`/`dateColumn`/`pkColumn`/`isTeamSynced`؛ `rangeIsoBounds(from,to)` → `[fromIso, toIso)` (يوم البداية 00:00 حتى نهاية يوم النهاية)؛ ثوابت `kBulkDeleteThreshold=100` / `kDeleteConfirmWord='حذف'`.
- `database_service.dart`: `countDeletableRecordsInRange(...)` (معاينة) + `deleteRecordsInRange(...)` — يجمّع `(table,id,remote_id)` للصفوف المُزامَنة قبل الحذف، `db.transaction` يحذف كل الأنواع، ثم `_queueDelete` لكل صف مُزامَن (وضع الفريق فقط). `report_logs` → حذف محلي بلا queue. الامتحانات: `DELETE exams WHERE id IN (...)` + FK CASCADE للتوابع (زي `deleteExam`). درجات منفصلة: `exam_id IN (امتحانات المدى)`. **درجات الامتحانات تُفلتَر بتاريخ الامتحان الأب** (`exam_grades` مالوش تاريخ ذاتي).
- `delete_records_controller.dart` (جديد): `GetxController` — المدى/الأنواع/المعاينة، `runPreview()`، `runDelete()` → نسخة احتياطية إجبارية (`BackupService().createBackup()`، فشل → `DeleteBackupFailed` بلا حذف) ثم `deleteRecordsInRange` ثم تحديث `Attendance/Payment/Exam/Dashboard` كونترولرز. `DeleteOutcome` = `DeleteSuccess`/`DeleteBackupFailed`/`DeleteError`.
- `delete_records_page.dart` (جديد): رأس تحذيري + تاريخَي من/إلى (`showDatePicker`) + `CheckboxListTile` لكل نوع + معاينة + حوار تأكيد (كتابة "حذف" لو الإجمالي > 100) + `ProgressDialog`. تحذير مزامنة الفريق لو `teamModeEnabled && previewTotal > 500`.
- `settings_page.dart`: سطر "حذف سجلّات بمدى تواريخ" في قسم النسخ الاحتياطي، **بلا** `requireTeamOwnerIfTeamMode` (المساعد يقدر يحذف — الحذف يتزامن اتجاهين).
- **fix صلاحيات (بعد مراجعة المزامنة):** `DeleteRecordsController.isTypeAllowed` — في وضع الفريق، عضو بلا `canDeleteAttendanceNow`/`canDeletePaymentsNow` ميقدرش يختار "الحضور"/"الدفعات" (Supabase triggers `check_delete_*` بترفض soft-delete من عضو بلا صلاحية → صف outbox مسموم). checkbox معطّل + "مالكش صلاحية". باقي الأنواع مفيهاش trigger.
- `test/delete_records_range_test.dart` (جديد، 9 اختبارات — `rangeIsoBounds` + خصائص الـenum + عتبة التأكيد؛ تنفيذ الحذف على القاعدة يُتحقَّق يدويًا لعدم وجود بنية اختبار DB in-memory).

**التحقّق:** `flutter test` (83) يعدّي، `flutter analyze` = 34 (baseline، صفر جديد).

**سبيك كامل:** `specs/028-delete-records-by-date-range/` — T001–T012 + T014 ✅، **T013 (تحقّق جهازي — quickstart 1–9) لسه**.

**⚠️ لسه محتاج:** commit + تحقّق جهازي (خصوصًا فشل النسخة الاحتياطية → إلغاء، وجهازين للمزامنة).

### hotfix — سجل جلسة الدفع كان بيعرض عرض الإخوة عنصر واحد بالمبلغ الكامل (Commit `47cf022`، مدفوع)

كان سجل "دفعوا اليوم" الحيّ يضيف عنصرًا واحدًا باسم الطالب الممسوح وبالمبلغ الإجمالي (150) بدل عنصر لكل أخ بنصيبه (75+75). القاعدة كانت مضبوطة والـhydrate بعد إعادة التشغيل صح — الخطأ في `_session.add` الحيّ فقط.
- `QRController.lastSiblingSplit`: قائمة صف لكل أخ (paymentId/الاسم/المبلغ/هاتف)، تُملأ داخل حلقة الإخوة، تُصفَّر أول كل `confirmPayment`.
- `qr_scanner_payment_page._confirmPayment`: لو `lastSiblingSplit` مش فاضية → عنصر سجل لكل أخ بنصيبه؛ غير كده السلوك القديم.
- الإجمالي مكانش غلط (150 = الفعلي)؛ العدد بقى +2 بدل +1 = أدق ومتطابق مع ما بعد إعادة التشغيل.

---

## ✅ اللي اتعمل في جلسات سابقة

### 1) spec 026 — تحصيل المديونية المتراكمة من شاشة الدفع بالماسح (متنفّذ بالكامل)

**المشكلة:** شاشة `qr_scanner_payment_page.dart` للمجموعات **بالحصة** كانت بتحسب الحصص المستحقة ضمن **الشهر الحالي فقط** (`QRController._preparePayment` كان `start = nowMonth`)، فتتعارض مع `PricingHelper.accumulatedDebt` (المديونية المتراكمة الحقيقية) المعروضة في كارت تفاصيل الطالب. المدرس مش قادر يحصّل المتأخر القديم من الماسح.

**الحل (ملفّان مصدر + ملف اختبار، صفر تغيير DB/مزامنة):**

- **`lib/controllers/qr_controller.dart`**
  - `_preparePayment`: للمسار per-session `start = DateTime(joined.year, joined.month)` حيث `joined = student.attendanceStart ?? student.createdAt` (fallback `nowMonth`)؛ `selectedMonths` = كل الشهور من الانضمام حتى الشهر الحالي (شامل). المسار الشهري بلا تغيير.
  - `_buildUpcomingMonths(DateTime start, {bool perSession = false})`: توقيع جديد. per-session = من start للشهر الحالي فقط، سقف حارس 60 بدل 12.
  - getters جديدة: `_effPrice` (= `scannedStudent.value?.effectivePrice ?? 0`)، `scannedStudentDebtSessions` (= `_effPrice > 0 ? (scannedStudentDebt / _effPrice).floor() : 0`)، `sessionsCoveredBy(double amount)`، `debtRemainingAfter(double amount)` (clamp ≥ 0).
  - `bool applyDebtAmountPayment(double amount)`: يتحقق (`isPerSessionGroup`, student != null, `amount > 0`, `debt > 0.01`, `amount <= debt + 0.01`) + توست خطأ؛ عند القبول `setOverride(amount, note: 'دفعة من المديونية')` ثم `_sessionsCoveredByQuickPay = sessionsCoveredBy(amount)` (أعدت استخدام الحقل القائم بدل `_explicitSessionsForPayment` الجديد اللي في tasks.md — نفس دورة الحياة: يُصفَّر في `setOverride`، يُعاد ضبطه بعده، يُقرأ في `confirmPayment`).
  - كل getters العدّ القائمة (`unpaidSessionsCount` / `unpaidSessionDates` / `_paidSessionsInSelectedMonths` / `fullyPaidUp` / `effectiveSessionsSelected`) تتصحّح تلقائيًا عبر توسيع `selectedMonths` — بلا تعديل في كودها.

- **`lib/views/qr_scanner/qr_scanner_payment_page.dart`**
  - سطر المديونية (كان `if (!controller.isPerSessionGroup && !student.isFullyExempt)` عند ~1054) → `if (!student.isFullyExempt)` — يظهر للـper-session كمان + سطر ثانٍ «= N حصة» (per-session فقط، `scannedStudentDebtSessions >= 1`).
  - ويدجت جديد `_DebtAmountField` (StatefulWidget، آخر الملف قبل `_MonthChip`): `TextField` رقمي «ادفع مبلغًا من المديونية» + `Obx` معاينة («يغطّي N حصة • المتبقّي بعد الدفع: …» / تحذير أحمر لو `> debt` / لا شيء لو فارغ/0/غير رقمي) + زر «تطبيق» → `controller.applyDebtAmountPayment(parsed)`. يظهر per-session فقط عندما `!fullyPaid && scannedStudentDebt > 0.01 && student.effectivePrice > 0`.

- **`test/qr_payment_debt_test.dart`** (جديد، 14 اختبار، كلها تعدّي): `PricingHelper.accumulatedDebt` per-session عبر شهرين = 140 (مثال المستخدم الحرفي: 6 حصص أغسطس + 1 سبتمبر × 20)، دفعة 60 → 80؛ منطق تحويل floor؛ قواعد قبول المبلغ الحر.

- **حالات محسومة (research.md):** floor مش round؛ منع الزيادة عن المديونية = سلوك v1 (مفيش رصيد مقدّم من الشاشة دي)؛ المبلغ الحر للمجموعات **الشهرية** خارج v1 (تفضل باختيار شهور كاملة، بس يظهر رقم المديونية)؛ سعر حصة = 0 → عرض بالجنيه بلا «= N حصة» + حقل المبلغ معطّل.

- **حالة معروفة مقبولة:** لو المدرس دخّل مبلغ **أقل من سعر حصة** (مثلاً 10 ج وسعر 20)، المبلغ يتسجّل صح لكن عدّاد `sessions` في الملاحظة يتقرّب لـ1 بدل 0 (فرق تجميلي في العدّ، الفلوس مضبوطة).

**Commit:** `dd5282e` على `main` (مدفوع). كل `flutter test` (53) + `flutter analyze` نظيف (صفر مشاكل جديدة — الـ34 info كلها baseline قديمة، منها 2 في `qr_scanner_payment_page.dart:179` و`:1487` مش من التعديل).

**سبيك كامل:** `specs/026-qr-payment-accumulated-debt/` (spec.md, plan.md, research.md, data-model.md, contracts/×3, quickstart.md, tasks.md — T001–T015 + T017–T020 ✅، **T016 لسه [ ]**).

### 2) ريليس v1.2.49 (منشور بالكامل)

- **`pubspec.yaml`**: `1.2.48+4066` → **`1.2.49+4067`**. `android/local.properties` كذلك (`flutter.versionCode=4067` — gitignored).
- **Commit:** `42f830a` على `main` (مدفوع). **Tag `v1.2.49`** مدفوع.
- **GitHub Release** (latest, مش draft/pre): https://github.com/amertimraz/App-Active-Class/releases/tag/v1.2.49
  - أصول: `ActiveClass-v1.2.49-arm64-v8a.apk` (sha256 `9ce7f9eb2e9c4861e6b560daca0ffc0bc6931074c8abd66c9915d18e6f5e2158`)، `-armeabi-v7a.apk`، `-x86_64.apk`، `-play.aab`. كلها versionCode **4067**، توقيع release صحيح (`5f74fe10af2da396cbf0a98895af02bb5ffbdc01cdf68a55bea25a841f02ec7b`).
  - محلّيًا في `release_assets/ActiveClass-v1.2.49-*`.
- **VPS نشر:** `/var/www/active-class.online/downloads/ActiveClass-arm64-v8a.apk` (backup `.bak-1.2.48`). التحقق: `curl -sI https://active-class.online/downloads/ActiveClass-arm64-v8a.apk` → 200، 48228892 بايت، sha256 مطابق. المستخدم بيثبّت **فوق** التطبيق (مايلغيش).
- **التحديث الذاتي داخل التطبيق** (`update_service.dart`): `/repos/amertimraz/App-Active-Class/releases/latest` → v1.2.49، يختار الأصل اللي فيه `arm64` في الاسم. شغّال.
- **release notes:** `scratchpad/release_notes_v1.2.49.md`.

**⚠️ درس البناء (محدَّث في `memory/release-build-versioncode.md`):**
- المشروع فيه `productFlavors { play; direct }` على بُعد `distribution` (فرق صلاحية `REQUEST_INSTALL_PACKAGES`). `flutter build appbundle --release` من غير `--flavor` يطلع رسالة "failed to produce an .aab file" رغم إن الـaab اتبنى فعلاً في `build/app/outputs/bundle/{play,direct}Release/`.
- **`--split-per-abi` بيقع OOM** على جهاز البناء (16GB، ~4GB فاضي). الحل: `--target-platform android-arm64` (وبعده `android-arm`، `android-x64`) — كل مرة بيكتب فوق `build/app/outputs/flutter-apk/app-direct-release.apk` فانسخه فورًا.
- v1.2.49 وقع 3 مرات OOM قبل ما DaVinci Resolve (~1.9GB) يتقفل.
- **قاعدة versionCode:** بناء عادي (بلا split) = versionCode = build# (4067). لازم يبقى > آخر ABI code قديم (كان 4066). التالي: `+4068` أو أعلى.

---

## ⏳ متبقّي / مفتوح

0. **الأحدث (v1.2.62):**
   - **رفع الـAAB على Play Console** (خطوة يدوية على المستخدم): `release_assets/v1.2.62/ActiveClass-play.aab`. لسه ماتعملش.
   - **spec 035 US2** (بيانات الطالب اللي خرج تفضل زي ما هي) — اتصمّمت بس ماتعملش تحقّق يدوي صريح ليها (quickstart scenario 4)، رغم إن المنطق (خصم الطالب من `remainingMembers` بس، بلا لمس صفوف حضور/دفعات) بيدعمها بالتصميم.
   - **تصادم كود الطالب التلقائي** — الإصلاح (retry تلقائي) اتعمل بس **السبب الجذري بالظبط لسه مش متأكّد منه 100%** (نظرية الأرجح: TOCTOU race مع مزامنة وضع الفريق — راجع تفاصيل الإصلاح فوق). لو البلاغ اتكرر بعد الإصلاح، محتاج فحص أعمق للـsync outbox ordering وقت الحذف/الإضافة الفورية.
1. **رفع الـAAB على Play Console** (خطوة يدوية على المستخدم): `release_assets/ActiveClass-v1.2.52-play.aab`.
2. **ريليس v1.2.51 اتنشر** (`1e4b3ab` + tag) — يضم 028–033. التحقّق الجهازي تحت (اتعمل بعد النشر).
3. **تحقّق جهازي — كله منشور في v1.2.51، لسه محتاج جهاز/جهازين للتأكيد:**
   - **spec 027 T019** — قارئ HID حقيقي (quickstart 1–11).
   - **spec 028** — حذف بمدى تواريخ (quickstart 1–9): فشل النسخة الاحتياطية → إلغاء، جهازين، عدم انحدار الروستر.
   - **spec 029** — تحذير تأخّر الدفع (quickstart 1–10).
   - **spec 030** — تقوية المزامنة (3 باجات SyncEngine): outbox poison، سحب دوري، عدم auto-logout كاذب.
   - **spec 031** — اتساق التعارضات (`62d88dc`): ساعة منحرفة، حضور/درجة مزدوجة، عدم انحدار.
   - **spec 032** — إلغاء/تعويض الحصة (quickstart 1–8): إلغاء/تراجع، تعويضية/إضافية، فوترة per-session، سجل الطالب، مزامنة `(group,date)` جهازين. **T024 (بوابة الأهل) مؤجّل.**
   - **spec 033** — تنظيف الرقم + واتساب (quickstart 1–11): لصق من سجل مكالمات حقيقي بلغة عربية، معاينة، رابط/username، جهازين لعمود `guardian_whatsapp`.
   - **spec 026 T016** — عدم انحدار المجموعات الشهرية في شاشة الدفع بالماسح + الدفعة الجزئية جهازين.
4. **مؤجَّلات قديمة (مش عاجلة):** `migration_student_follow_ups.sql` لسه ماتطبّقش (لو هنعيد تفعيل مزامنة `student_follow_ups`)؛ تحقّق جهازين لـ024 + 025.
5. **باج قديم:** `Student.copyWith` مفهوش `clearGuardianPhone` → إفراغ رقم ولي الأمر في التعديل مابيتحفظش.

---

## 🔑 حقائق ثابتة للجلسة الجديدة

- **git push فقط بإذن صريح.** الـspecs بتتعمل commit على `main` مباشرة (عرف المشروع).
- **التوقيع:** نفس keystore كل مرة (`android/key.properties` + `RELEASE_SIGNING_INFO.md` — الاتنين gitignored، فيهم باسورد `gG1lrhvSog96kQbwCYtyoRxN`، **متتعملش commit ولا expose**). SHA-256 = `5f74fe10af2da396cbf0a98895af02bb5ffbdc01cdf68a55bea25a841f02ec7b`. مزج debug/release أو إلغاء-وإعادة تثبيت = مسح بيانات محلية (slug بوابة الأهل + الرخصة).
- **SSH VPS:** `ssh -i ~/.ssh/ovh_key root@active-class.online` — شغّال من الساندبوكس. حاوية Supabase: `active-class-auth-db-1`، compose في `/opt/active-class-auth/docker`. تطبيق migration: `ssh ... 'docker exec -i active-class-auth-db-1 psql -U postgres -d postgres -v ON_ERROR_STOP=1' < supabase/migration_X.sql`. ⚠️ **`ALTER TABLE public.students`** لازم `-U supabase_admin` (الجدول مملوك لـsupabase_admin مش postgres) — spec 033.
- **DB version = 33** (v29 session_overrides (spec 032) → v30 students.guardian_whatsapp (spec 033) → v31 session_overrides.session_time (spec 032) → v32 students.sibling_group_uuid (مزامنة ربط الإخوة عبر الأجهزة) → **v33 students.sibling_group_committed_count (spec 035)**). spec 026/029/030/031 **مازادوش النسخة**.
- **مزامنة الفريق (`SyncEngine`):** قناتان Realtime — `_channel` (`_coreTables`، وفيها دلوقتي `TABLE_SESSION_OVERRIDES` — spec 032) + `_channelX` (`_extendedTables` = `[TABLE_EXAM_QUESTIONS, TABLE_EXAM_SUBMISSIONS, TABLE_BANK_QUESTIONS]`). CHANNEL_ERROR في واحدة معزول عن التانية (إصلاح دائم لحادثة `student_follow_ups`). تعارض الصف المكرّر → `_reconcileDuplicate` (LWW، spec 031) للجداول ذات مفتاح منطقي: attendance/homework/exam_groups/exam_grades/exam_submissions/**session_overrides**.
- **وقت الخادم (spec 031):** `trg_set_updated_at` على 12 جدول متزامن (11 + `session_overrides`) يفرض `updated_at = now()` — LWW متسق رغم انحراف ساعات الأجهزة.
- **`PricingHelper`:** `accumulatedDebt` = مجموع `monthlyDue` من شهر الانضمام لدلوقتي ناقص **كل** الدفعات (رصيد واحد FIFO). per-session: `monthlyDue = student.price * sessionsAttended(month)`. `billingArrears` / `prorateFirstMonth` static flags (per-session بيتجاهلهم). الإخوة: `siblingsTotal / count` عبر `siblingGroupMembers`.
- **`toCloudMap()` لـ`ExamQuestion`** لازم يفضل نضيف من `correctIndex`/`points`/`explanation` (اختبار `exam_question_cloud_map_test.dart` بيفرض ده — FR-034 spec 016). مفاتيح التصحيح بس في `results/{attemptKey}` بعد اعتماد المدرس.
- **الرخصة auto-rebind:** "سيبه زي ماهو" — متغيّرش. الإلغاء عبر `status: suspended`.
- **السر المضمّن في `booking_service.dart`** (`88657c22...`) مقصود وغير حساس (فيه تعليق).
- **جهاز المستخدم (MIUI):** كل جلسة بيعيد تفعيل "Install via USB" في خيارات المطوّر. `adb` أحيانًا offline → `& "F:/AndroidSDK/Sdk/platform-tools/adb.exe" kill-server; start-server`.
- **بناء R8 release بيقع OOM** ("daemon disappeared") — قوّل المستخدم يقفل Resolve/تطبيقات تقيلة. `--no-tree-shake-icons` بيخفّف شوية. `org.gradle.jvmargs=-Xmx2048m` (زيادتها لـ4096 زوّدت الـcrashes).

---

## 📂 ملفات السبيك 026 (لو محتاج تفاصيل)

```
specs/026-qr-payment-accumulated-debt/
├── spec.md          # 3 user stories، 17 FR، 6 SC
├── plan.md          # الملخص التقني + Constitution Check (PASS)
├── research.md      # 8 قرارات محسومة
├── data-model.md    # كيانات محسوبة، لا سكيمة
├── contracts/
│   ├── qr-controller-per-session-scope.md   # سلوك _preparePayment + جدول before/after
│   ├── debt-display.md                       # عقد عرض سطر المديونية
│   └── debt-amount-payment.md                # applyDebtAmountPayment + معاينة + note
├── quickstart.md    # 6 سيناريوهات تحقّق
└── tasks.md         # T001–T020
```
