# Phase 0 Research: الملازم والكتب

## 1) دفعات الملازم: جدول مستقل أم صفوف `Payment` بملاحظة؟

**Decision**: جدول `booklet_payments` مستقل تمامًا.

**Rationale**: spec 038 (إسقاط المديونية) أثبت أن تمييز نوع مختلف داخل جدول `payments` بملاحظة نصية بيخلّي كل مكان بيجمع `Payment.amount` (كارت الصفحة الرئيسية، دفعوا اليوم، التقارير، التصدير، شاشة المدفوعات…) محتاج استثناء يدوي — وطلعت ٥ أماكن ناقصة أثناء التجربة. جدول منفصل بيحقق FR-008/FR-009 و SC-004 **افتراضيًا**: مفيش سطر واحد في `pricing_helper.dart` أو تقارير المدفوعات بيتلمس، وأي إجمالي "محصَّل" قائم مايشوفش دفعات الملازم أصلاً.

**Alternatives considered**: صفوف `Payment` بـ`note` ثابتة أو عمود `kind` جديد — مرفوض للسبب أعلاه (ضريبة صيانة دائمة على كل مجمِّع مالي).

---

## 2) شكل الجداول: صفوف مادّية لكل (طالب × ملزمة) أم كسولة؟

**Decision**: أربع جداول: `booklets`، `booklet_groups` (ربط)، `booklet_records` (تسليم + استثناء)، `booklet_payments`. `booklet_records` **كسولة**: مفيش صف يتنشأ لطالب لحد ما المدرّس يسلّم/يستثني له؛ الافتراض لطالب بلا صف = "مؤهَّل، لم يُسلَّم، غير مستثنى".

**Rationale**: (أ) FR-004 (طالب جديد ينضم لمجموعة → يبقى مؤهَّل تلقائيًا) بيتحقق مجانًا لأن الأهلية مشتقة من عضوية المجموعة، بلا كود مزامنة/hook على إضافة الطالب. (ب) إنشاء ملزمة على مجموعة 50 طالب = صف واحد + صف ربط، بدل 50 صف مزامَن (SC-001). (ج) نفس نمط الامتحانات المثبت في المشروع: قائمة الطلاب = طلاب المجموعة LEFT JOIN السجلات (`getGradesForExamGroup`). (د) دفعات الملازم مربوطة مباشرة بـ(booklet_id, student_id) لا بصف record، فمافيش اعتماد على وجود record لتسجيل دفعة.

**Alternatives considered**: صف record مادّي لكل طالب مؤهَّل عند الإنشاء — مرفوض: مزامنة كثيفة، ويحتاج hook لإنشاء صفوف للطلاب الجدد (مصدر باجات تكرار/فقد).

---

## 3) الأهلية والمشتقات (لا تُخزَّن)

**Decision**: دوال صرفة في `lib/utils/booklet_math.dart` (راجع contracts/booklet-math.md):
- `bookletPaid(payments)` = مجموع المبالغ؛ `bookletRemaining(price, paid)` = `max(0, price − paid)`؛ `bookletOverpaid(price, paid)` = `max(0, paid − price)`.
- `bookletPaymentStatus(price, paid)` → `none | partial | full` (سعر 0 ⇒ `full` دائمًا؛ paid ≥ price ⇒ `full`).
- `eligibleStudents(...)`: طلاب مجموعات الملزمة **غير المؤرشفين** — **مطروحًا** المستثنون — **مع الإبقاء** على أي طالب مؤرشف/مستثنى/منقول عنده دفعة أو تسليم مسجَّل بس في عرض "السجل التاريخي" (FR-015): الافتراضي في القوائم التشغيلية استبعاد المؤرشف (نفس درس إصلاح الأرشفة في تصحيح الامتحانات: الفلتر لازم يتطبّق على مصدر الصفوف الفعلي).

**Rationale**: كل الأرقام مشتقة → تغيير السعر (Acceptance 1.5) بيتحدّث لوحده، والقص عند صفر مع مؤشر "زيادة دفع" يغطي edge case تخفيض السعر.

---

## 4) الاستثناء لطالب عنده دفعات

**Decision**: الاستثناء يضبط `excluded=1` فقط ولا يمسح أي دفعة أبدًا. الواجهة تعرض تأكيدًا يذكر مبلغ الدفعات المسجَّلة (لو فيه) وأنها **هتتحفظ**؛ حذف دفعة بيتم بشكل منفصل من قائمة دفعات الطالب.

**Rationale**: أبسط وأأمن ماليًا (لا فقد صامت لبيانات مالية)، ويغطي الـedge case بخيار "احتفظ" فقط؛ خيار "امسح" مضمَّن عمليًا عبر حذف الدفعات يدويًا.

---

## 5) المزامنة (وضع الفريق)

