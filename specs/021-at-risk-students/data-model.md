# Data Model: طلاب محتاجين متابعة

## جدول جديد: `student_follow_ups`

الصف الوحيد المخزَّن فعليًا في الميزة دي — واقعة "تمّت المتابعة" واحدة. كل حاجة تانية (الإشارات، عناصر القائمة) محسوبة وقت العرض ومش بتتخزّن.

```sql
CREATE TABLE student_follow_ups (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id       INTEGER NOT NULL,
  reason_types     TEXT NOT NULL,   -- JSON list<String>، مثال: ["consecutive_absence","late_payment"]
  acknowledged_at  TEXT NOT NULL,   -- ISO 8601
  note             TEXT,            -- ملاحظة اختيارية للمدرس
  sync_updated_at  TEXT,
  remote_id        TEXT,
  FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
);
CREATE INDEX idx_student_follow_ups_student ON student_follow_ups(student_id);
```

**قواعد**:
- `reason_types` = أنواع الإشارات (من `RiskSignalType`) اللي كانت متحقّقة **وقت الإقرار بالظبط** — مش كل الأنواع الممكنة. بيُستخدم لتحديد "إشارة نوع جديد" (FR-014).
- صف واحد لكل ضغطة "تمّت المتابعة" — مفيش تحديث في مكانه؛ لإرجاع طالب للقائمة الرئيسية يدويًا (US2 AC5)، الصف بيتحذف (مش بيتحدّث لحالة "ملغاة") — أبسط، ومفيش حاجة تانية بتحتاج تاريخ "الإلغاءات".
- **التهدئة محسوبة وقت العرض**، مش عمود مخزَّن: طالب مؤجَّل = عنده صف `student_follow_ups` بـ`acknowledged_at` أحدث من `الآن − cooldownDays`، وإشاراته الحالية ⊆ `reason_types` المخزَّنة في آخر صف له.
- **الحذف Cascade**: حذف الطالب (موجود بالفعل، `ON DELETE CASCADE` على جداول تانية كتير) بيمسح وقائعه تلقائيًا — صفر كود إضافي.
- **المزامنة**: `sync_updated_at`/`remote_id` نفس العمودين القياسيين على أي جدول متزامَن (`TABLE_HOMEWORK`/`TABLE_PAYMENTS`... إلخ) — نفس الآلية بالظبط، مفيش تخصيص.

## Migration

`DATABASE_VERSION`: **24 → 25**.

```dart
if (oldVersion < 25) {
  try {
    await db.execute(_studentFollowUpsTableSql);
    await db.execute(_studentFollowUpsIndexSql);
  } catch (_) {}
}
```

نفس نمط `oldVersion < 23` (spec 016 — إضافة `exam_questions`/`exam_submissions` ككيان جديد بالكامل، مش عمود على جدول موجود). التثبيتات الجديدة تكسب الجدول من `onCreate` مباشرة (زي `_examQuestionsTableSql` موجود في كل من `onCreate` والـmigration).

## كيانات محسوبة (مش مخزَّنة)

### `RiskSignalType` (enum)
`consecutiveAbsence` | `missingHomework` | `gradeDrop` | `latePayment`

### `RiskSignal`
| حقل | نوع | وصف |
|---|---|---|
| `type` | `RiskSignalType` | نوع الإشارة |
| `reasonText` | `String` | نص جاهز للعرض بالأرقام، مثال: `"غياب متتالي (2)"` |
| `severityWeight` | `int` | وزن للترتيب (قيمة افتراضية لكل نوع، قابلة للمراجعة وقت التنفيذ) |

### `AtRiskStudent`
| حقل | نوع | وصف |
|---|---|---|
| `student` | `Student` | |
| `group` | `Group?` | |
| `signals` | `List<RiskSignal>` | إشارة واحدة على الأقل |
| `severityScore` | `int` | مجموع/تركيب أوزان `signals` — أساس الترتيب التنازلي |
| `guardianPhone` | `String?` | من `student.guardianPhone` — لتفعيل/تعطيل أزرار التواصل |

### `AtRiskSettings` (مبنية من `app_settings`، مش كيان DB منفصل)
| المفتاح | افتراضي | الوصف |
|---|---|---|
| `atrisk_absence_enabled` / `atrisk_absence_threshold` | `true` / `2` | غياب متتالي (K حصص) |
| `atrisk_homework_enabled` / `atrisk_homework_m` / `atrisk_homework_w` | `true` / `3` / `5` | واجب ناقص (M من آخر W) |
| `atrisk_grade_enabled` / `atrisk_grade_drop_points` | `true` / `15` | هبوط الدرجات (نقطة مئوية) — "تحت النجاح" مبني على `passingGrade` الموجود في `ExamGrade` نفسها، مش عتبة منفصلة |
| `atrisk_payment_enabled` | `true` | تأخّر الدفع — **يعيد استخدام `SettingsController.paymentGraceDays` الموجود بالفعل كعتبة الأيام**، صفر مفتاح عتبة جديد (بدل ما اقترحته في الـspec كعتبة منفصلة — نفس المفهوم فعليًا موجود ومُستخدَم في الداشبورد/qr_controller/الإشعار اليومي) |
| `atrisk_cooldown_days` | `7` | مدة التهدئة بعد "تمّت المتابعة" |
| `atrisk_weekly_notif_enabled` / `_day` / `_hour` / `_minute` | `true` / `الأحد` / `9` / `0` | الإشعار الأسبوعي |

**تصحيح عن الـspec**: FR-005 وصف "عتبة أيام التأخّر" كإعداد جديد مستقل؛ فعليًا التطبيق عنده `paymentGraceDays` بنفس المعنى بالظبط (مُستخدَم في 4 أماكن: الداشبورد، `qr_controller`، الإشعار اليومي الحالي، `group_details_page`). القرار: **نعيد استخدامه بدل ما نكرّره** — يقلّل الإعدادات ويوحّد تعريف "متأخّر" في التطبيق كله. الإشارة برضو بتستبعد الطلاب المعفيّين وبتعتمد `accumulatedDebt > 0` — مطابق تمامًا لما هو موصوف في FR-005، غير مصدر العتبة بس.
