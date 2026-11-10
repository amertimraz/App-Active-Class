# Tasks: إرسال واتساب تلقائي من داخل التطبيق

**Input**: [spec.md](spec.md)، [plan.md](plan.md)، [data-model.md](data-model.md)، [contracts/](contracts/)، [research.md](research.md)

**Tests**: مطلوبة لمنطق الأهلية والـ worker والشاشات (الخطة فيها ملفات اختبار)؛ بدون TDD صارم.

**Format**: `- [ ] T### [P?] [US?] وصف + مسار الملف`. [P] = ممكن بالتوازي (ملفات مختلفة).

**قواعد المشروع**: كل شاشة/إعداد جديد = تحديث `lib/help/help_content.dart` و`lib/help/help_coverage.dart` في نفس التغيير. أي migration على السيرفر يحتاج موافقة المالك قبل التنفيذ.

---

## Phase 1: Setup + Spike (قبل أي كود إنتاج)

- [ ] T001 تجهيز المتطلبات الخارجية (يدوي من المالك): شريحة مصرية جديدة، حساب Meta Business موثّق، تسجيل الرقم على WhatsApp Cloud API، تقديم 3 قوالب utility بالعربي (غياب/تأخر دفع/إيصال)
- [x] T002 (جزئي: Meta قبلت الإرسال بالرقم التجريبي `accepted`؛ التسليم الفعلي والـ webhook لم يُختبرا) Spike: إرسال قالب واحد لرقم المالك عبر Meta Cloud API (الرقم التجريبي ثم الرقم الحقيقي) بسكربت مؤقت في `supabase/wa-worker/spike/send.js`، وتسجيل تسجيل الرقم، التوقيع X-Hub-Signature-256، تجديد الـ token، والتسعير الفعلي
- [ ] T003 تحديث `specs/056-whatsapp-auto-send/research.md` (قسم R3) و`contracts/worker-and-webhook.md` بنتايج الـ spike؛ تعديل أرقام الحصة/المعدل الافتراضية في `spec.md` لو التكلفة مختلفة
- [x] T004 [P] إنشاء هيكل `supabase/wa-worker/` (package.json، Dockerfile، `src/`، `test/`)

**Checkpoint**: Cloud API يرسل ويستقبل فعليًا بالرقم المصري.

---

## Phase 2: Foundational (يعطّل كل القصص)

- [x] T005 كتابة `supabase/migration_whatsapp_auto.sql`: جداول `wa_outbox` و`wa_consents` و`wa_quota` و`wa_settings` + indexes + unique(dedupe_key) + RLS حسب `contracts/outbox-and-quota.md` + تنظيف السجل بعد 90 يوم (idempotent)
- [x] T006 [P] واجهة `Provider` في `supabase/wa-worker/src/provider.js` + تنفيذ Meta في `supabase/wa-worker/src/meta.js` (send + parse webhook + verify signature)
- [x] T007 [P] قوالب الرسايل وخريطة المتغيرات في `supabase/wa-worker/src/templates.js` (3 أنواع + test)
- [x] T008 حلقة الإرسال في `supabase/wa-worker/src/sender.js`: سحب `for update skip locked`، kill_switch، ساعات الإرسال، token bucket، موافقة، خصم ذري من الحصة/الرصيد، إعادة محاولة 3 مرات، رد الخصم عند الفشل غير المحاسَب (بعد T005, T006, T007)
- [x] T009 Webhook في `supabase/wa-worker/src/webhook.js`: تحقق التوقيع، تحديث الحالات (idempotent)، التقاط "إيقاف/ايقاف/STOP"، تأكيد واحد، تنبيه المالك عند فشل >20%/ساعة (kill switch تلقائي)
- [x] T010 [P] اختبارات الـ worker في `supabase/wa-worker/test/` (sender: حصة تحت التزامن، موافقة، تأجيل ساعات؛ webhook: توقيع، idempotency، إيقاف)
- [ ] T011 إعداد النشر: خدمة `wa-worker` في docker compose + مسار `/wa/webhook` في Caddy + متغيرات البيئة (DB_URL, PROVIDER_KEY, WEBHOOK_SECRET) على الـ VPS — **بعد موافقة المالك**
- [ ] T012 تطبيق الـ migration على السيرفر عبر SSH (`supabase_admin`) والتحقق من الجداول والـ RLS — **بعد موافقة المالك**
- [ ] T013 [P] نموذج `lib/models/whatsapp_message_model.dart` (status/kind/failReason + fromJson) وثوابت في `lib/config/constants.dart`
- [ ] T014 [P] أهلية صرفة `lib/services/whatsapp_auto_rules.dart`: نوع مفعّل، طالب نشط، رقم صالح (PhoneHelper)، حصة غير ملغاة (spec 032)، بناء `dedupe_key`، متغيرات القالب
- [ ] T015 اختبار الأهلية `test/whatsapp_auto_rules_test.dart` (بعد T014)
- [ ] T016 `lib/services/whatsapp_auto_service.dart`: enqueue (insert on conflict nothing)، قراءة السجل/الحصة/الموافقات، upsert موافقة، رسالة اختبار — مفعّل على جهاز المالك فقط (بعد T013, T014)
- [ ] T017 `lib/controllers/whatsapp_auto_controller.dart` + إعدادات (`enabled`, `kinds`) عبر `settings_controller.dart` (إعداد محلي افتراضي مقفول)

