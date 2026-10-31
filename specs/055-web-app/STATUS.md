# حالة السبيك 055 — الويب (متوقّف مؤقتًا، 2026-10-31)

**الحالة:** نسخة ويب تجريبية شغّالة على `https://app.active-class.online/` **محمية بباسورد Caddy** (مستخدم `gate`، الباسورد على السيرفر في `/root/.web_gate_pw`). **لا تفتحها للمدرسين قبل بوابة الأهلية (المرحلة 4).** كل التعديلات على جهاز التطوير **بدون commit**.

## اللي اتنفّذ وجرّب
- نسخة ويب كاملة تبني وتشتغل (sqflite على IndexedDB، بدون CDN خارجي، `--no-web-resources-cdn`).
- شاشتا الترحيب وتسجيل الدخول (رقم تليفون + باسورد)، خروج بمسح كامل للبيانات المحلية (اتجرّب عمليًا).
- تجاوب الشاشات العريضة (المستوى 1): إطار 1100، تكبير خط/أيقونات، 3 شبكات تزيد أعمدتها.
- ترخيص صاحب الفريق على الويب (قراءة بس) واسمه/جنسه من الفريق.
- منع الويب من كتابة أي حاجة تخص المالك على السيرفر (`TeamModeService._startEngine`) — **كان سبب قفل فريق حقيقي** (research R13).
- نشر: DNS + Caddy + `releases/` + symlink `current` (آخر إصدار `1.2.80_4098-name1`، بيحتفظ بآخر 3).
- الاختبارات: **778 ناجح**، `flutter analyze` = 43 (خط الأساس).

## اللي لسه (بالترتيب المقترح)
1. **المرحلة 4 — بوابة الأهلية (الأولوية):** مفتاح تفعيل الويب لكل مدرس في لوحة الأدمن (زي بوابة ولي الأمر) + `teams.web_enabled/web_expires_at` + `get_web_entitlement` + شاشة «الترخيص مقفول»/«الويب غير مفعّل» + إيقاف تجربة الويب (وإيقاف تسجيل `devices/{uuid}` على Firestore) + بعدها نشيل `basic_auth` من Caddy. (tasks T022–T036)
2. **المرحلة 6 — مزامنة إعدادات الفريق:** جدول `team_settings` + رفع من الموبايل + إصدار موبايل جديد → يخلّي مدفوعات الشهور والمتأخرات على الويب = الموبايل. (T044–T048)
3. **المرحلة 7 — عنصر الويب في الموبايل** وإنشاء الفريق تلقائيًا. (T049–T052)
4. منع الكتابة أوفلاين، تاب واحد نشط، مؤشر تقدّم للسحب الأول، فحص إصدار الصفحة. (T037–T043)
5. المستوى 2 من التجاوب (إعادة تخطيط الحضور/المدفوعات/الرئيسية)، الصورة الشخصية، قياس سحب فريق كبير (T006).
6. حماية RLS حسب `Origin` (النسخة التانية)، الدخول بـ QR.

## تحذيرات للجلسة الجاية
- **ما تفتحش الويب من غير بوابة الأهلية:** التجربة المجانية لسه شغّالة لأي حد بحساب فريق.
- أي كود جديد على الويب يمر على `kIsWeb`: ممنوع يكتب في `teams`/Firestore ترخيص أو بيانات مالك.
- `dart format` على مجلدات كاملة بيعدّل عشرات الملفات — نفّذه على الملفات الجديدة فقط.
- فحص إنتاج بالقراءة بس (psql عبر SSH) اتعمل بإذن صريح من المستخدم؛ لازم إذن كل مرة.
- شاشات مخفية/غير متجاوبة على الويب لسه: الحجوزات، الملازم، بنك الأسئلة، الإعدادات المتقدمة، النسخ الاحتياطي.

## ملفات جديدة (غير مضافة لـ git)
`specs/055-web-app/*`, `lib/core/platform/*`, `lib/views/web/*`, `lib/utils/{responsive,web_login_notice,web_owner_license}.dart`, `lib/widgets/web_responsive_frame.dart`, `web/sqlite3.wasm`, اختبارات `test/{web_auth_pages,responsive,web_login_notice,web_owner_license}_test.dart`.
## ملفات متعدّلة
`pubspec.{yaml,lock}`, `web/{index.html,manifest.json}`, `lib/main.dart`, `lib/config/theme.dart`, `lib/controllers/license_controller.dart`, `lib/services/{database_service,team_mode_service,sync_engine}.dart`, `lib/views/{splash_page,home_page}.dart`, `lib/views/auth/account_screen.dart`, `lib/views/students/students_page.dart`, `lib/views/qr_scanner/qr_gallery_page.dart`.
