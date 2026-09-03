# Contract — فلاتر صفحة المراكز + توسيع getLeaderboard

## الفلتر (حالة واجهة، واحد نشط)

```dart
enum LbScope { all, group, exam, month }

class LbFilter {
  final LbScope scope;
  final int? groupId;      // scope == group
  final int? examId;       // scope == exam
  final DateTime? month;   // scope == month (اليوم 1)
}
```

الافتراضي: `LbScope.all`. منتقي في الترويسة: شرائح (زي `_FilterChipW` في `exams_page`) — "الكل" ثابت، ثم قوائم منسدلة/شرائح للمجموعات والامتحانات والشهور المتاحة.

## توسيع `DatabaseService.getLeaderboard`

**التوقيع الجديد**:
```dart
Future<List<LeaderboardEntry>> getLeaderboard({
  int? examId,
  int? groupId,
  List<int>? examIds,   // جديد — لفلتر الشهر (كل امتحانات الشهر)
});
```

**التغييرات على الاستعلام** (كلها إصلاحات مرغوبة):
1. **استبعاد المؤرشفين** — `AND s.$COL_STUDENT_IS_ARCHIVED = 0` في WHERE. (FR-016 — نقص حالي)
2. **`examIds`** — `AND eg.$COL_GRADE_EXAM_ID IN (?, ?, ...)` لو `examIds != null && examIds.isNotEmpty`. القائمة تُبنى في الكنترولر من `exams.where((e) => sameMonth(e.effectiveReportMonth, filter.month))`. (FR-019)
3. **tie-break ثابت** — `ORDER BY (SUM(grade)*1.0/SUM(max)) DESC, s.$COL_STUDENT_NAME ASC`. (FR-017 / SC-005)
4. الحقول المرجَّعة زي ما هي (`LeaderboardEntry`).

**الكنترولر** (`ExamController.leaderboard(LbFilter)`):
- `all` → `getLeaderboard()`
- `group` → `getLeaderboard(groupId: f.groupId)`
- `exam` → `getLeaderboard(examId: f.examId)`
- `month` → `examIds = exams.where(month match).map((e) => e.id!)` ثم `getLeaderboard(examIds: examIds)`؛ لو `examIds` فاضية → قائمة فاضية.

## العرض (FR-011..015)

- **ترويسة** متدرّجة (إنديجو→بنفسجي) فيها عنوان "المراكز" + عدد الطلاب المحتسبين + نطاق الفلتر الحالي.
- **صف الطالب**:
  - المركز: 1/2/3 → ميدالية 🥇🥈🥉 في دائرة ملوّنة (ذهبي `0xFFFFD700`، فضي `0xFFC0C0C0`، برونزي `0xFFCD7F32`)؛ الباقي → رقم في دائرة رمادية.
  - الاسم (bold) + المجموعة (شريحة صغيرة).
  - يمين: النسبة المئوية كبيرة + "{totalGrade}/{totalMax}" صغير + "{examCount} امتحان".
  - شريط تقدّم رفيع بالنسبة.
- **زر مشاركة** أعلى/floating → `Share.share(buildLeaderboardShareText(top20, teacherLine, filterLabel))`. معطّل لو القائمة فاضية.
- **زر "شهادات المراكز"** → يفتح `certificates_sheet` بأول 3 (CertKind.rank1/2/3) — نطاق الفلتر في نص الإنجاز.

## حالات حافّة

- فلتر مجموعة/امتحان اتحذف → `LbFilter` يرجع `all` تلقائيًا (تحقّق `groupId`/`examId` لسه موجود قبل الاستعلام).
- شهر مفيهوش امتحانات → قائمة فاضية + "مفيش امتحانات في {شهر}".
- طالب واحد بس عنده درجات → يظهر بالمركز 1 بميدالية، بدون مقارنة.