**Checkpoint**: رسالة اختبار من التطبيق تعدّي outbox → worker → واتساب → webhook.

---

## Phase 3: US3 — موافقة ولي الأمر (P1) 🎯 يسبق الإرسال

**Goal**: لا رسالة بلا موافقة؛ "إيقاف" يوقف فورًا.
**Independent Test**: غياب بلا موافقة = `blocked`، بعد الموافقة = يتبعت، بعد "إيقاف" = `blocked: stopped`.

- [ ] T018 [P] [US3] شيت موافقة `lib/views/whatsapp/consent_sheet.dart` (فردي + بالجملة لمجموعة، يعرض الأرقام غير الصالحة) بتصميم `AppPanel`
- [ ] T019 [US3] ربط الموافقة من بيانات الطالب في `lib/views/student_details_page.dart` ومن المجموعة في `lib/views/groups_page.dart`
- [ ] T020 [US3] عرض حالة الموافقة (موافق/أوقف/بلا) كشارة في تفاصيل الطالب
- [ ] T021 [US3] اختبار شاشة `test/whatsapp_consent_sheet_test.dart`

---

## Phase 4: US1 — تنبيه الغياب التلقائي (P1) 🎯 MVP

**Goal**: غياب → رسالة لولي الأمر بدون نقرات.
**Independent Test**: مدرس تجريبي، تسجيل غياب → وصول الرسالة وظهورها في السجل.

- [ ] T022 [US1] شاشة الإعدادات `lib/views/settings/categories/whatsapp_auto_category.dart` (تفعيل عام، تفعيل الأنواع، شرح الشروط + تأكيد FR-016، زر رسالة اختبار FR-021) وتسجيلها في `lib/views/settings/` (حسب spec 051)
- [ ] T023 [US1] enqueue الغياب من `lib/controllers/attendance_controller.dart` عند تسجيل غياب يدوي (مرجع `date|groupId`، إلغاء لو تحوّل لحضور قبل الإرسال)
- [ ] T024 [US1] enqueue الغياب التلقائي في `lib/services/auto_absent_service.dart` (توزيع زمني للدفعات الكبيرة FR-014)
- [ ] T025 [US1] إلغاء الطلبات `pending` عند أرشفة الطالب أو تحوّل الغياب لحضور
- [ ] T026 [US1] اختبار `test/whatsapp_absence_enqueue_test.dart` (لا تكرار، لا ميزة=لا طلب، حصة ملغاة)
- [ ] T027 [US1] موضوع مساعدة "واتساب تلقائي" في `lib/help/help_content.dart` + مسارات في `lib/help/help_coverage.dart` + تشغيل اختبارات help الثلاثة

---

## Phase 5: US2 — تأخر الدفع وإيصال الدفعة (P1)

**Goal**: إيصال عند تسجيل دفعة، وتذكير تأخر أسبوعي.
**Independent Test**: دفعة → إيصال بمبلغ صحيح؛ طالب متأخر → تذكير واحد/أسبوع.

- [ ] T028 [P] [US2] enqueue الإيصال من مسار تسجيل الدفعة (مرجع `payment_id`، المتغيرات: المبلغ، الشهر، الباقي) في `lib/controllers/payment_controller.dart` (راجع المسار الفعلي قبل التعديل)
- [ ] T029 [US2] تذكير التأخر الأسبوعي في خدمة خلفية جديدة `lib/services/late_payment_auto_service.dart` تعيد استخدام منطق `PricingHelper`/التأخر الحالي (مرجع ISO week)
- [ ] T030 [US2] تعديل/حذف دفعة بعد الإرسال: لا إيصال جديد تلقائي (تسجيل فقط) — شرط في T028
- [ ] T031 [US2] اختبار `test/whatsapp_receipt_late_test.dart`
- [ ] T032 [US2] تحديث موضوع المساعدة (إيصال/تأخر) والتغطية + اختبارات help