**Decision** (نفس بصمة spec 032/025/024، ٦ مواضع في `sync_engine.dart`):
1. `_tables`: بالترتيب `booklets` ← `booklet_groups` ← `booklet_records` ← `booklet_payments` في **آخر القائمة** (بعد `exam_submissions`) — آباؤهم (`groups`, `students`) فوق أصلاً.
2. `_extendedTables` (القناة الممتدة) — مش `_coreTables` — عشان أي backend ناقص migration ما يكسرش القناة الأساسية.
3. `_pkCol` لكل جدول (4 حالات).
4. push mapping (توليد remote map) — `booklet_groups.group_remote_id`، `booklet_records/booklet_payments.{booklet_remote_id, student_remote_id}` (FK → remote uuid بنفس أسلوب `student_remote_id`/`group_remote_id`).
5. pull mapping (عكسي) مع `return null` لو الأب لسه ما وصلش.
6. reload switch: ينادي `BookletController.load()` لو مسجّل.
7. **reconcile duplicates** (نمط spec 031/032): `booklet_records` على (booklet_id, student_id)، `booklet_groups` على (booklet_id, group_id) — جهازين ممكن ينشئوا نفس الصف قبل التبادل (خصوصًا records الكسولة: مساعد يسلّم ومدرّس يستثني في نفس اللحظة).

**Server**: `supabase/migration_booklets.sql` بنفس قالب `migration_session_overrides.sql` (RLS بـ`is_team_member` + `is_team_license_active`، بلا DELETE policy، soft-delete عبر `deleted_at`، `trg_set_updated_at`، publication realtime). صلاحية الحذف: trigger يعيد استخدام `delete_payments` لكل الجداول الأربعة (طبيعتها مالية) بدل صلاحية جديدة. **ملكية الجداول الجديدة**: تُنشأ بمستخدم `supabase_admin` (نفس تحقق ملكية attendance في spec 040) فتتوافق مع باقي الجداول.

---

## 6) الحذف المتسلسل (محلي + طابور المزامنة)

**Decision**:
- `deleteBooklet`: بنفس نمط `deleteExam` بالضبط — التقاط remote_id للأبناء (`booklet_groups`, `booklet_records`, `booklet_payments`) **قبل** الحذف المحلي (cascade)، ثم `_queueDelete` لكل ابن ثم الأب. واجهة: تأكيد صريح يذكر عدد التسليمات/إجمالي المدفوع (Edge Case).
- حذف طالب نهائيًا (`deleteStudent`) وحذف مجموعة (`deleteGroup`): إضافة التقاط/`_queueDelete` لـ`booklet_records` و`booklet_payments` التابعة للطالب (والمجموعة → `booklet_groups`) بنفس أسلوب التقاط `TABLE_PAYMENTS`/`TABLE_ATTENDANCE` القائم في تلك الدوال — وإلا الطرف التاني يفضل عنده يتامى.
- الأرشفة **لا تحذف** أي شيء (FR-015).

---

## 7) الصلاحيات والواجهة

**Decision**: لا صلاحيات جديدة. عرض/تسجيل الدفعات وأرقام المبالغ = `TeamModeService.canSeeFinancials`؛ حذف دفعة/ملزمة = `canDeletePaymentsNow`؛ التسليم والاستثناء = أي مستخدم (زي الحضور). قسم الملازم في تفاصيل الطالب موجود **داخل تاب المدفوعات** (المقفول أصلاً بـ`_canSeeFinancials`) — التسليم لمن لا يملك الصلاحية المالية متاح من شاشة تفاصيل الملزمة نفسها (تعرض التسليم بلا أرقام مالية).

**نقطة الدخول**: مسار جديد `ROUTE_BOOKLETS` مسجَّل في `main.dart`، ومدخل من `home_page.dart` بنفس نمط مدخل بنك الأسئلة/الامتحانات.

**Alternatives considered**: تاب رابع في تفاصيل الطالب — مرفوض (شاشة التفاصيل أصلاً ثقيلة؛ القسم داخل المدفوعات أقل تكلفة وأكثر منطقية ماليًا).

---

## 8) DB version وترقية

**Decision**: `DATABASE_VERSION` 34→35 (34 اتحجزت لـspec 040 واتنشرت v1.2.72). فرع `if (oldVersion < 35)` ينشئ الجداول الأربعة + الفهارس بـ`CREATE TABLE IF NOT EXISTS` داخل try/catch (نمط `oldVersion < 28/29`)، ونفس الـSQL في `_onCreate`. **فهارس UNIQUE**: `booklet_records(booklet_id, student_id)`، `booklet_groups(booklet_id, group_id)`.

---

## 9) اختبار

**Decision**: `test/booklet_math_test.dart` — الحالات: لا دفع/جزئي/كامل/زيادة، سعر 0 (مجانية)، سعر بيتخفّض بعد دفعات أكبر (قص + زيادة)، أهلية (مؤرشف، مستثنى، طالب مؤرشف عنده دفعة في عرض السجل)، إجمالي "متبقي ملازم" للطالب. الباقي يدوي على جهاز حقيقي + جهازين للمزامنة.