---

## Phase 6: US5 — سجل الإرسال وحالة التسليم (P2)

**Goal**: المدرس يشوف كل رسالة وحالتها وسبب الفشل.
**Independent Test**: رقم صحيح = وصلت، رقم غير موجود = فشلت بسبب عربي + "ابعتها يدوي".

- [ ] T033 [P] [US5] شاشة `lib/views/whatsapp/whatsapp_log_page.dart` (فلاتر طالب/نوع/حالة/تاريخ، ترقيم صفحات، ألوان حالة + أيقونة مش لون بس)
- [ ] T034 [US5] زر "ابعتها يدوي" للفاشل عبر `whatsapp_launcher` الحالي وزر "إعادة محاولة" (يعيد `pending` لو فشل مؤقت)
- [ ] T035 [US5] مسار الشاشة في `lib/config/constants.dart` + `lib/routes` + دخول من الإعدادات، وتغطيته في `help_coverage.dart`
- [ ] T036 [US5] اختبار `test/whatsapp_log_page_test.dart`

---

## Phase 7: US4 — الحصة والرصيد (P2)

**Goal**: المدرس يشوف المتبقي، ويتنبه، ويتوقف الإرسال عند النفاد.
**Independent Test**: حصة 3، إرسال 4، الرابعة `no_quota` + إشعار واحد.

- [ ] T037 [P] [US4] عرض الحصة والمتبقي وتحذير <20% في شاشة الإعدادات والسجل (FR-022)
- [ ] T038 [US4] إشعار محلي واحد عند النفاد (`lib/services/notification_service.dart`) مع خيار الإرسال اليدوي
- [ ] T039 [US4] لوحة الأدمن (repo منفصل): ضبط الحصة، إضافة رصيد، إيقاف مدرس/الكل، شاشة استهلاك (FR-017)
- [ ] T040 [US4] اختبار `test/whatsapp_quota_ui_test.dart`

---

## Phase 8: US6 — الإرسال اليدوي يفضل شغال (P2)

**Goal**: لا كسر للأزرار الحالية، وتنبيه ضد الإرسال المزدوج.
**Independent Test**: الميزة مقفولة = كل المسارات القديمة كما هي؛ مفعّلة = تنبيه "اتبعتت تلقائيًا".

- [ ] T041 [US6] تنبيه "اتبعتت تلقائيًا الساعة كذا" قبل الإرسال اليدوي في أزرار غياب/دفع (`lib/utils/absence_message.dart` caller، `attendance_page`, `session_detail_page`) بقراءة السجل
- [ ] T042 [US6] تشغيل اختبارات الأزرار/الشاشات الحالية (`flutter test`) وتأكيد صفر انحدار

---

## Phase 9: Polish & تجريبي

- [ ] T043 [P] جولة "جرّبها بنفسك" اختيارية لتفعيل الواتساب في `lib/tour/tour.dart` (+ `tour_sync_test`)
- [ ] T044 مراجعة الخصوصية: سجلات الـ worker بدون أرقام/نصوص كاملة، RLS بفريق واحد فقط (اختبار يدوي بحسابين)
- [ ] T045 تشغيل سيناريوهات `quickstart.md` كلها (9 سيناريوهات) على رقم حقيقي
- [ ] T046 تجريبي مغلق مع مدرس/اثنين، مراقبة نسبة الفشل والتكلفة أسبوعين، ثم ضبط الحصة النهائية
- [ ] T047 رفع الإصدار + بناء + ملاحظات إصدار (بعد موافقة المالك على النشر)

---

## Dependencies

- Phase 1 → Phase 2 → Phase 3 (US3) → Phase 4 (US1) → Phase 5 (US2).
- US5 (6) وUS4 (7) يعتمدوا على Phase 2 فقط، ممكن بالتوازي مع 4–5 بعد T017.
- US6 (8) يعتمد على US5 (قراءة السجل).
- T011/T012 (نشر السيرفر) شرط لأي اختبار حقيقي من التطبيق.

## Parallel Examples

- Phase 2: T006، T007، T013، T014 معًا؛ بعدها T008 ثم T009.
- بعد T017: T018 (US3) مع T033 (US5) مع T037 (US4).

## Implementation Strategy

1. **MVP = Phase 1 + 2 + 3 + 4**: رسالة غياب تلقائية بموافقة، على مدرس واحد، بحصة ثابتة. نوقف ونراجع التكلفة الفعلية.
2. بعدها الدفع والتأخر (Phase 5)، ثم السجل والحصة، ثم الإطلاق التجريبي.
3. لا نفتح لكل المدرسين قبل T046.
